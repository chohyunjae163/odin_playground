package main

//parse skeleton xml file

import "core:fmt"
import "core:encoding/xml"
import "core:mem"
import "core:strconv"
import "core:math/linalg"
import "core:strings"
import "core:log"

bone :: struct {
  id       : int,
  parent   : int,
  position : linalg.Vector4f32,
  quaternion : linalg.Vector4f32,
  scale    : linalg.Vector4f32,
}

@(private="file")
conv_string_to_vector4 :: proc(s : string) -> linalg.Vector4f32 {
  using linalg
  ret : Vector4f32
  values := strings.split(s," ")
  defer delete(values)
  ok : bool
  ret.x,ok = strconv.parse_f32(values[0])
  assert(ok)
  ret.y,ok = strconv.parse_f32(values[1])
  assert(ok)
  ret.z,ok = strconv.parse_f32(values[2])
  assert(ok)
  ret.w = 1.0
  if len(values) > 3 {
    ret.w,ok = strconv.parse_f32(values[3])
    assert(ok)
  }
  return ret
}

//parse the skeleton!
parse_skeleton_bone :: proc() -> [112]bone {
  using fmt
  track : mem.Tracking_Allocator
  mem.tracking_allocator_init(&track,context.allocator)
  context.allocator = mem.tracking_allocator(&track)
  defer {
    if len(track.allocation_map) > 0 {
      println()
      for _,v in track.allocation_map {
        printf("%v Leaked %v bytes. \n", v.location, v.size)
      }      
    }
  }
  /*load_from_file :: proc(
    filename: string, 
    options := DEFAULT_OPTIONS, 
    error_handler := default_error_handler, 
    allocator := context.allocator) 
    -> (doc: ^Document, err: Error) 
  */
  doc, err := xml.load_from_file("skeleton.xml",xml.DEFAULT_OPTIONS,xml.default_error_handler,context.allocator)
  if err != nil {
    eprintln("something went wrong with parsing a file")
    eprintln("Error: ",err)
  }
  defer xml.destroy(doc)
  attribute := doc.elements[0].attribs[0]
  assert(attribute.key == "Count")
  bones : [112]bone
  m_bones := make(map[string]int)
  defer delete(m_bones)
  //hips has no parent so set it to -1.
  elems :=  doc.elements[1:]// the first element is skeleton count information.
  elem_count := len(elems)
  bone_count := strconv.atoi(attribute.val)
  bone_index := 0
  for elem_index := 0; elem_index < elem_count; elem_index += 1 {
    element := elems[elem_index]
    assert(element.ident == "Bone")
    bones[bone_index].id = bone_index
    attribs := element.attribs
    substrings := strings.split(attribs[0].val,":")
    defer delete(substrings)
    m_bones[substrings[1]] = bone_index
    bones[bone_index].parent= -1
    if len(attribs) > 1 {
      parent_attribute := strings.split(attribs[1].val,":")
      defer delete(parent_attribute)
      bones[bone_index].parent = m_bones[parent_attribute[1]]
    }
    
    bone_data := [3]^linalg.Vector4f32 {
      &bones[bone_index].position,
      &bones[bone_index].quaternion,
      &bones[bone_index].scale,
    }

    for i in 0..< 3 {
      elem_index+=1
      element = elems[elem_index]
      assert(len(element.value) > 0)
      bone_data[i]^ = conv_string_to_vector4(element.value)
    }
    
    bone_index += 1
  }
  
  println("xml parsing done.")

  return bones;
}
