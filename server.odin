package main

import "core:fmt"
import "core:mem"
import "core:strings"
import sdl "vendor:sdl2"

PORT :: 4000
NET_MAX_CLIENTS :: 4
DELAY_PER_FRAME :: 1 // <||
TIMEOUT :: 2000      // <||

// Returns the position of the first empty slot or -1 if there isn't one
Find_Empty_Slot :: proc(slot_array: []bool) -> i8 {
    for i in 0..<len(slot_array) {
        if slot_array[i] == false do return cast(i8)i
    }
    return -1
}
All_Slots_Empty :: proc(slot_array: []bool) -> bool {
    for i in 0..<len(slot_array) {
        if slot_array[i] == true do return false
    }
    return true
}

// https://stackoverflow.com/questions/3746274/line-intersection-with-aabb-rectangle
Check_Ray_Segment :: proc(a1: [2]f32, a2: [2]f32, b1:[2]f32, b2: [2]f32) -> bool {
    b := a2 - a1
    d := b2 - b1
    b_dot_d_perp := b.x * d.y - b.y * d.x

    // if b dot d == 0, it means the lines are parallel so have infinite intersection points
    if b_dot_d_perp == 0 do return false

    c := b1 - a1;
    t := (c.x * d.x - c.x * d.x) / b_dot_d_perp
    if t < 0 || t > 1 do return false

    u := (c.x * b.y - c.y * b.x) / b_dot_d_perp
    if u < 0 || u > 1 do return false

    return true
}

Check_Ray_AABB :: proc(p0: [2]f32, p1: [2]f32, aabb: sdl.Rect) -> bool {
    // Top
    if Check_Ray_Segment(p0, p1, { cast(f32)aabb.x, cast(f32)aabb.y }, { cast(f32)aabb.x + cast(f32)aabb.w, cast(f32)aabb.y }) do return true
    // Bottom
    if Check_Ray_Segment(p0, p1, { cast(f32)aabb.x, cast(f32)aabb.y + cast(f32)aabb.h }, { cast(f32)aabb.x + cast(f32)aabb.w, cast(f32)aabb.y + cast(f32)aabb.h }) do return true
    // Left
    if Check_Ray_Segment(p0, p1, { cast(f32)aabb.x, cast(f32)aabb.y }, { cast(f32)aabb.x, cast(f32)aabb.y + cast(f32)aabb.h }) do return true
    // Right
    if Check_Ray_Segment(p0, p1, { cast(f32)aabb.x + cast(f32)aabb.w, cast(f32)aabb.y }, { cast(f32)aabb.x + cast(f32)aabb.w, cast(f32)aabb.y + cast(f32)aabb.h }) do return true
    // No intersection
    return false
}

Run_As_Server :: proc(max_client_num: i8) {
    Net_Init()
    defer Net_Destroy()

    socket := Net_Socket_Create(PORT)
    defer Net_Socket_Destroy(socket)

    clients := make([]Player, max_client_num)
    client_slots := make([]bool, max_client_num) // 0 for empty, 1 for occupied
    client_addresses := make([]Net_Address, max_client_num)
    packet_content_arr := make([]Net_Packet_Content, max_client_num)
    client_last_recv_time := make([]f32, max_client_num)


    game_started := false

    last_send_time : f32 = App_Get_Milli()

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
        recv_packet : Net_Packet // This is the received packet
        recv_address : Net_Address
        recv_result := Net_Recv(socket, &recv_packet, &recv_address)
        for recv_result != 0 {
            assert(recv_result != -1)
            packet_content : Net_Packet_Content // This is sent back to the client

            #partial switch recv_packet.type {
            case .Connect:
                // If lobby is full, then do not accept any more clients
                slot := Find_Empty_Slot(client_slots)
                if slot == -1 {
                    packet_content.accept.id = -1
                    Net_Send(socket, recv_address, .Accept, &packet_content)
                }
                else { // If the lobby is not full send .Accept message
                    client_slots[slot] = true
                    // Set ID, name and address of player
                    clients[slot].id = slot
                    mem.copy(&clients[slot].name[0], &recv_packet.content.connect.name[0], 28)
                    client_addresses[slot] = recv_address
                    // Setting width and height
                    clients[slot].image.width = PLAYER_IMG_W
                    clients[slot].image.height = PLAYER_IMG_H
                    // Construct the accept packet
                    packet_content.accept.id = slot
                    packet_content.accept.lobby_size = max_client_num
                    // Log
                    fmt.printfln("{} connected.", cstring(&clients[slot].name[0]))
                    // Send the packet
                    Net_Send(socket, recv_address, .Accept, &packet_content)
                }
            case .Disconnect:
                id := recv_packet.content.disconnect.id
                fmt.printfln("{} disconnected.", cstring(&clients[id].name[0]))
                client_slots[id] = false
            case .Data:
                id := recv_packet.content.data.id
                // Update the time the last packet was received
                client_last_recv_time[id] = App_Get_Milli()

                // Set client data
                clients[id].pos = recv_packet.content.data.pos
                clients[id].angle = recv_packet.content.data.angle
                clients[id].vel = recv_packet.content.data.vel
                clients[id].ang_vel = recv_packet.content.data.ang_vel
                clients[id].health = recv_packet.content.data.health

                // Calculate AABB
                Player_Calculate_AABB(&clients[id])
            case .Bullet:
                id := recv_packet.content.bullet.id
                ray_end : [2]f32 = {
                    cast(f32)recv_packet.content.bullet.target.x,
                    cast(f32)recv_packet.content.bullet.target.y
                }
                for i in 0..<len(clients) {
                    if cast(i8)i != id && Check_Ray_AABB(clients[id].pos, ray_end, clients[i].aabb) {
                        packet_content : Net_Packet_Content
                        packet_content.hit.damage = PLAYER_DMG
                        Net_Send(socket, client_addresses[cast(i8)i], .Hit, &packet_content)

                        message : string
                        message = strings.concatenate({string(cstring(&clients[id].name[0])), " killed ", string(cstring(&clients[i].name[0]))})
                        raw_string := transmute(mem.Raw_String)message

                        mem.copy(&packet_content.chat.message, raw_string.data, 48)
                        for addr in client_addresses do Net_Send(socket, addr, .Chat, &packet_content)
                    }
                }
            }
            recv_result = Net_Recv(socket, &recv_packet, &recv_address)
        }

        // Checking if all the players have disconnected to close the server
        if game_started && All_Slots_Empty(client_slots) {
            fmt.println("All clients have disconnected. Exitting.")
            break main_loop
        }

        // Checking if the lobby is full so the game can start
        if !game_started && Find_Empty_Slot(client_slots) == -1 {
            for i in 0..<max_client_num do client_last_recv_time[i] = App_Get_Milli()

            game_started = true
            fmt.println("Lobby is full, game started.")
        }

        // Checking if any client has not sent a packet in TIMEOUT ms after the game has started
        if game_started {
            for i in 0..<max_client_num {
                if client_slots[i] == true && App_Get_Milli() - client_last_recv_time[i] > TIMEOUT {
                    fmt.printfln("{} disconnected.", clients[i].name)
                    client_slots[i] = false
                }
            }
        }

        // Checking if the lobby if filled up
        if game_started {
            // Sending packets
            current_time := App_Get_Milli()
            if current_time > last_send_time + SEND_INTERVAL {
                last_send_time = current_time
                for i in 0..<max_client_num {
                    //if client_slots[i] {
                        Net_Packet_Content_From_Player(&packet_content_arr[i], &clients[i])
                    //}
                }
                for i in 0..<max_client_num {
                    //if client_slots[i] {
                        for j in 0..<max_client_num {
                            //if client_slots[j] {
                                Net_Send(socket, client_addresses[i], .Data, &packet_content_arr[j])
                            //}
                        }
                    //}
                }
            }
        }

        sdl.Delay(DELAY_PER_FRAME)
    }
}

