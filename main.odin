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

PORT :: 4000
NET_UPDATE_INTERVAL :: 1000 / 30

Run_As_Client :: proc() {
    app : App
    App_Init(&app, "Top Down Shooter", WND_W, WND_H)
    defer App_Destroy(&app)

    Net_Init()
    defer Net_Destroy()

    socket := Net_Socket_Create(0)
    defer Net_Socket_Destroy(socket)

    server_address := Net_Address_From_String("127.0.0.1", PORT)

    player : Player
    Player_Init(&app, &player, "res/blue.png")
    defer Player_Destroy(&player)

    packet := Net_Packet_Create(&player, server_address)

    event : sdl.Event
    delta_time : f32 = 0
    net_accumulator : f32 = 0
    game_loop : for {
        frame_start := App_Get_Milli()

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
            // Do shit:
            assert(Net_Send(socket, packet) == 1, sdl.GetErrorString())
        }

        frame_end := App_Get_Milli()
        delta_time = cast(f32)(frame_end - frame_start)
    }
}

Run_As_Server :: proc() {
    Net_Init()
    defer Net_Destroy()

    socket := Net_Socket_Create(PORT)
    defer Net_Socket_Destroy(socket)

    packet := Net_Packet_Create()
    defer Net_Packet_Destroy(packet)

    fmt.printfln("Listening on port {}.", PORT)
    event : sdl.Event
    main_loop : for {
        // Event handling
        if sdl.PollEvent(&event) {
            #partial switch event.type {
                case sdl.EventType.QUIT:
                    break main_loop
            }
        }

        // Receiving packets (and printing them)
        for recv_result := Net_Recv(socket, packet); recv_result != 0; recv_result = Net_Recv(socket, packet) {
            fmt.println("Received!!!")
            assert(recv_result != -1)
            data := cast(cstring)(packet.data)
            fmt.println(data)
        }
    }
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

