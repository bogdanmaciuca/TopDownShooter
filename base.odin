package main

import "core:fmt"
import "core:unicode/utf8"
import sdl "vendor:sdl2"
import sdl_ttf "vendor:sdl2/ttf"
import sdl_img "vendor:sdl2/image"

FONT_NAME :: "C64_Mono.ttf"
FONT_SIZE :: 16
FONT_COLOR : sdl.Color : { 255, 255, 255, 255 }
CHAR_SPACING :: 0
LINE_SPACING :: 2

Text_Char :: struct {
    texture: ^sdl.Texture,
    width: i32,
    height: i32
}

Text_Renderer :: struct {
    font: ^sdl_ttf.Font,
    font_size: i32,
    chars: map[rune]Text_Char,
    max_height: i32
}

App_Image :: struct {
    texture: ^sdl.Texture,
    width: i32,
    height: i32,
    src_width: i32,
    src_height: i32
}

App :: struct {
    name: cstring,
    window_width: u16,
    window_height: u16,
    window: ^sdl.Window,
    renderer: ^sdl.Renderer,
    text_renderer: Text_Renderer,

    camera_x: f32,
    camera_y: f32
}

Text_Renderer_Make_Char :: proc(app: ^App, ch: rune) -> Text_Char {
    text_char : Text_Char
    c_ch := cstring(raw_data(utf8.runes_to_string([]rune{ch})))
    surface := sdl_ttf.RenderText_Solid(app.text_renderer.font, c_ch, FONT_COLOR)
    text_char.texture = sdl.CreateTextureFromSurface(app.renderer, surface)
    sdl_ttf.SizeText(app.text_renderer.font, c_ch, &text_char.width, &text_char.height)
    sdl.FreeSurface(surface)
    if text_char.height > app.text_renderer.max_height {
        app.text_renderer.max_height = text_char.height
    }
    return text_char
}

App_Init :: proc(app: ^App, name: cstring, width: u16, height: u16) {
    app.name = name
    app.window_width = width
    app.window_height = height
    app.text_renderer.font_size = FONT_SIZE
    app.camera_x = 0
    app.camera_y = 0

    // Initialize SDL
    sdl_init_error := sdl.Init(sdl.INIT_VIDEO)
    assert(sdl_init_error == 0, sdl.GetErrorString())

    // Create window
    app.window = sdl.CreateWindow(
        app.name,
        sdl.WINDOWPOS_CENTERED, sdl.WINDOWPOS_CENTERED,
        cast(i32)app.window_width, cast(i32)app.window_height,
        sdl.WINDOW_SHOWN | sdl.WINDOW_RESIZABLE
    )
    assert(app.window != nil, sdl.GetErrorString())

    // Make window un-resizable
    sdl.SetWindowResizable(app.window, false)

    // Create renderer
    app.renderer = sdl.CreateRenderer(app.window, -1, sdl.RENDERER_ACCELERATED)
    assert(app.renderer != nil, sdl.GetErrorString())

    // Font
    sdl_ttf_error := sdl_ttf.Init()
    assert(sdl_ttf_error == 0, sdl.GetErrorString())
    app.text_renderer.font = sdl_ttf.OpenFont(FONT_NAME, app.text_renderer.font_size)
    assert(app.text_renderer.font != nil, sdl.GetErrorString())

    // Initialize char map
    runes :: " ?!@#$%^&*();:',.@_0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
    for r in runes {
        app.text_renderer.chars[r] = Text_Renderer_Make_Char(app, r)
    }
}

App_Destroy :: proc(app: ^App) {
    // TODO: destroy character map
    sdl.DestroyRenderer(app.renderer)
    sdl.DestroyWindow(app.window)
    sdl.Quit()
}

App_Present :: proc(app: ^App) {
    sdl.RenderPresent(app.renderer)
    sdl.RenderClear(app.renderer)
}

// width and height can be 0 and they will be set to the source width and height
App_Load_Image :: proc(app: ^App, filename: cstring, width: i32, height: i32) -> App_Image {
    image : App_Image
    surface := sdl_img.Load(filename)
    assert(surface != nil, sdl.GetErrorString())
    image.src_width, image.src_height = surface.w, surface.h
    image.texture = sdl.CreateTextureFromSurface(app.renderer, surface)

    if width == 0 || height == 0 {
        image.width, image.height = image.src_width, image.src_height
    }
    else {
        image.width, image.height = width, height
    }
    return image
}

App_Free_Image :: proc(image: App_Image) {
    sdl.DestroyTexture(image.texture)
}

App_Draw_Text :: proc(app: ^App, str: string, x: i32, y: i32) {
    current_x, current_y := x, y
    for ch in str {
        if ch == '\n' {
            current_x = x
            current_y += app.text_renderer.max_height + LINE_SPACING
        }
        else {
            w, h := app.text_renderer.chars[ch].width, app.text_renderer.chars['A'].height
            rect : sdl.Rect = { current_x, current_y, w, h }
            sdl.RenderCopy(app.renderer, app.text_renderer.chars[ch].texture, nil, &rect)
            current_x += w + CHAR_SPACING
        }
    }
}

App_Draw_Image :: proc(app: ^App, image: App_Image, x: i32, y: i32, angle: f32) {
    rect : sdl.Rect = {
        x - cast(i32)app.camera_x + cast(i32)app.window_width / 2,
        y - cast(i32)app.camera_y + cast(i32)app.window_height / 2,
        image.width, image.height
    }
    result := sdl.RenderCopyEx(app.renderer, image.texture, nil, &rect, cast(f64)angle, nil, sdl.RendererFlip.NONE)
    assert(result == 0, sdl.GetErrorString())
}

App_Get_Cursor_Pos :: proc(x: ^i32, y: ^i32) {
    sdl.GetMouseState(x, y)
}

App_Get_Milli :: proc() -> f32 {
	return f32(f64(sdl.GetPerformanceCounter()) * 1000 / f64(sdl.GetPerformanceFrequency()))
}

