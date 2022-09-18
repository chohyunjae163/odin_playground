package main

import "core:fmt"
import "core:math/rand"
import "core:time"
//minesweeper
// size : 9 by 9 
// number of mines : 10
//two states 
//Empty cell - can be represented as 0 -> num cell
//mine cell

mine :: -1
size :: 9

main :: proc() {
    // 91 bytes 
    ground := [size*size]i8{}
    mine_pos : [10]int
    
    //place mines randomly
    t := time.now()
    unix_sec := time.to_unix_seconds(t)
    r := rand.create(u64(unix_sec))
    for i := 0 ; i < 10; {
        if random := i32(rand.float32(&r) * 100.0); random < size * size {
            ground[random] = mine
            i += 1
        }
    }

    //visual check for debugging
    for i in 0.. = size*size {
        if i % 9 == 0 {
            fmt.println("")
        }
        fmt.print(ground[i])
        fmt.print("\t")
    }
    
    
} 
