/*
TODO:
- start networking
  - server
  - sending player struct to server
*/

package main

import "core:fmt"
import "core:os"
import sdl "vendor:sdl2"

WND_W :: 1024
WND_H :: 768
BKG_COLOR : sdl.Color : { 150, 100, 150, 255 }
FONT_NAME :: "C64_Mono.ttf"
FONT_SIZE :: 16
FONT_COLOR : sdl.Color : { 255, 255, 255, 255 }
CHAR_SPACING :: 0
LINE_SPACING :: 2
NET_UPDATE_INTERVAL :: 1000 / 30

Run_As_Client :: proc() {
    app : App
    App_Init(&app, "Top Down Shooter", WND_W, WND_H)
    defer App_Destroy(&app)

    player : Player
    Player_Init(&app, &player, "res/blue.png")
    defer Player_Destroy(&player)

    event : sdl.Event
    delta_time : f32 = 0
    net_accumulator : f32 = 0
    game_loop : for {
        frame_start := App_Get_Ticks()

        // Event handling
        if sdl.PollEvent(&event) {
            #partial switch event.type {
                case sdl.EventType.QUIT:
                    break game_loop
            }
        }

        // Game logic
        Player_Update(&app, &player, delta_time)

        // Rendering
        Player_Draw(&app, player)
        App_Draw_Text(&app, "Hello world!\nHow you doin'", 100, 200)
        App_Present(&app)

        // Networking
        net_accumulator += delta_time
        if net_accumulator > NET_UPDATE_INTERVAL {
            net_accumulator -= NET_UPDATE_INTERVAL
        }

        frame_end := App_Get_Ticks()
        delta_time = cast(f32)(frame_end - frame_start)
    }
}

Run_As_Server :: proc() {
    fmt.println("Server!!!")
}

main :: proc() {
    if len(os.args) == 2 {
        if os.args[1] == "-s" || os.args[1] == "--server" {
            Run_As_Server()
        }
        else {
            fmt.println("Error: unknown argument")
        }
    }
    else if len(os.args) > 2 {
        fmt.println("Error: too many arguments")
    }
    else {
        Run_As_Client()
    }
}

