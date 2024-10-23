package main

import "core:fmt"
import "core:mem"
import sdl "vendor:sdl2"

PORT :: 4000
NET_MAX_CLIENTS :: 4
SEND_INTERVAL :: 20 // Milliseconds
DELAY_PER_FRAME :: 1 // Milliseconds

Run_As_Server :: proc(max_client_num: i32) {
    Net_Init()
    defer Net_Destroy()

    socket := Net_Socket_Create(PORT)
    defer Net_Socket_Destroy(socket)

    clients : [NET_MAX_CLIENTS]Player
    client_addresses : [NET_MAX_CLIENTS]Net_Address
    connected_clients_num : i32 = 0
    packet_content_arr : [NET_MAX_CLIENTS]Net_Packet_Content

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
                if connected_clients_num >= NET_MAX_CLIENTS {
                    packet_content.accept.id = -1
                    Net_Send(socket, recv_address, .Accept, &packet_content)
                }
                else {
                    packet_content.accept.id = connected_clients_num
                    mem.copy(&clients[connected_clients_num].name[0], &recv_packet.content.connect.name[0], 28)
                    client_addresses[connected_clients_num] = recv_address
                    fmt.println("{} connected.", cstring(&clients[connected_clients_num].name[0]))
                    connected_clients_num += 1
                    Net_Send(socket, recv_address, .Accept, &packet_content)
                }
            case .Disconnect:
                fmt.printfln("{} disconnected.", cstring(&clients[recv_packet.content.disconnect.id].name[0]))
            case .Data:
                clients[packet_content.data.id].x = packet_content.data.x
                clients[packet_content.data.id].y = packet_content.data.y
                clients[packet_content.data.id].angle = packet_content.data.angle
                clients[packet_content.data.id].vel_x = packet_content.data.vel_x
                clients[packet_content.data.id].vel_y = packet_content.data.vel_y
                clients[packet_content.data.id].ang_vel = packet_content.data.ang_vel
            }
            recv_result = Net_Recv(socket, &recv_packet, &recv_address)
        }

        // Checking if the lobby if filled up
        if connected_clients_num == max_client_num {

            // Sending packets
            current_time := App_Get_Milli()
            if current_time > last_send_time + SEND_INTERVAL {
                last_send_time = current_time
                for i in 0..<max_client_num {
                    Net_Packet_Content_From_Player(&packet_content_arr[i], &clients[i])
                }
                for i in 0..<max_client_num {
                    for j in 0..<max_client_num {
                        Net_Send(socket, client_addresses[i], .Data, &packet_content_arr[j])
                    }
                }
            }
        }

        sdl.Delay(DELAY_PER_FRAME)
    }
}

