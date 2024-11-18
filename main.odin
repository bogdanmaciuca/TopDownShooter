/*
TODO:
- add GUI:
  - text box for username and IP
- camera that is between cursor and player
- cursor as sprite
- fire sprite at the tip of the gun (hard code the position)
- screen shake when shooting
- field of view (simple geometry/sprite?)
- respawn player when health reaches 0 and send death to server

- chat: print who joins and disconnects
- reliable udp
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
                Run_As_Server(i8(max_client_num))
            }
        }
        else {
            fmt.println("Error: unknown argument")
        }
    }
    else if len(os.args) > 3 {
        fmt.println("Error: too many arguments")
    }
    else if len(os.args) == 1 {
        Run_As_Client()
    }
    else {
        fmt.println("Error: wrong number of arguments")
    }
}

