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
      println("-----binary search-----")
      fixed_array_size :: 10
      if len(os.args) < 2 {
        eprintln("command line argument is needed")
      }
      key := strconv.atoi(os.args[1])
      println("key is: ",key)
      nums := [fixed_array_size]int{ 1, 4, 6, 19, 23, 41, 70, 75,81, 88 }
      println("nums: ",nums)
      array_size := fixed_array_size
      middle_index := array_size / 2 
      value_in_middle := nums[middle_index]

      for key != nums[middle_index] {
        array_size = array_size / 2 
        if array_size < 2 {
          if key < nums[middle_index] {
            middle_index -= 1
          } else if key > nums[middle_index] {
            middle_index += 1
          }
        } else {
          if key < nums[middle_index] {
            middle_index = middle_index -  (array_size / 2)  
          } else if key > nums[middle_index] {
            middle_index = middle_index + (array_size / 2) 
          }
        }
      }

      println("the index of the key is:",middle_index)
    }

    //bubble sort
    {
      //compare two neighbouring values
      //traverse from left and swap if the number is bigger than the right one.
      //the purpose is to place the biggest number to the rightmost end 
      println("-----bubble sort-----")
      nums := [10]int{ 1, 5, 2, 6, 3, 64, 9, 43, 15, 7 }
      len_nums := len(nums)
      len_sorted := 0
      for i := 0; i < len_nums - len_sorted; i += 1 {
        for j := 0; j < len_nums - 1 - len_sorted; j +=1 {
          if nums[j] > nums[j + 1] {
            nums[j]     = nums[j] ~ nums[j+1]
            nums[j+1]   = nums[j] ~ nums[j+1]
            nums[j]     = nums[j] ~ nums[j+1]
          }
        }
        len_sorted += 1
      }
      println(nums)
    }

    //selection sort
    {
      //select the min value from the array and place it in the first place of the unsorted
      println("-----selection sort-----")
      nums := [10]int{ 1, 5, 2, 6, 3, 64, 9, 43, 15, 7 }
      min_val := nums[0]
      for num_sorted := 0 ; num_sorted < len(nums) ; num_sorted += 1 {
        min_val = nums[num_sorted]
        for j := num_sorted ; j < len(nums); j += 1 {
          if min_val > nums[j] {
            min_val = min_val ~ nums[j]
            nums[j] = min_val ~ nums[j]
            min_val = min_val ~ nums[j]
          }
        }
        nums[num_sorted] = min_val
      }
      println(nums)
    }
}
