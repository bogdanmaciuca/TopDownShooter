package main

import "core:strings"
import sdl "vendor:sdl2"
import sdl_net "vendor:sdl2/net"

NET_PACKET_SIZE :: 32

Net_Socket :: sdl_net.UDPsocket
Net_Address :: sdl_net.IPaddress
Net_Packet :: sdl_net.UDPpacket

Net_Init :: proc() {
    err := sdl_net.Init()
    assert(err == 0, sdl.GetErrorString())
}

Net_Destroy :: proc() {
    sdl_net.Quit()
}

Net_Socket_Create :: proc(port: u16) -> Net_Socket {
    socket := sdl_net.UDP_Open(port)
    assert(socket != nil, sdl.GetErrorString())
    return socket
}

Net_Socket_Destroy :: proc(socket: Net_Socket) {
    sdl_net.UDP_Close(socket)
}

Net_Address_From_String :: proc(str: cstring, port: u16) -> Net_Address {
    address : Net_Address
    sdl_net.ResolveHost(&address, str, port)
    return address
}

Net_Packet_Create_Empty :: proc() -> ^Net_Packet {
    packet := sdl_net.AllocPacket(NET_PACKET_SIZE)
    return packet
}
Net_Packet_Create_From_Player :: proc(player: ^Player, address: Net_Address) -> ^Net_Packet {
    packet := sdl_net.AllocPacket(NET_PACKET_SIZE)
    // Test:
    packet.address = address
    str := strings.unsafe_string_to_cstring("hello server i am player!!!")
    packet.len = len("hello server i am player!!!")
    packet.data = cast(^u8)str
    // ...
    return packet
}
Net_Packet_Create :: proc {
    Net_Packet_Create_Empty,
    Net_Packet_Create_From_Player
}

Net_Packet_Destroy :: proc(packet: ^Net_Packet) {
    sdl_net.FreePacket(packet)
}

// Returns -1 on error, 1 on packet received and 0 on no packet received
Net_Recv :: proc(socket: Net_Socket, packet: ^Net_Packet) -> i32 {
    return sdl_net.UDP_Recv(socket, packet)
}

// Returns 0 on error and 1 if the package was sent
Net_Send :: proc(socket: Net_Socket, packet: ^Net_Packet) -> i32 {
    return sdl_net.UDP_Send(socket, -1, packet)
}
