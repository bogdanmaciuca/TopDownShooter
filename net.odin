/*
FORMAT:
- packet type
- packet content

Packet types:
- connect    -> 0 (client --> server)
- accept     -> 1 (client <-- server)
- disconnect -> 2 (client --> server)
- data       -> 3 (client <-> server)
- hit        -> 4 (client --> server)
- death      -> 5 (client --> server)

[connect]:
- name -> 28 bytes

[disconnect]:
- id -> 1 byte

[accept]:
- id         -> 1 byte
- lobby_size -> 1 byte
-----------------------
- sum        -> 2 bytes
* id starts from 0 and is used to index into the client array on the server;
negative numbers are errors:
  - -1 -> No more room

TODO: make id 2 bytes and add state that is also 2 bytes (or just add another 4 bytes for state)
      (based on state, maybe get some animation going)
[data]:
- id      -> 2 bytes
- x       -> 4 bytes
- y       -> 4 bytes
- angle   -> 4 bytes
- vel_x   -> 4 bytes
- vel_y   -> 4 bytes
- ang_vel -> 4 bytes
- health  -> 2 bytes
---------------------
- sum     -> 28 bytes

[bullet]:
- id: player -> 4 bytes / 2 bytes maybe?
- endpoint   -> 8 bytes (i32, i32) maybe?
------------------------
- sum        -> 12 bytes

[hit]:
- damage -> 1 byte

[death]
*/

package main

import "core:fmt"
import "core:strings"
import "core:mem"
import sdl "vendor:sdl2"
import sdl_net "vendor:sdl2/net"

NET_RECV_RETRY_TIME :: 20 // Milliseconds
NET_PACKET_CAPACITY :: 48
NET_PACKET_SIZE :: 28
NET_CONN_TIMEOUT :: 2000  // Milliseconds
SEND_INTERVAL :: 20       // Milliseconds

MAX_CHAT_MSG_LEN :: 48

Net_UDP_Socket :: sdl_net.UDPsocket
Net_Address :: sdl_net.IPaddress
Net_UDP_Packet :: sdl_net.UDPpacket

Net_Packet_Type :: enum i8 {
    Connect,
    Accept,
    Disconnect,
    Data,
    Bullet,
    Hit,
    Chat,
    Death
}

Net_Packet_Content_Connect :: struct {
    name: [28]u8
}
Net_Packet_Content_Accept :: struct {
    id: i8,
    lobby_size: i8
}
Net_Packet_Content_Disconnect :: struct {
    id: i8
}
Net_Packet_Content_Data :: struct {
    id: i8,
    state: i8,
    health: i8,
    angle: f32,
    ang_vel: f32,
    pos: [2]f32,
    vel: [2]f32
}
Net_Packet_Content_Bullet :: struct {
    id: i8,
    target: [2]i32
}
Net_Packet_Content_Hit :: struct {
    damage: i8
}
Net_Packet_Content_Chat :: struct {
    message: [48]u8
}
Net_Packet_Content :: struct #raw_union {
    connect:     Net_Packet_Content_Connect,
    accept:      Net_Packet_Content_Accept,
    disconnect:  Net_Packet_Content_Disconnect,
    data:        Net_Packet_Content_Data,
    bullet:      Net_Packet_Content_Bullet,
    hit:         Net_Packet_Content_Hit,
    chat:        Net_Packet_Content_Chat
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
    error := sdl_net.ResolveHost(&address, str, port)
    assert(error == 0)
    return address
}

// Initializes the packet with type DATA
Net_Packet_Content_From_Player :: proc(packet_content: ^Net_Packet_Content, player: ^Player) {
    packet_content.data.id = player.id
    packet_content.data.state = cast(i8)player.state
    packet_content.data.health = player.health
    packet_content.data.pos = player.pos
    packet_content.data.angle = player.angle
    packet_content.data.vel = player.vel
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
    packet : Net_Packet = ---
    packet.type = packet_type
    if packet_content == nil do packet.content = packet_content^

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
Net_Connect :: proc(socket: Net_Socket, address: Net_Address, name: cstring) -> (i8, i8) {
    // Send request with name
    packet_content : Net_Packet_Content
    mem.copy(&packet_content.connect.name, rawptr(name), len(name))
    send_result := Net_Send(socket, address, Net_Packet_Type.Connect, &packet_content)
    assert(send_result == 1)

    // Wait for response from server
    packet : Net_Packet
    recv_result := Net_Recv_Blocking(socket, &packet, nil, NET_CONN_TIMEOUT)
    assert(recv_result == 1)
    return packet.content.accept.id, packet.content.accept.lobby_size
}

