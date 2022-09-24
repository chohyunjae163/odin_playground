//author: CHO HYUNJAE
//title: miesweeper-clone

package main

import "core:fmt"
import "core:math/rand"
import "core:time"
import "core:container/queue"
import "core:builtin"

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
searched : [size*size]bool

Position :: struct {
	x: u8,
	y: u8,
}

main :: proc() {
    //close cells
    for i in 0..< size * size {
        cells[i] = closed_cell
        searched[i] = false
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

    // open cell
    // write number of mines around the cell if any
    // if no mines around, write -2 on the square and expand
    
    pos := Position { 0 , 0 }
    if cell := cells[get_cell_index(pos)]; cell == mined_cell {
        //game over
        fmt.println("\n-------------------")
        fmt.println("step on a landmine!")
        fmt.println("-------------------\n")
    } else {
        unvisited : [dynamic]Position
        append(&unvisited,pos)
        offset := -1
        expand_once := false
        expand: for {     
            offset += 1
            if offset >= builtin.len(unvisited) {
                fmt.println("offset is larger than len(unvisited)")
                break expand
            }                   
            if cells[get_cell_index(unvisited[offset])] == mined_cell {
                fmt.println("this is mined cell")
                continue 
            }
            mines_num := count_surrounding_mine(unvisited[offset])
            fmt.println("mines_num ", mines_num)
            cells[get_cell_index(unvisited[offset])] = mines_num
            if expand_once && mines_num > 0 {
                fmt.println("expand ended. mines_num", mines_num)
                continue
            }
            surroundings := get_unvisited_cells(unvisited[offset])
            size := builtin.len(surroundings)
            for i := 0 ; i < size ; i += 1 {
                append(&unvisited,surroundings[i])
            }            

            expand_once = true
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
}

get_unvisited_cells :: proc (pos : Position) -> [dynamic]Position {
    cells : [dynamic]Position
    if is_safe_top_bound(pos) {
        top := Position { pos.x , pos.y - 1}
        if is_cell_intact(top) {
            append(&cells,top)
        }
        if is_safe_left_bound(pos) {
            left_top := Position { pos.x - 1 , pos.y - 1 }
            if is_cell_intact(left_top) {
                append(&cells, left_top)
            }
        }
        if is_safe_right_bound(pos) {
            right_top := Position {pos.x + 1 , pos.y - 1} 
            if is_cell_intact(right_top) {
                append(&cells,right_top)
            }
        }
    }
    
    if is_safe_bottom_bound(pos) {
        bottom := Position{pos.x , pos.y + 1}
        if is_cell_intact(bottom) {
            append(&cells,bottom)
        }
        
        if is_safe_left_bound(pos) {
            bottom_left := Position {pos.x - 1 , pos.y + 1}
            if is_cell_intact(bottom_left) {
                append(&cells,bottom_left)
            }
            
        }
        if is_safe_right_bound(pos) {
            bottom_right := Position {pos.x + 1 , pos.y + 1}
            if is_cell_intact(bottom_right) {
                append(&cells,bottom_right)
            }
        }
    }

    if is_safe_left_bound(pos) {
        left := Position {pos.x - 1 , pos.y}
        if is_cell_intact(left) {
            append(&cells,left)    
        }
    }
    if is_safe_right_bound(pos) {
        right := Position {pos.x + 1 , pos.y}
        if is_cell_intact(pos) {
            append(&cells,right)
        }
    }
    return cells
}

is_cell_intact :: proc(pos : Position) -> bool {
    return searched[get_cell_index(pos)] == false
}

is_safe_right_bound :: proc(pos : Position) -> bool {
    return get_cell_index(pos) % size < size - 1
}

is_safe_top_bound :: proc(pos : Position) -> bool {
    return get_cell_index(pos) >= size
}

is_safe_left_bound :: proc(pos : Position) -> bool {
    return get_cell_index(pos) % size > 0
}

is_safe_bottom_bound :: proc(pos : Position) -> bool {
    return get_cell_index(pos) < size * size - size
}

get_cell_index :: proc(pos : Position) -> u8 {
    return pos.x + (size * pos.y)
}

count_surrounding_mine :: proc(pos : Position) -> u8 {
    mine_num : u8 = 0
    index := get_cell_index(pos)
    safe_right_bound := is_safe_right_bound(pos)
    safe_left_bound := is_safe_left_bound(pos)
    safe_top_bound := is_safe_top_bound(pos)
    safe_bottom_bound := is_safe_bottom_bound(pos)
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
