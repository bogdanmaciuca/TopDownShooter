/*
TODO:
- start networking
  - server
  - sending player struct to server
    - server should keep track of all player positions
*/

package main

import "core:fmt"
import "core:os"
import sdl "vendor:sdl2"

main :: proc() {
    if len(os.args) == 2 {
        if os.args[1] == "-s" || os.args[1] == "--server" {
            Run_As_Server()
        }
        else {
            fmt.println("Error: unknown argument")
        }
    }
    else if len(os.args) > 2 {
        fmt.println("Error: too many arguments")
    }
    else {
        Run_As_Client()
    }
}

