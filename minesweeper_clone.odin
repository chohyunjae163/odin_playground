package main

import "core:fmt"
import "core:math/rand"
import "core:time"


//minesweeper
// size : 9 by 9 
// number of mines : 10
//unopened square 
//opened square
//flagged square
//mine square

closed_cell :: 9
mined_cell :: 10
flagged_cell :: 11
size : u8 : 9
cells : [size*size]u8

Position :: struct {
	x: u8,
	y: u8,
}

main :: proc() {
    // 91 bytes 
    
    //close cells
    for i in 0..< size * size {
        cells[i] = closed_cell
    }
    
    //place mines randomly
    //TODO: place mines after the first click
    mine_pos : [10]int
    t := time.now()
    unix_sec := time.to_unix_seconds(t)
    r := rand.create(u64(unix_sec))
    for i := 0 ; i < 10; {
        if random := u8(rand.float32(&r) * 100.0); random < size * size {
            cells[random] = mined_cell
            i += 1
        }
    }

    //visual check for debugging
    for i in 0..< size * size {
        if i % 9 == 0 {
            fmt.println("")
        }
        fmt.print(cells[i])
        fmt.print("\t")
    }
    
    // open cell
    // write number of mines around the cell if any
    // if no mines around, write -2 on the square and expand
    
    pos := Position { 0 , 0 }
    if cell := open_cell(pos); cell == mined_cell {
        //game over
        fmt.println("\n-------------------")
        fmt.println("step on a landmine!")
        fmt.println("-------------------\n")
    } else {
        expand: for {
            has_mine : bool

            break expand
        }
        mines_num := count_surrounding_mine(pos)
        cells[get_cell_index(pos)] = mines_num
        if mines_num == 0 {
           
        }
    }
}

get_cell_index :: proc(pos : Position) -> u8 {
    return pos.x + (size * pos.y)
}

open_cell :: proc(pos : Position) -> u8 {
    return cells[get_cell_index(pos)]
}

count_surrounding_mine :: proc(pos : Position) -> u8 {
    mine_num : u8 = 0
    index := get_cell_index(pos)
    fmt.println("\n\nINDEX : %d \n\n", index - size)
    safe_right_bound := index % size < size - 1
    safe_left_bound := index % size > 0
    safe_top_bound := index - size >= 0
    safe_bottom_bound := index < size * size - size
    //right
    if safe_right_bound {
        if cells[index + 1] == mined_cell {
            mine_num += 1
        }
    }
    //left
    if safe_left_bound  {
        if cells[index - 1]  == mined_cell  {
            mine_num += 1
        }
    }
    //top
    if safe_top_bound  {
        if cells[index - size] == mined_cell {
            mine_num += 1
        }
    }
    //bottom
    if safe_bottom_bound {
        if cells[index + size]  == mined_cell {
            mine_num += 1
        }
    }
    //top_left
    if safe_top_bound && safe_left_bound {
        if cells[index - size - 1]  == mined_cell {
            mine_num += 1
        }
    }
    //top_right
    if safe_top_bound && safe_right_bound {
        if cells[index - size + 1] == mined_cell {
            mine_num += 1
        }
    }
    //bottom_left
    if safe_bottom_bound && safe_left_bound {
        if cells[index + size - 1] == mined_cell {
            mine_num += 1
        }
    }
    //bottom_right
    if safe_bottom_bound &&  safe_right_bound  {
        if cells[index + size + 1] == mined_cell {
            mine_num += 1
        }
    }

    return mine_num
}
