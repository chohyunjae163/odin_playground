package main

import "core:fmt"
import "core:math/rand"
import "core:time"
//minesweeper
// size : 9 by 9 
// number of mines : 10
//two states 
//Empty square - can be represented as 0 -> num square
//mine square

mine :: -1
size :: 9
squares := [size*size]i8{}

main :: proc() {
    // 91 bytes 
    
    mine_pos : [10]int
    
    //place mines randomly
    t := time.now()
    unix_sec := time.to_unix_seconds(t)
    r := rand.create(u64(unix_sec))
    for i := 0 ; i < 10; {
        if random := i32(rand.float32(&r) * 100.0); random < size * size {
            squares[random] = mine
            i += 1
        }
    }

    //visual check for debugging
    for i in 0..< size * size {
        if i % 9 == 0 {
            fmt.println("")
        }
        fmt.print(i)
        fmt.print("\t")
    }
    

} 

step_empty_square :: proc( x , y : int) -> bool {
    return squares[x + (size * y)] == -1 
}

count_surrounding_mine :: proc( x : int , y : int) -> int {
    mine_num := 0
    index := x + (size * y)
    safe_right_bound := index % size < size - 1
    safe_left_bound := index % size > 0
    safe_top_bound := index - size >= 0
    safe_bottom_bound := index < size * size - size
    //right
    if safe_right_bound {
        //squares[index + 1]
    }
    //left
    if safe_left_bound  {
        //squares[index - 1]
    }
    //top
    if safe_top_bound {
        //squares[index - size] 
    }
    //bottom
    if safe_bottom_bound {
        //squares[index + size]
    }
    //top_left
    if safe_top_bound && safe_left_bound {
        //squares[index - size - 1] 
    }
    //top_right
    if safe_top_bound && safe_right_bound {
        //squares[index - size + 1]
    }
    //bottom_left
    if safe_bottom_bound && safe_left_bound {
        //squares[index + size - 1]
    }
    //bottom_right
    if safe_bottom_bound &&  safe_right_bound  {
        //squares[index + size + 1]
    }

    return mine_num
}
