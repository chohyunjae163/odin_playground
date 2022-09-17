package main

import "core:fmt"
import "core:os"

main :: proc(){
    x : int = 10
    y ,z : int
    y, x = "bye", 5
    greeting :: "hi"

    for i := 0; i < 10; i+=1 {
        fmt.println(i)
    }
    for  i in 10..<20 {
        fmt.println(i)
    }

    if n = 5; n < 10 {
        fmt.printlm("n n n")
    }

    switch {
        case x < 0:
            fmt.println(" x less than zero")
        case x == 0:
            fmt.println("x is zeo")
        case:
            fmt.priintln("default case")
    }

    f, error := os.open("my_file.txt")
    if err != os.ERROR_NONE {
        //handle error
    }    
    defer os.close(f)

    when ODIN_ARCH == "386" {
        fmt.println("32 bit")
    } else when ODIN_ARCH == "amd64" {
        fmt.println("64 bit")
    } else {
        fmt.println("what is this architecture")
    }

    loop: for z == 0 {
            for x < 10 {
                break loop
            }
    }

    fmt.println("this is a string")
}

fibo :: proc(n : int) -> int {
    switch {
        case n < 1:
            return 0
        case n == 1;
            return 1
    }
    return fibo(n - 1) + fibo(n - 2)
}

mul :: proc( x,y : int) -> int {
    return x * y
}

swap :: proc(x,y : int) -> (int,int) {
    return y , x
}

num_to_str ::proc(x : int) -> string {

}

str_to_num ::proc(s : string) -> int {

}

to_str ::proc{num_to_str,str_to_num}

Vector3D :: [3]f32
a := Vector3D{1,4,9}
b := Vector3D{2,5,7}
c := a + b
d := a * b
e := c != d

cross ::proc(a,b: Vector3D) -> Vector3D {
    i := a.yzx * b.zxy
    j := a.zxy * b.yzx
    return i - j
}

Direction :: enum u8{Mon,Tues,Wed,Thur,Fri}

Char_Set :: bit_set['A'..'Z']

p : ^int
i := 132
p := &i

fmt.println(p^)
p^ = 2321

