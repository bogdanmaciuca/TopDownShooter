package main

import "core:fmt"
import "core:mem"
import sdl "vendor:sdl2"

PORT :: 4000
NET_MAX_CLIENTS :: 4
DELAY_PER_FRAME :: 1 // <||
TIMEOUT :: 2000      // <||

// Returns the position of the first empty slot or -1 if there isn't one
Find_Empty_Slot :: proc(slot_array: []bool) -> i32 {
    for i in 0..<len(slot_array) {
        if slot_array[i] == false do return cast(i32)i
    }
    return -1
}
All_Slots_Empty :: proc(slot_array: []bool) -> bool {
    for i in 0..<len(slot_array) {
        if slot_array[i] == true do return false
    }
    return true
}

Run_As_Server :: proc(max_client_num: i32) {
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
                clients[id].x = recv_packet.content.data.x
                clients[id].y = recv_packet.content.data.y
                clients[id].angle = recv_packet.content.data.angle
                clients[id].vel_x = recv_packet.content.data.vel_x
                clients[id].vel_y = recv_packet.content.data.vel_y
                clients[id].ang_vel = recv_packet.content.data.ang_vel
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

