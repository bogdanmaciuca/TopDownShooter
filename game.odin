package main

import "core:fmt"
import "core:strconv"
import "core:os"
import "core:math"
import "core:encoding/json"
import sdl "vendor:sdl2"

PLAYER_IMG_W :: 100 // These keep
PLAYER_IMG_H :: 50  // proportions
PLAYER_MAX_VEL :: 0.5
PLAYER_AABB_SHRINKING_FACTOR :: 0.1

PLAYER_MAX_HEALTH :: 100
PLAYER_MAX_AMMO :: 20
PLAYER_DMG :: 20

Player :: struct {
    image: App_Image,
    aabb: sdl.Rect,
    id: i8,
    health: i8,
    ammo: i8,
    name: [28]u8,
    pos: [2]f32,
    vel: [2]f32,
    angle: f32,
    ang_vel: f32
}

Map_Mesh :: [dynamic]sdl.Rect

Player_Init :: proc(app: ^App, player: ^Player, sprite: cstring) {
    player.image = App_Load_Image(app, sprite, PLAYER_IMG_W, PLAYER_IMG_H)
}

Player_Destroy :: proc(player: ^Player) {
    App_Free_Image(player.image)
}

// If predict is true then the procedure will take into account the velocity
// and add it to the player's position
Player_Draw :: proc(app: ^App, player: ^Player, predict: bool) {
    prediction : [2]f32
    predict_angle : f32
    if predict {
        prediction = player.vel * SEND_INTERVAL
        predict_angle = player.ang_vel * SEND_INTERVAL
    }
    App_Draw_Image(app, player.image, player.pos + prediction, player.angle + predict_angle)
}

Player_Draw_GUI :: proc(app: ^App, player: ^Player) {
    str := fmt.aprintf("HEALTH: %d\nAMMO: %d/%d", player.health, player.ammo, PLAYER_MAX_AMMO)
    App_Draw_Text(app, str, WND_W - 200, WND_H - 50)
}

// angle must be in radians!!!
Rotate_Point :: proc(point: ^[2]f32, center: [2]f32, angle: f32) {
    s := math.sin(angle)
    c := math.cos(angle)

    // Translate point to origin
    point.x -= center.x
    point.y -= center.y

    // Rotate point
    x_new := point.x * c - point.y * s
    y_new := point.x * s + point.y * c

    // Translate point back
    point.x = x_new + center.x
    point.y = y_new + center.y
}

Player_Calculate_AABB :: proc(player: ^Player) {
    rotated_rect : [4][2]f32 = {
        [2]f32{ player.pos.x - cast(f32)player.image.width / 2, player.pos.y - cast(f32)player.image.height / 2 },
        [2]f32{ player.pos.x + cast(f32)player.image.width / 2, player.pos.y - cast(f32)player.image.height / 2 },
        [2]f32{ player.pos.x + cast(f32)player.image.width / 2, player.pos.y + cast(f32)player.image.height / 2 },
        [2]f32{ player.pos.x - cast(f32)player.image.width / 2, player.pos.y + cast(f32)player.image.height / 2 }
    }

    Rotate_Point(&rotated_rect[0], player.pos, math.to_radians(player.angle))
    min := rotated_rect[0]
    max := rotated_rect[0]
    for i in 1..<len(rotated_rect) {
        Rotate_Point(&rotated_rect[i], player.pos, math.to_radians(player.angle))
        if rotated_rect[i].x < min.x do min.x = rotated_rect[i].x
        else if rotated_rect[i].x > max.x do max.x = rotated_rect[i].x
        if rotated_rect[i].y < min.y do min.y = rotated_rect[i].y
        else if rotated_rect[i].y > max.y do max.y = rotated_rect[i].y
    }
    player.aabb.x = cast(i32)(min.x + PLAYER_AABB_SHRINKING_FACTOR * (max.x - min.x))
    player.aabb.y = cast(i32)(min.y + PLAYER_AABB_SHRINKING_FACTOR * (max.y - min.y))
    player.aabb.w = cast(i32)((1 - 2 * PLAYER_AABB_SHRINKING_FACTOR) * (max.x - min.x))
    player.aabb.h = cast(i32)((1 - 2 * PLAYER_AABB_SHRINKING_FACTOR) * (max.y - min.y))
}

// Returns (correction_x, correction_y)
Resolve_AABB_Collision :: proc(player: ^Player, rect: sdl.Rect) -> [2]f32 {
    // Calculate half-extents
    a_half_w := cast(f32)player.aabb.w / 2.0
    a_half_h := cast(f32)player.aabb.h / 2.0
    b_half_w := cast(f32)rect.w / 2.0
    b_half_h := cast(f32)rect.h / 2.0

    // Find centers
    a_center_x := cast(f32)player.aabb.x + cast(f32)player.aabb.w / 2
    a_center_y := cast(f32)player.aabb.y + cast(f32)player.aabb.h / 2
    b_center_x := cast(f32)rect.x + b_half_w
    b_center_y := cast(f32)rect.y + b_half_h

    // Calculate the distance between centers
    delta_x := b_center_x - a_center_x
    delta_y := b_center_y - a_center_y

    // Calculate the overlap on each axis
    overlap_x := a_half_w + b_half_w - abs(delta_x)
    overlap_y := a_half_h + b_half_h - abs(delta_y)

    // If there's no overlap on either axis, there’s no collision
    if (overlap_x <= 0 || overlap_y <= 0) do return { 0, 0 }

    // Resolve collision by pushing along the axis with the least overlap
    if (overlap_x < overlap_y) {
        // Collision on X axis
        return { -(delta_x < 0 ? -overlap_x : overlap_x), 0 }
    } else {
        // Collision on Y axis
        return { 0, -(delta_y < 0 ? -overlap_y : overlap_y) }
    }
}

Player_Resolve_Collisions :: proc(players: ^[]Player, client_id: i8, map_mesh: Map_Mesh) {
    for i in 0..<len(players^) do Player_Calculate_AABB(&players^[i])
    // Check for overlapping with the map
    for i in 0..<len(map_mesh) {
        correction := Resolve_AABB_Collision(&players^[client_id], map_mesh[i])
        players^[client_id].pos += correction
    }
    // Check for overlapping with other players
    for i in 0..<len(players^) {
        if cast(i8)i != client_id {
            correction := Resolve_AABB_Collision(&players^[client_id], players^[i].aabb)
            players^[client_id].pos += correction
        }
    }
}

Player_Update_Movement :: proc(app: ^App, players: ^[]Player, client_id: i8, map_mesh: Map_Mesh, delta_time: f32) {
    keyboard := sdl.GetKeyboardState(nil)

    players[client_id].vel = { 0, 0 }
    if keyboard[sdl.SCANCODE_W] == 1 do players[client_id].vel.y = -PLAYER_MAX_VEL
    else if keyboard[sdl.SCANCODE_S] == 1 do players[client_id].vel.y = PLAYER_MAX_VEL
    if keyboard[sdl.SCANCODE_A] == 1 do players[client_id].vel.x = -PLAYER_MAX_VEL
    else if keyboard[sdl.SCANCODE_D] == 1 do players[client_id].vel.x = PLAYER_MAX_VEL

    magnitude_2 := players[client_id].vel.x * players[client_id].vel.x + players[client_id].vel.y * players[client_id].vel.y
    if magnitude_2 > PLAYER_MAX_VEL * PLAYER_MAX_VEL {
        magnitude := math.sqrt(magnitude_2)
        players[client_id].vel = players[client_id].vel / magnitude * PLAYER_MAX_VEL
    }

    players[client_id].pos += players[client_id].vel * delta_time

    Player_Resolve_Collisions(players, client_id, map_mesh)

    mouse_x, mouse_y : i32
    App_Get_Cursor_Pos(&mouse_x, &mouse_y)

    last_angle := players[client_id].angle
    players[client_id].angle = math.to_degrees(math.atan2(
        cast(f32)mouse_y - cast(f32)app.window_height / 2.0,
        cast(f32)mouse_x - cast(f32)app.window_width / 2.0
    ))
    players[client_id].ang_vel = (players[client_id].angle - last_angle) / SEND_INTERVAL
}

Map_Load :: proc(map_mesh: ^Map_Mesh, filepath: string) {
    content, success := os.read_entire_file(filepath)
    assert(success == true, "Error reading map file.")

    object, err := json.parse(content)
    assert(err == nil, "Error parsing map file.")

    rects := object.(json.Object)["layers"].(json.Array)[1].(json.Object)["objects"].(json.Array)
    for rect in rects {
        sdl_rect : sdl.Rect
        sdl_rect.x = cast(i32)rect.(json.Object)["x"].(f64)
        sdl_rect.y = cast(i32)rect.(json.Object)["y"].(f64)
        sdl_rect.w = cast(i32)rect.(json.Object)["width"].(f64)
        sdl_rect.h = cast(i32)rect.(json.Object)["height"].(f64)
        append(map_mesh, sdl_rect)
    }
}

