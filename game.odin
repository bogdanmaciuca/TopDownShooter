package main

import math "core:math"
import sdl "vendor:sdl2"

PLAYER_MAX_VEL :: 1

Player :: struct {
    image: App_Image,
    id: i32,
    name: [28]u8,
    x: f32,
    y: f32,
    angle: f32,
    vel_x: f32,
    vel_y: f32,
    ang_vel: f32
}

Player_Init :: proc(app: ^App, player: ^Player, sprite: cstring) {
    player.image = App_Load_Image(app, sprite, 0, 0)
}

Player_Destroy :: proc(player: ^Player) {
    App_Free_Image(player.image)
}

Player_Draw :: proc(app: ^App, player: Player) {
    App_Draw_Image(
        app, player.image,
        cast(i32)player.x - player.image.width / 2,
        cast(i32)player.y - player.image.height / 2,
        player.angle
    )
}

Player_Update :: proc(app: ^App, player: ^Player, delta_time: f32) {
    keyboard := sdl.GetKeyboardState(nil)

    player.vel_x, player.vel_y = 0, 0
    if keyboard[sdl.SCANCODE_W] == 1 do player.vel_y = -PLAYER_MAX_VEL
    else if keyboard[sdl.SCANCODE_S] == 1 do player.vel_y = PLAYER_MAX_VEL
    if keyboard[sdl.SCANCODE_A] == 1 do player.vel_x = -PLAYER_MAX_VEL
    else if keyboard[sdl.SCANCODE_D] == 1 do player.vel_x = PLAYER_MAX_VEL

    magnitude_2 := player.vel_x * player.vel_x + player.vel_y * player.vel_y
    if magnitude_2 > PLAYER_MAX_VEL * PLAYER_MAX_VEL {
        magnitude := math.sqrt(magnitude_2)
        player.vel_x = player.vel_x / magnitude * PLAYER_MAX_VEL
        player.vel_y = player.vel_y / magnitude * PLAYER_MAX_VEL
    }

    player.x += player.vel_x * delta_time
    player.y += player.vel_y * delta_time

    mouse_x, mouse_y : i32
    App_Get_Cursor_Pos(&mouse_x, &mouse_y)

    player.angle = math.to_degrees(math.atan2(
        cast(f32)mouse_y - (player.y + cast(f32)app.window_height / 2.0),
        cast(f32)mouse_x - (player.x + cast(f32)app.window_width / 2.0)
    ))
}

