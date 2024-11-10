package main

import "core:fmt"
import sdl "vendor:sdl2"

WND_W :: 1024
WND_H :: 768

Run_As_Client :: proc(username: cstring) {
    app : App
    App_Init(&app, "Top Down Shooter", WND_W, WND_H)
    defer App_Destroy(&app)

    Net_Init()
    defer Net_Destroy()

    socket := Net_Socket_Create(0)
    defer Net_Socket_Destroy(socket)

    server_address := Net_Address_From_String("127.0.0.1", PORT)

    player_id, lobby_size := Net_Connect(socket, server_address, username)

    game_map := App_Load_Image(&app, "res/map.jpg", 0, 0)
    SPRITE_LOOKUP := [4]cstring{ "res/red.png", "res/blue.png", "res/yellow.png", "res/green.png" }
    players := make([]Player, lobby_size)
    for i in 0..<lobby_size do Player_Init(&app, &players[i], SPRITE_LOOKUP[i])

    map_mesh : Map_Mesh
    Map_Load(&map_mesh, "res/map_mesh.json")
    defer delete(map_mesh)

    players[player_id].id = player_id // The client

    Player_Init(&app, &players[player_id], SPRITE_LOOKUP[player_id])

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

        // Receiving packets
        recv_packet : Net_Packet
        recv_result := Net_Recv(socket, &recv_packet, nil)
        for recv_result != 0 {
            assert(recv_result != -1)
            if recv_packet.type == .Data && recv_packet.content.data.id != player_id {
                players[recv_packet.content.data.id].x = recv_packet.content.data.x
                players[recv_packet.content.data.id].vel_x = recv_packet.content.data.vel_x
                players[recv_packet.content.data.id].y = recv_packet.content.data.y
                players[recv_packet.content.data.id].vel_y = recv_packet.content.data.vel_y
                players[recv_packet.content.data.id].angle = recv_packet.content.data.angle
                players[recv_packet.content.data.id].ang_vel = recv_packet.content.data.ang_vel
            }
            recv_result = Net_Recv(socket, &recv_packet, nil)
        }

        // Sending packets
        net_send_accumulator += delta_time
        if net_send_accumulator > SEND_INTERVAL {
            net_send_accumulator -= SEND_INTERVAL

            packet_content : Net_Packet_Content
            Net_Packet_Content_From_Player(&packet_content, &players[player_id])
            Net_Send(socket, server_address, .Data, &packet_content)
        }

        // Game logic
        Player_Update(&app, &players, player_id, map_mesh, delta_time)
        app.camera_x = players[player_id].x
        app.camera_y = players[player_id].y

        // Rendering
        App_Draw_Image(&app, game_map, 0, 0, 0)
        App_Set_Color(&app, {25, 150, 25})
        //for i in 0..<len(map_mesh) {
        //    App_Draw_Rect(&app, map_mesh[i])
        //}
        App_Set_Color(&app, {25, 25, 150})
        for i in 0..<lobby_size {
            Player_Draw(&app, &players[i], cast(i32)i != player_id)
        //    App_Draw_Rect(&app, players[i].aabb)
        }
        App_Set_Color(&app, {0, 0, 0})
        App_Present(&app)

        frame_end := App_Get_Milli()
        delta_time = frame_end - frame_start
    }

    packet_content : Net_Packet_Content
    packet_content.disconnect.id = player_id
    Net_Send(socket, server_address, .Disconnect, &packet_content)
}

