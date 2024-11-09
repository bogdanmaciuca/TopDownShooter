package main

import "core:fmt"
import "core:os"
import "core:math"
import "core:encoding/json"
import sdl "vendor:sdl2"

PLAYER_IMG_W :: 100 // These keep
PLAYER_IMG_H :: 60  // proportions
PLAYER_MAX_VEL :: 0.5

Player :: struct {
    image: App_Image,
    aabb: sdl.Rect,
    id: i32,
    name: [28]u8,
    x: f32,
    y: f32,
    angle: f32,
    vel_x: f32,
    vel_y: f32,
    ang_vel: f32
}

Map_Mesh :: [dynamic]sdl.Rect

Player_Init :: proc(app: ^App, player: ^Player, sprite: cstring) {
    player.image = App_Load_Image(app, sprite, PLAYER_IMG_W, PLAYER_IMG_H)
}

Player_Destroy :: proc(player: ^Player) {
    App_Free_Image(player.image)
}

Player_Draw :: proc(app: ^App, player: ^Player) {
    App_Draw_Image(app, player.image, cast(i32)player.x, cast(i32)player.y, player.angle)
}

// angle must be in radians!!!
Rotate_Point :: proc(point_x: ^f32, point_y: ^f32, center_x: f32, center_y: f32, angle: f32) {
    s := math.sin(angle);
    c := math.cos(angle);

    // Translate point to origin
    point_x^ -= center_x;
    point_y^ -= center_y;

    // Rotate point
    x_new := point_x^ * c - point_y^ * s;
    y_new := point_x^ * s + point_y^ * c;

    // Translate point back
    point_x^ = x_new + center_x;
    point_y^ = y_new + center_y;
}

Player_Calculate_AABB :: proc(player: ^Player) {
    rotated_rect : [4]sdl.FPoint = {
        sdl.FPoint{ player.x - cast(f32)player.image.width / 2, player.y - cast(f32)player.image.height / 2 },
        sdl.FPoint{ player.x + cast(f32)player.image.width / 2, player.y - cast(f32)player.image.height / 2 },
        sdl.FPoint{ player.x + cast(f32)player.image.width / 2, player.y + cast(f32)player.image.height / 2 },
        sdl.FPoint{ player.x - cast(f32)player.image.width / 2, player.y + cast(f32)player.image.height / 2 }
    }

    Rotate_Point(&rotated_rect[0].x, &rotated_rect[0].y, player.x, player.y, math.to_radians(player.angle))
    min_x, min_y := rotated_rect[0].x, rotated_rect[0].y
    max_x, max_y := rotated_rect[0].x, rotated_rect[0].y
    for i in 1..<len(rotated_rect) {
        Rotate_Point(&rotated_rect[i].x, &rotated_rect[i].y, player.x, player.y, math.to_radians(player.angle))
        if rotated_rect[i].x < min_x do min_x = rotated_rect[i].x
        else if rotated_rect[i].x > max_x do max_x = rotated_rect[i].x
        if rotated_rect[i].y < min_y do min_y = rotated_rect[i].y
        else if rotated_rect[i].y > max_y do max_y = rotated_rect[i].y
    }
    player.aabb.x, player.aabb.y = cast(i32)min_x, cast(i32)min_y
    player.aabb.w, player.aabb.h = cast(i32)(max_x - min_x), cast(i32)(max_y - min_y)
}

// Returns (correction_x, correction_y)
Resolve_AABB_Collision :: proc(player: ^Player, rect: sdl.Rect) -> (f32, f32) {
    // Calculate half-extents
    a_half_w := cast(f32)player.aabb.w / 2.0
    a_half_h := cast(f32)player.aabb.h/ 2.0
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
    if (overlap_x <= 0 || overlap_y <= 0) do return 0, 0

    // Resolve collision by pushing along the axis with the least overlap
    if (overlap_x < overlap_y) {
        // Collision on X axis
        return -(delta_x < 0 ? -overlap_x : overlap_x), 0
    } else {
        // Collision on Y axis
        return 0, -(delta_y < 0 ? -overlap_y : overlap_y)
    }
}

Player_Resolve_Collisions :: proc(player: ^Player, map_mesh: Map_Mesh) {
    Player_Calculate_AABB(player)
    for i in 0..<len(map_mesh) {
        correction_x, correction_y := Resolve_AABB_Collision(player, map_mesh[i])
        player.x += correction_x
        player.y += correction_y
    }
}

Player_Update :: proc(app: ^App, player: ^Player, map_mesh: Map_Mesh, delta_time: f32) {
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

    Player_Resolve_Collisions(player, map_mesh)

    mouse_x, mouse_y : i32
    App_Get_Cursor_Pos(&mouse_x, &mouse_y)

    player.angle = math.to_degrees(math.atan2(
        cast(f32)mouse_y - cast(f32)app.window_height / 2.0,
        cast(f32)mouse_x - cast(f32)app.window_width / 2.0
    ))
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

