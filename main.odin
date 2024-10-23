/*
TODO:
- make the server update all players every N milliseconds
- don t set len to max_capacity in net_send() if that s not necessary
- Send back a different color to each player that they will have throughtout the match
- connect multiple players to the server
*/

package main

import "core:fmt"
import "core:os"
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
        fmt.println("Error: too few arguments")
    }
    else {
        Run_As_Client()
    }
}

