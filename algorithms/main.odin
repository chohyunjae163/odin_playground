package main

import "core:fmt"
import "core:os"
import "core:strconv"

//let's get some algorithms done!


main :: proc() {
    using fmt
    //divde and conquer

    //binary search
    // 1. 10 random numbers
    // 2. sort the numbers
    // 3. find a number
    {
      // let's find the key number!
      // compare the number and the one in the middle of the array
      // to find the one in the middle of the array
      // i need to get the middle index 
      // to get the middle index, i need to divide the size of the array in half 
      fixed_array_size :: 10
      if len(os.args) < 2 {
        eprintln("command line argument is needed")
      }
      key := strconv.atoi(os.args[1])
      nums := [fixed_array_size]int{ 1, 4, 6, 19, 23, 41, 70, 75,81, 88 }
      array_size := fixed_array_size
      middle_index := array_size / 2 
      value_in_middle := nums[middle_index]

      for key != nums[middle_index] {
        array_size = array_size / 2 
        if key < nums[middle_index] {
          middle_index = middle_index -  (array_size / 2)  
        } else if key > nums[middle_index] {
          middle_index = middle_index + (array_size / 2) 
        }
      }

      println("the index of the key is:",middle_index)
    }
}
