package main

import "core:fmt"
import sdl "vendor:sdl2"

WND_W :: 1024
WND_H :: 768
BKG_COLOR : sdl.Color : { 150, 100, 150, 255 }
FONT_NAME :: "C64_Mono.ttf"
FONT_SIZE :: 16
FONT_COLOR : sdl.Color : { 255, 255, 255, 255 }
CHAR_SPACING :: 0
LINE_SPACING :: 2

NET_UPDATE_INTERVAL :: 20 // Milliseconds

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
    net_send_accumulator : f32 = 0
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

        // Receiving packets
        recv_packet : Net_Packet
        recv_result := Net_Recv(socket, &recv_packet, nil)
        for recv_result != 0 {
            assert(recv_result != -1)
            if recv_packet.type == .Data && recv_packet.content.data.id != player.id {
                fmt.println("Receiving data!!!")
            }
            recv_result = Net_Recv(socket, &recv_packet, nil)
        }

        // Sending packets
        net_send_accumulator += delta_time
        if net_send_accumulator > NET_UPDATE_INTERVAL {
            net_send_accumulator -= NET_UPDATE_INTERVAL

            packet_content : Net_Packet_Content
            Net_Packet_Content_From_Player(&packet_content, &player)
            Net_Send(socket, server_address, .Data, &packet_content)
        }

        frame_end := App_Get_Milli()
        delta_time = frame_end - frame_start
    }

    packet_content : Net_Packet_Content
    packet_content.disconnect.id = player.id
    Net_Send(socket, server_address, .Disconnect, &packet_content)
}


