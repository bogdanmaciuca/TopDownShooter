package main

import "core:fmt"
import sdl "vendor:sdl2"
import "core:container/queue"
import "core:strings"
import "core:mem"
import "core:os"
import "core:math/rand"
import "core:math/noise"

WND_W :: 1024
WND_H :: 768

CHAT_MAX_LINES :: 5
SCREEN_SHAKE_POWER :: 5
SCREEN_SHAKE_DIMINISHING_FACTOR :: 0.004
NOISE_SEED :: 69420

Startup_Screen :: proc(app: ^App) -> (cstring, cstring) {
    prompt : strings.Builder
    prompt = strings.builder_make()
    strings.write_bytes(&prompt, []byte{'U', 's', 'e', 'r', 'n', 'a', 'm', 'e', '/', 'S', 'e', 'r', 'v', 'e', 'r', ' ', 'I', 'P', ':', ' '}) // Is there no better way???

    event : sdl.Event
    input_loop : for {
        // Event handling
        if sdl.PollEvent(&event) {
            #partial switch event.type {
            case sdl.EventType.QUIT:
                App_Destroy(app)
                os.exit(0)
            case sdl.EventType.KEYDOWN:
                ascii_val := cast(i32)event.key.keysym.sym
                if event.key.keysym.mod == sdl.KMOD_LSHIFT || event.key.keysym.mod == sdl.KMOD_RSHIFT do ascii_val -= 32
                if ascii_val >= 'A' && ascii_val <= 'Z' || ascii_val >= 'a' && ascii_val <= 'z' \
                    || ascii_val == ' ' || ascii_val == '/' || ascii_val >= '0' && ascii_val <= '9' || ascii_val == '.'
                {
                    strings.write_byte(&prompt, cast(u8)ascii_val)
                }
                else if event.key.keysym.scancode == sdl.SCANCODE_BACKSPACE && strings.builder_len(prompt) > 20 {
                    strings.pop_byte(&prompt)
                }
                else if event.key.keysym.scancode == sdl.SCANCODE_RETURN {
                    break input_loop
                }
            }
        }
        App_Draw_Text(app, strings.to_string(prompt), 10, 10)
        App_Present(app)
    }

    str := strings.to_string(prompt)[20:] // TODO: must free this i think?
    fields := strings.split(str, "/")

    return strings.clone_to_cstring(fields[0]), strings.clone_to_cstring(fields[1]) // TODO: must also free this i think?
}

Run_As_Client :: proc() {
    app : App
    App_Init(&app, "Top Down Shooter", WND_W, WND_H)
    defer App_Destroy(&app)

    App_Load_Cursor("res/cursor.png")

    username, ip_str := Startup_Screen(&app)

    Net_Init()
    defer Net_Destroy()

    socket := Net_Socket_Create(0)
    defer Net_Socket_Destroy(socket)

    // TODO: If address is wrong go to the prompt again
    server_address := Net_Address_From_String(ip_str, PORT)
    fmt.println(server_address)

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

    screen_shake_factor : f32
    time_since_last_shot : f32

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
                    if time_since_last_shot > PLAYER_TIME_BETWEEN_SHOTS {
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
                        time_since_last_shot = 0

                        // Add screenshake
                        screen_shake_factor = rand.float32_range(0.6, 1.2) * SCREEN_SHAKE_POWER
                    }
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
        time_since_last_shot += delta_time
        Player_Update_Movement(&app, &players, player_id, map_mesh, delta_time)
        cursor_pos : [2]i32
        App_Get_Cursor_Pos(&cursor_pos.x, &cursor_pos.y)
        app.camera = 0.5 * {cast(f32)(cursor_pos.x - app.window_width/2), cast(f32)(cursor_pos.y - app.window_height/2)} + players[player_id].pos

        // Screen shake
        noise_coord := frame_start / 100
        app.camera.x += noise.noise_2d(NOISE_SEED, {noise_coord, -noise_coord}) * screen_shake_factor
        app.camera.y += noise.noise_2d(NOISE_SEED, {-noise_coord, noise_coord}) * screen_shake_factor
        screen_shake_factor -= SCREEN_SHAKE_POWER * SCREEN_SHAKE_DIMINISHING_FACTOR * delta_time
        if screen_shake_factor < 0 do screen_shake_factor = 0

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
        //App_Set_Color(&app, {200, 200, 200})
        Player_Draw_GUI(&app, &players[player_id])
        str : string
        for i in 0..<queue.len(chat) {
            str, _ = strings.concatenate({str, queue.get(&chat, i), "\n"})
        }
        App_Draw_Text(&app, str, 10, 10)
        App_Set_Color(&app, {0, 0, 0})
        App_Present(&app)

        frame_end := App_Get_Milli()
        delta_time = cast(f32)(frame_end - frame_start)
    }

    packet_content : Net_Packet_Content
    packet_content.disconnect.id = player_id
    Net_Send(socket, server_address, .Disconnect, &packet_content)
}

