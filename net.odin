/*
FORMAT:
- packet type    -> 4 bytes
- packet content -> 28 bytes
----------------------------
- sum            -> 32 bytes

Packet types:
- connect    -> 0 (client --> server)
- accept     -> 1 (client <-- server)
- disconnect -> 2 (client --> server)
- data       -> 3 (client <-> server)

[connect]:
- name -> 28 bytes

[disconnect]:
- id -> 2 bytes

[accept]:
- id         -> 2 bytes
- lobby_size -> 2 bytes
-----------------------
- sum        -> 4 bytes
* id starts from 0 and is used to index into the client array on the server;
negative numbers are errors:
  - -1 -> No more room

[data]:
- id      -> 4 bytes
- x       -> 4 bytes
- y       -> 4 bytes
- angle   -> 4 bytes
- vel_x   -> 4 bytes
- vel_y   -> 4 bytes
- ang_vel -> 4 bytes
---------------------
- sum     -> 28 bytes
*/

package main

import "core:fmt"
import "core:strings"
import "core:mem"
import sdl "vendor:sdl2"
import sdl_net "vendor:sdl2/net"

NET_RECV_RETRY_TIME :: 20 // Milliseconds
NET_PACKET_CAPACITY :: 32
NET_PACKET_SIZE :: 28
NET_CONN_TIMEOUT :: 2000 // Milliseconds

Net_UDP_Socket :: sdl_net.UDPsocket
Net_Address :: sdl_net.IPaddress
Net_UDP_Packet :: sdl_net.UDPpacket

Net_Packet_Type :: enum i32 {
    Connect = 0,
    Accept = 1,
    Disconnect = 2,
    Data = 3
}

Net_Packet_Content_Connect :: struct {
    name: [28]u8
}
Net_Packet_Content_Accept :: struct {
    id: i32,
    lobby_size: i32
}
Net_Packet_Content_Disconnect :: struct {
    id: i32
}
Net_Packet_Content_Data :: struct {
    id: i32,
    x: f32,
    y: f32,
    angle: f32,
    vel_x: f32,
    vel_y: f32,
    ang_vel: f32
}
Net_Packet_Content :: struct #raw_union {
    connect: Net_Packet_Content_Connect,
    accept: Net_Packet_Content_Accept,
    disconnect: Net_Packet_Content_Disconnect,
    data: Net_Packet_Content_Data
}
Net_Packet :: struct {
    type: Net_Packet_Type,
    content: Net_Packet_Content
}

Net_Socket :: struct {
    socket: Net_UDP_Socket,
    recv_packet: ^Net_UDP_Packet,
    send_packet: ^Net_UDP_Packet
}

Net_Init :: proc() {
    err := sdl_net.Init()
    assert(err == 0, sdl.GetErrorString())
}

Net_Destroy :: proc() {
    sdl_net.Quit()
}

// use port 0 for creating a client
Net_Socket_Create :: proc(port: u16) -> Net_Socket {
    socket : Net_Socket

    socket.socket = sdl_net.UDP_Open(port)
    assert(socket.socket != nil, sdl.GetErrorString())

    socket.recv_packet = sdl_net.AllocPacket(NET_PACKET_CAPACITY)
    socket.send_packet = sdl_net.AllocPacket(NET_PACKET_CAPACITY)

    return socket
}

Net_Socket_Destroy :: proc(socket: Net_Socket) {
    sdl_net.UDP_Close(socket.socket)
}

Net_Address_From_String :: proc(str: cstring, port: u16) -> Net_Address {
    address : Net_Address
    sdl_net.ResolveHost(&address, str, port)
    return address
}

// Initializes the packet with type DATA
Net_Packet_Content_From_Player :: proc(packet_content: ^Net_Packet_Content, player: ^Player) {
    packet_content.data.id = player.id
    packet_content.data.x = player.x
    packet_content.data.y = player.y
    packet_content.data.angle = player.angle
    packet_content.data.vel_x = player.vel_x
    packet_content.data.vel_y = player.vel_y
    packet_content.data.ang_vel = player.ang_vel
}

Net_Packet_Destroy :: proc(packet: ^Net_UDP_Packet) {
    sdl_net.FreePacket(packet)
}

// Returns -1 on error, 1 on packet received and 0 on no packet received
Net_Recv :: proc(socket: Net_Socket, packet: ^Net_Packet, address: ^Net_Address) -> i32 {
    result := sdl_net.UDP_Recv(socket.socket, socket.recv_packet)
    if address != nil do address^ = socket.recv_packet.address
    mem.copy(packet, socket.recv_packet.data, NET_PACKET_CAPACITY)

    return result
}

// timeout is in milliseconds
// Returns -1 on error, 1 on packet received and 0 on no packet received
Net_Recv_Blocking :: proc(socket: Net_Socket, packet: ^Net_Packet, address: ^Net_Address, timeout: u32) -> i32 {
    start := sdl.GetTicks()
    err : i32
    recv_result := Net_Recv(socket, packet, address)
    for sdl.GetTicks() - start < timeout {
        if recv_result == -1 do return -1
        else if recv_result == 1 do return 1
        recv_result = Net_Recv(socket, packet, address)
        sdl.Delay(NET_RECV_RETRY_TIME)
    }
    return 0
}

// Returns 0 on error and 1 if the package was sent
Net_Send :: proc(socket: Net_Socket, address: Net_Address, packet_type: Net_Packet_Type, packet_content: ^Net_Packet_Content) -> i32 {
    packet := Net_Packet{type = packet_type, content = packet_content^} // TODO: Would it be better if instead of dereferencing i would
    socket.send_packet.address = address                                //       just pass be value the array?
    socket.send_packet.channel = -1
    socket.send_packet.len = NET_PACKET_CAPACITY
    socket.send_packet.data = cast([^]u8)&packet
    return sdl_net.UDP_Send(socket.socket, -1, socket.send_packet)
}

/*
PROTOCOL:
- client sends a packet with their name
- server sends back a packet with the client's ID (or -1 if the connection is denied)
and the lobby size
*/
// Returns the ID the client must use when sending packets to the server
Net_Connect :: proc(socket: Net_Socket, address: Net_Address, name: cstring) -> (i32, i32) {
    // Send request with name
    packet_content : Net_Packet_Content
    mem.copy(&packet_content.connect.name, rawptr(name), 28)
    send_result := Net_Send(socket, address, Net_Packet_Type.Connect, &packet_content)
    assert(send_result == 1)

    // Wait for response from server
    packet : Net_Packet
    recv_result := Net_Recv_Blocking(socket, &packet, nil, NET_CONN_TIMEOUT)
    assert(recv_result == 1)
    return packet.content.accept.id, packet.content.accept.lobby_size
}

