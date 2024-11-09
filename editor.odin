package main

/*
import "core:fmt"
import sdl "vendor:sdl2"

ZOOM_FACTOR :: 0.1

Draw_Zoomed :: proc(app: ^App, image: ^App_Image, zoom_level: f32) {
    src_rect_f := sdl.FRect{ x = 0, y = 0, w = cast(f32)image.width, h = cast(f32)image.height }
    dst_rect_f := sdl.FRect{ x = -app.camera_x, y = -app.camera_y, w = src_rect_f.w, h = src_rect_f.h }

    zoom_center_x, zoom_center_y := app.camera_x + cast(f32)app.window_width / 2, app.camera_y + cast(f32)app.window_height / 2
    dst_rect_f.x = (dst_rect_f.x - zoom_center_x) * zoom_level + zoom_center_x
    dst_rect_f.y = (dst_rect_f.y - zoom_center_y) * zoom_level + zoom_center_y
    dst_rect_f.w *= zoom_level;
    dst_rect_f.h *= zoom_level;

    src_rect := sdl.Rect{ cast(i32)src_rect_f.x, cast(i32)src_rect_f.y, cast(i32)src_rect_f.w, cast(i32)src_rect_f.h }

    sdl.RenderCopyF(app.renderer, image.texture, &src_rect, &dst_rect_f);
}

Run_As_Editor :: proc(filename: cstring) {
    app : App
    App_Init(&app, "Top Down Shooter", WND_W, WND_H)
    defer App_Destroy(&app)

    map_image := App_Load_Image(&app, filename, 0, 0)
    rects : [dynamic]sdl.Rect

    zoom : f32 = 1.0
    rect_start, rect_end : sdl.Point
    selection_started : bool

    lmb_down, ctrl_down := false, false
    cursor_x, cursor_y : i32 = 0, 0
    last_cursor_x, last_cursor_y : i32 = 0, 0

    event : sdl.Event
    main_loop : for {
        last_cursor_x, last_cursor_y = cursor_x, cursor_y
        App_Get_Cursor_Pos(&cursor_x, &cursor_y)
        delta_cursor_y := cast(f32)(cursor_y - last_cursor_y) * zoom
        delta_cursor_x := cast(f32)(cursor_x - last_cursor_x) * zoom
        // Event handling
        if sdl.PollEvent(&event) {
            #partial switch event.type {
            case sdl.EventType.QUIT:
                break main_loop
            case sdl.EventType.KEYDOWN:
                if event.key.keysym.scancode == sdl.SCANCODE_LCTRL || event.key.keysym.scancode == sdl.SCANCODE_RCTRL {
                    ctrl_down = true
                }
            case sdl.EventType.KEYUP:
                if event.key.keysym.scancode == sdl.SCANCODE_LCTRL || event.key.keysym.scancode == sdl.SCANCODE_RCTRL {
                    ctrl_down = false
                }
            case sdl.EventType.MOUSEBUTTONDOWN:
                if event.button.button == sdl.BUTTON_LEFT do lmb_down = true
                if !ctrl_down {
                    // Start selection
                }
            case sdl.EventType.MOUSEBUTTONUP:
                if event.button.button == sdl.BUTTON_LEFT do lmb_down = false
                if !ctrl_down && selection_started {
                    // End selection
                }
            case sdl.EventType.MOUSEWHEEL:
                if ctrl_down {
                    // Zoom
                    zoom += cast(f32)event.wheel.y * ZOOM_FACTOR
                }
            }
        }

        if lmb_down && ctrl_down {
            app.camera_x -= cast(f32)delta_cursor_x
            app.camera_y -= cast(f32)delta_cursor_y
        }

        Draw_Zoomed(&app, &map_image, zoom)
        for rect in rects {
            // Draw zoomed rect
        }
        sdl.SetRenderDrawColor(app.renderer, 50, 50, 50, 255);
        App_Present(&app)
    }
}
*/

