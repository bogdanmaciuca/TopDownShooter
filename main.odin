/*
TODO:
- start networking
  - server
  - server should send a id to each player that they should use
to identify themselves
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
MAX_CLIENTS :: 4
NET_UPDATE_INTERVAL :: 1000 / 30 // Milliseconds

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

    player.id = Net_Connect(socket, server_address, "Dogshit")
    fmt.println(player.id)

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

            // Receiving packets
            packet_recv : Net_Packet
            recv_result := Net_Recv(socket, &packet_recv, nil)
            for recv_result != 0 {
                assert(recv_result != -1)
                fmt.println(packet_recv.type)
                recv_result = Net_Recv(socket, &packet_recv, nil)
            }

            // Send packets
            // ...
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

    clients : [MAX_CLIENTS]Player
    curr_client_id : i32 = 1

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

        // Receiving packets
        packet : Net_Packet = ---
        address : Net_Address = ---
        recv_result := Net_Recv(socket, &packet, &address)
        for recv_result != 0 {
            assert(recv_result != -1)

            packet_content : Net_Packet_Content
            #partial switch packet.type {
            case .Connect:
                fmt.println(cstring(&packet.content.connect.name[0]), "connected.")
                packet_content.accept.id = curr_client_id
                curr_client_id += 1
                Net_Send(socket, address, .Accept, packet_content)
            case .Disconnect:
            case .Data:
            }
            recv_result = Net_Recv(socket, &packet, &address)
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

