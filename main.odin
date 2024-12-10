/*
TODO:
- Cannot connect to server?
- respawn player when health reaches 0 and send death to server
- add state to player
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

