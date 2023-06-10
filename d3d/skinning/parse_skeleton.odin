package main

import "core:fmt"
import "core:encoding/xml"
import "core:math/linalg"
import "core:strconv"

anim_frame :: struct {
  position    : [112]linalg.Vector4f32,
  quaternion  : [112]linalg.Vector4f32,
}

parse_anim :: proc(animation : ^[dynamic]anim_frame) {
  using fmt
  //load xml anim file
  doc,err := xml.load_from_file("Idle.xml",xml.DEFAULT_OPTIONS,xml.default_error_handler,context.allocator)
  if err != nil {
    eprintln("Error:",err)
  }
  defer xml.destroy(doc)

  attribute := doc.elements[0].attribs[0]
  assert(attribute.key == "FrameCount")
  elems := doc.elements[1:]
  num_elems := len(elems)
  num_frame := strconv.atoi(attribute.val)
  bone_index := 0
  for i := 0; i < num_frame; i+=1 {
    append(animation,anim_frame{})
  }
  for i := 0; i < num_elems; i += 1 {
    //ident - bone
    //ident - transform
    //ident - pos
    //ident - rot
    //ident - scale
    if elems[i].ident == "Bone" {
      for j := 0; j < num_frame; j += 1 {
        i+=1
        assert(elems[i].ident == "Transform")
        assert(elems[i].attribs[0].key == "Index")
        frame_index, ok := strconv.parse_int(elems[i].attribs[0].val)
        assert(frame_index == j)
        i+=1
        str_val1 := elems[i].value
        assert(elems[i].ident == "Position")
        pos := conv_string_to_vector4(elems[i].value)
        i+=1
        str_val2 := elems[i].value
        assert(elems[i].ident == "Rotation")
        quat := conv_string_to_vector4(str_val2)
        i+=1
        animation^[j].position[bone_index] = pos;
        animation^[j].quaternion[bone_index] = quat;
      } 
      bone_index += 1
    }
  }
}
