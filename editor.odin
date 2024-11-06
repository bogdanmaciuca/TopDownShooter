package main

import "core:fmt"
import sdl "vendor:sdl2"

WND_W :: 1024
WND_H :: 768

Run_As_Editor :: proc(filename: cstring) {
    app : App
    App_Init(&app, "Top Down Shooter", WND_W, WND_H)
    defer App_Destroy(&app)

    map_image = App_Load_Image(&app, filename, 0, 0)

    main_loop : for {
        // Event handling
        if sdl.PollEvent(&event) {
            #partial switch event.type {
                case sdl.EventType.QUIT:
                    break game_loop
            }
        }

        App_Present(&app)
    }
}

