package main

import "core:fmt"
import "core:bufio"
import "core:mem"
import "core:os"

/*
SubMeshCount (unsigned int / 4btye)
  for subMeshMeshCount
    IndexCount (unsigned int / 4byte)
    Index Value Arr (unsigned int / 4byte)
    VertexCount (unsigned int / 4byte)
    VertexValue (SkinnedMeshVertex / 64byte)

SkinnedMeshVertex
  position (float 3개 / 12byte)
  normal (float 3개 / 12byte)
  uv (float 2개 / 8byte)
  boneIndex (unsigned int 4개 / 16byte)
  wieght (float 4개 / 16byte)

*/

vector2 :: struct {
	x,y : f32,
}

vector3 :: struct {
	x,y,z :f32,
}

skinned_mesh_vertex :: struct {
	pos : vector3,
	norm : vector3,
	uv : vector2,
	bone_index : [4]u32,
	weight : [4]f32,
}

read_skel_mesh_from_file :: proc(s : string) -> ([dynamic]skinned_mesh_vertex,[dynamic]u32) {	
	data,ok := os.read_entire_file_from_filename(s)
	
	if !ok {
		fmt.eprintln("failed to load the file!")
		return nil,nil
	}

	defer delete(data) 
	
	vertex_data: [dynamic]skinned_mesh_vertex
	index_data : [dynamic]u32

	r : u32 = 0
	num_submesh : u32
	mem.copy(&num_submesh,&data[r],4)
	fmt.printf("num_submesh : %d \n",num_submesh)
	r += 4

	for _ in 0 ..< num_submesh {
		index_count : u32
		mem.copy(&index_count,&data[r],4)
		fmt.printf("index count : %d \n", index_count)
		r += 4

		index_buffer_size := r + (index_count * 4)
		for ; r < index_buffer_size; r += 4 {
			new_index : u32 = 0
			mem.copy(&new_index,&data[r],size_of(u32)) 
			append(&index_data,new_index)
		}

		vertex_count : u32
		mem.copy(&vertex_count,&data[r],4)
		r += 4
		fmt.printf("vertex count : %d  \n", vertex_count)	
		
		vertex_buffer_size := r + (vertex_count * size_of(skinned_mesh_vertex))
		for ; r < vertex_buffer_size; r += size_of(skinned_mesh_vertex) {
			new_vertex : skinned_mesh_vertex = {}
			mem.copy(&new_vertex,&data[r],size_of(skinned_mesh_vertex))
			append(&vertex_data,new_vertex)
		}
	}

	return vertex_data,index_data
}

/*
YBot.DC
(4560 764)
(30612 5104)
(3384 647)
(46332 8835)
(120 24)
(2760 482)
(7248 1388)
(72 28)
*/
