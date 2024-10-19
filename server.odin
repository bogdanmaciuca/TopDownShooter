package main

import "core:fmt"
import sdl "vendor:sdl2"

PORT :: 4000
MAX_CLIENTS :: 4

Run_As_Server :: proc() {
    Net_Init()
    defer Net_Destroy()

    socket := Net_Socket_Create(PORT)
    defer Net_Socket_Destroy(socket)

    clients : [MAX_CLIENTS]Player
    curr_client_id : i32 = 0

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

