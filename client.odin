package main

import "core:fmt"
import sdl "vendor:sdl2"
import "core:container/queue"
import "core:strings"
import "core:mem"

WND_W :: 1024
WND_H :: 768

CHAT_MAX_LINES :: 5

Run_As_Client :: proc(username: cstring) {
    app : App
    App_Init(&app, "Top Down Shooter", WND_W, WND_H)
    defer App_Destroy(&app)

    Net_Init()
    defer Net_Destroy()

    socket := Net_Socket_Create(0)
    defer Net_Socket_Destroy(socket)

    server_address := Net_Address_From_String("192.168.221.105", PORT)

    player_id, lobby_size := Net_Connect(socket, server_address, username)

    SPRITE_LOOKUP := [4]cstring{ "res/red.png", "res/blue.png", "res/yellow.png", "res/green.png" }
    players := make([]Player, lobby_size)
    for i in 0..<lobby_size do Player_Init(&app, &players[i], SPRITE_LOOKUP[i])

    game_map := App_Load_Image(&app, "res/map.jpg", 0, 0)
    map_mesh : Map_Mesh
    Map_Load(&map_mesh, "res/map_mesh.json")
    defer delete(map_mesh)

    players[player_id].id = player_id // The client
    Player_Init(&app, &players[player_id], SPRITE_LOOKUP[player_id])
    players[player_id].health = PLAYER_MAX_HEALTH
    players[player_id].ammo = PLAYER_MAX_AMMO

    chat : queue.Queue(string)
    queue.init(&chat, 0)

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
            case sdl.EventType.MOUSEBUTTONDOWN:
                if event.button.button == sdl.BUTTON_LEFT {
                    // TODO: Add minimum time between shots
                    cursor_x, cursor_y : i32
                    App_Get_Cursor_Pos(&cursor_x, &cursor_y)
                    target : [2]i32 = {
                        cursor_x + cast(i32)app.camera.x - app.window_width / 2,
                        cursor_y + cast(i32)app.camera.y - app.window_height / 2
                    }
                    packet_content : Net_Packet_Content
                    packet_content.bullet.id = player_id
                    packet_content.bullet.target = target
                    Net_Send(socket, server_address, .Bullet, &packet_content)
                }
            }
        }

        // Receiving packets
        recv_packet : Net_Packet
        recv_result := Net_Recv(socket, &recv_packet, nil)
        for recv_result != 0 {
            assert(recv_result != -1)
            #partial switch recv_packet.type {
            case .Data:
                if recv_packet.type == .Data && recv_packet.content.data.id != player_id {
                    players[recv_packet.content.data.id].pos = recv_packet.content.data.pos
                    players[recv_packet.content.data.id].vel = recv_packet.content.data.vel
                    players[recv_packet.content.data.id].angle = recv_packet.content.data.angle
                    players[recv_packet.content.data.id].ang_vel = recv_packet.content.data.ang_vel
                    players[recv_packet.content.data.id].health = recv_packet.content.data.health
                }
            case .Hit:
                players[player_id].health -= recv_packet.content.hit.damage
            case .Chat:
                queue.push(&chat, strings.clone(string(cstring(&recv_packet.content.chat.message[0]))))
                if queue.len(chat) > CHAT_MAX_LINES do queue.pop_front(&chat)
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
        Player_Update_Movement(&app, &players, player_id, map_mesh, delta_time)
        app.camera = players[player_id].pos

        // Rendering
        App_Draw_Image_i(&app, game_map, {0, 0}, 0)
        App_Set_Color(&app, {25, 150, 25})
        //for i in 0..<len(map_mesh) {
        //    App_Draw_Rect(&app, map_mesh[i])
        //}
        App_Set_Color(&app, {25, 25, 150})
        for i in 0..<lobby_size {
            Player_Draw(&app, &players[i], cast(i8)i != player_id)
            //App_Draw_Rect(&app, players[i].aabb)
        }
        App_Set_Color(&app, {200, 200, 200})
        Player_Draw_GUI(&app, &players[player_id])
        str : string
        for i in 0..<queue.len(chat) {
            str, _ = strings.concatenate({str, queue.get(&chat, i), "\n"})
        }
        App_Draw_Text(&app, str, 10, 10)
        App_Set_Color(&app, {0, 0, 0})
        App_Present(&app)

        frame_end := App_Get_Milli()
        delta_time = frame_end - frame_start
    }

    packet_content : Net_Packet_Content
    packet_content.disconnect.id = player_id
    Net_Send(socket, server_address, .Disconnect, &packet_content)
}

