/*
TODO:
- add cli argument for server IP
- add shooting (raycasting): use AABB to check intersection
  - send message to a player if they have been hit
- add health bar (also send it every frame to the server)
- refactor functions to use [2] arrays instead of _x, _y
- camera that is between cursor and player
- cursor as sprite
- fire sprite at the tip of the gun (hard code the position)
- screen shake when shooting
- field of view (simple geometry/sprite?)

- find a way to make the interpolation smoother; until then, use
SEND_INTERVAL as an approximation
- don t set len to max_capacity in net_send() if that s not necessary
- when a new player tries to connect, search for an empty slot in the
client array and if an index is found send that as the player ID
*/

package main

import "core:fmt"
import "core:os"
import "core:strings"
import "core:strconv"
import sdl "vendor:sdl2"

main :: proc() {
    if len(os.args) == 3 {
        if os.args[1] == "-s" || os.args[1] == "--server" {
            max_client_num, ok := strconv.parse_int(os.args[2])
            if ok == false {
                fmt.println("Error: Second argument must be a number")
            }
            else {
                Run_As_Server(i32(max_client_num))
            }
        }
        else {
            fmt.println("Error: unknown argument")
        }
    }
    else if len(os.args) > 3 {
        fmt.println("Error: too many arguments")
    }
    else if len(os.args) == 2 {
        username := strings.unsafe_string_to_cstring(os.args[1])
        Run_As_Client(username)
    }
    else {
        fmt.println("Error: too few arguments")
    }
}

