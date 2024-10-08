/*
TODO:
- input
- start networking
*/

package main

import "core:fmt"
import "core:unicode/utf8"
import SDL "vendor:sdl2"
import SDL_TTF "vendor:sdl2/ttf"
import SDL_IMG "vendor:sdl2/image"

WND_W :: 1024
WND_H :: 768
BKG_COLOR : SDL.Color : { 150, 100, 150, 255 }
FONT_NAME :: "C64_Mono.ttf"
FONT_SIZE :: 16
FONT_COLOR : SDL.Color : { 255, 255, 255, 255 }
CHAR_SPACING :: 0
LINE_SPACING :: 2

Text_Char :: struct {
    texture: ^SDL.Texture,
    width: i32,
    height: i32
}

Text_Renderer :: struct {
    font: ^SDL_TTF.Font,
    font_size: i32,
    chars: map[rune]Text_Char,
    max_height: i32
}

App_Image :: struct {
    texture: ^SDL.Texture,
    width: i32,
    height: i32,
    src_width: i32,
    src_height: i32
}

App :: struct {
    name: cstring,
    window_width: u16,
    window_height: u16,
    window: ^SDL.Window,
    renderer: ^SDL.Renderer,
    text_renderer: Text_Renderer
}

Text_Renderer_Make_Char :: proc(app: ^App, ch: rune) -> Text_Char {
    text_char : Text_Char
    c_ch := cstring(raw_data(utf8.runes_to_string([]rune{ch})))
    surface := SDL_TTF.RenderText_Solid(app.text_renderer.font, c_ch, FONT_COLOR)
    text_char.texture = SDL.CreateTextureFromSurface(app.renderer, surface)
    SDL_TTF.SizeText(app.text_renderer.font, c_ch, &text_char.width, &text_char.height)
    SDL.FreeSurface(surface)
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

    // Initialize SDL
    sdl_init_error := SDL.Init(SDL.INIT_VIDEO)
    assert(sdl_init_error == 0, SDL.GetErrorString())

    // Create window
    app.window = SDL.CreateWindow(
        app.name,
        SDL.WINDOWPOS_CENTERED, SDL.WINDOWPOS_CENTERED,
        cast(i32)app.window_width, cast(i32)app.window_height,
        SDL.WINDOW_SHOWN | SDL.WINDOW_RESIZABLE
    )
    assert(app.window != nil, SDL.GetErrorString())

    // Create renderer
    app.renderer = SDL.CreateRenderer(app.window, -1, SDL.RENDERER_ACCELERATED)
    assert(app.renderer != nil, SDL.GetErrorString())

    // Font
    sdl_ttf_error := SDL_TTF.Init()
    assert(sdl_ttf_error == 0, SDL.GetErrorString())
    app.text_renderer.font = SDL_TTF.OpenFont(FONT_NAME, app.text_renderer.font_size)
    assert(app.text_renderer.font != nil, SDL.GetErrorString())

    // Initialize char map
    runes :: " ?!@#$%^&*();:',.@_0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
    for r in runes {
        app.text_renderer.chars[r] = Text_Renderer_Make_Char(app, r)
    }
}

App_Destroy :: proc(app: ^App) {
    // TODO: destroy character map
    SDL.DestroyRenderer(app.renderer)
    SDL.DestroyWindow(app.window)
    SDL.Quit()
}

App_Present :: proc(app: ^App) {
    SDL.RenderPresent(app.renderer)
    SDL.SetRenderDrawColor(app.renderer, BKG_COLOR.r, BKG_COLOR.g, BKG_COLOR.b, BKG_COLOR.a)
    SDL.RenderClear(app.renderer)
}

App_Load_Image :: proc(app: ^App, filename: cstring, width: i32, height: i32) -> App_Image {
    image : App_Image
    surface := SDL_IMG.Load(filename)
    image.src_width, image.src_height = surface.w, surface.h
    image.texture = SDL.CreateTextureFromSurface(app.renderer, surface)

    if width == 0 || height == 0 {
        image.width, image.height = image.src_width, image.src_height
    }
    else {
        image.width, image.height = width, height
    }
    return image
}

App_Draw_Text :: proc(app: ^App, str: string, x: i32, y: i32) {
    current_x, current_y := x, y
    for ch in str {
        if ch == '\n' {
            current_x = x
            current_y += app.text_renderer.max_height + LINE_SPACING
        }
        w, h := app.text_renderer.chars[ch].width, app.text_renderer.chars['A'].height
        rect : SDL.Rect = { current_x, current_y, w, h }
        SDL.RenderCopy(app.renderer, app.text_renderer.chars[ch].texture, nil, &rect)
        current_x += w + CHAR_SPACING
    }
}

App_Draw_Image :: proc(app: ^App, image: App_Image, x: i32, y: i32) {
    rect : SDL.Rect = { x, y, image.width, image.height }
    SDL.RenderCopy(app.renderer, image.texture, nil, &rect)
}

main :: proc() {
    app : App
    App_Init(&app, "Top Down Shooter", 1024, 768)
    defer App_Destroy(&app)

    player := App_Load_Image(&app, "res/red.png", 0, 0)

    event : SDL.Event

    GAME_LOOP : for {
        if SDL.PollEvent(&event) {
            #partial switch event.type {
                case SDL.EventType.QUIT:
                    break GAME_LOOP
                case SDL.EventType.KEYDOWN:
            }
        }

        App_Draw_Image(&app, player, 400, 300)
        App_Draw_Text(&app, "Hello world!\nFUck YoU", 100, 200)
        App_Present(&app)
    }
}

