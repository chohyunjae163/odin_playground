package main

/*
/ hyunjaecho
/ 2023-05-31
/ skinning 
/ vertex blending 
/ enveloping, or 
/ skeleton-subspace deformation
/ hmm... gotta update the vertices with skeleton data... let's see..
*/


import SDL "vendor:sdl2"
import D3D11 "vendor:directx/d3d11"
import DXGI "vendor:directx/dxgi"
import D3D "vendor:directx/d3d_compiler"
import "core:image/png"
import "core:bytes"
import "core:math/linalg"
import "core:os"
import "core:math"
import "core:mem"
import "core:fmt"

main :: proc() {
  using fmt
  //tracking memory leak
  track : mem.Tracking_Allocator
  mem.tracking_allocator_init(&track,context.allocator)
  context.allocator = mem.tracking_allocator(&track)
  defer {
    if len( track.allocation_map ) > 0 {
    	for _,v in track.allocation_map {
    	  printf("%v leaked %v bytes. \n",v.location, v.size)
    	}
    	println()
    }
  }

  //load vertex data and index data
  skinned_submeshes := read_skel_mesh_from_file("./bin/YBot.dc")
  //load skeleton data
  bones := parse_skeleton_bone()
  //load animation data
  anim_frames : [dynamic]anim_frame
  defer delete(anim_frames)
  parse_anim(&anim_frames)
  //create a window with SDL2
  SDL.Init({.VIDEO})
  defer SDL.Quit()
  SDL.SetHintWithPriority(SDL.HINT_RENDER_DRIVER, "direct3d11", .OVERRIDE)
  window := SDL.CreateWindow("Skinning in Odin",
    SDL.WINDOWPOS_CENTERED,SDL.WINDOWPOS_CENTERED,
    800,800,
    {.ALLOW_HIGHDPI, .HIDDEN, .RESIZABLE})
  defer SDL.DestroyWindow(window)
  window_system_info : SDL.SysWMinfo
  SDL.GetVersion(&window_system_info.version)
  SDL.GetWindowWMInfo(window,&window_system_info)
  assert(window_system_info.subsystem == .WINDOWS)  
  
  // prepare a d3d11
  // create a device and a device context
  device : ^D3D11.IDevice
  device_context : ^D3D11.IDeviceContext
  {
    feature_levels := [?] D3D11.FEATURE_LEVEL { ._11_0 }
    D3D11.CreateDevice(nil,.HARDWARE,nil,{.BGRA_SUPPORT},
      &feature_levels[0],len(feature_levels),
      D3D11.SDK_VERSION,&device,nil,&device_context)
  }

  // create swap chain
  // swapchain : a series of virtual framebuffers used by
  // graphics card and graphics API
  swapchain : ^DXGI.ISwapChain1
  {
    dxgi_device : ^DXGI.IDevice
    device->QueryInterface(DXGI.IDevice_UUID,(^rawptr)(&dxgi_device))
    dxgi_adapter : ^DXGI.IAdapter
    dxgi_device->GetAdapter(&dxgi_adapter)
    dxgi_factory : ^DXGI.IFactory2
    dxgi_adapter->GetParent(DXGI.IFactory2_UUID,(^rawptr)(&dxgi_factory))
    swapchain_desc := DXGI.SWAP_CHAIN_DESC1 {
      Width = 0,
      Height = 0,
      Format = .B8G8R8A8_UNORM_SRGB,
      Stereo = false,
      SampleDesc = {
        Count = 1,
        Quality = 0,
      },
      BufferUsage = { .RENDER_TARGET_OUTPUT },
      BufferCount = 2,
      Scaling = .STRETCH,
      SwapEffect = .DISCARD,
      AlphaMode = .UNSPECIFIED,
      Flags = 0,
    }
    native_window := DXGI.HWND(window_system_info.info.win.window)
    dxgi_factory->CreateSwapChainForHwnd(device,
      native_window,
      &swapchain_desc,
      nil,nil,
      &swapchain)
  }

  // create framebuffer view
  framebuffer : ^D3D11.ITexture2D
  framebuffer_view : ^D3D11.IRenderTargetView
  {
    swapchain->GetBuffer(0,D3D11.ITexture2D_UUID,(^rawptr)(&framebuffer))
    device->CreateRenderTargetView(framebuffer,nil,&framebuffer_view)
  }

  //create depth buffer view
  depthbuffer_view : ^D3D11.IDepthStencilView
  depth_buffer_desc : D3D11.TEXTURE2D_DESC
  {
    framebuffer->GetDesc(&depth_buffer_desc)
    depth_buffer_desc.Format = .D24_UNORM_S8_UINT
    depth_buffer_desc.BindFlags = { .DEPTH_STENCIL }
    depthbuffer : ^D3D11.ITexture2D
    device->CreateTexture2D(&depth_buffer_desc,nil,&depthbuffer)
    device->CreateDepthStencilView(depthbuffer,nil,&depthbuffer_view)
   }
  
  // constant buffer
  using linalg
  Constants :: struct {
    mvp : linalg.Matrix4f32,
    bone_matrix : [112]linalg.Matrix4f32,
    bone_matrix_inv : [112]linalg.Matrix4f32,
  } 

  ref_pose : [112]Matrix4f32
  ref_pose_inv : [112]Matrix4f32
  for bone,i in bones {
    s : Matrix4f32 = {
      bones[i].scale.x,0,0,0,
      0,bones[i].scale.y,0,0,
      0,0,bones[i].scale.z,0,
      0,0,0,1,
    }
    t : Matrix4f32 = {
      1,0,0,bones[i].position.x,
      0,1,0,bones[i].position.y,
      0,0,1,bones[i].position.z,
      0,0,0,1,
    }
    q : Quaternionf32 
    q.w = bones[i].quaternion.w
    q.x = bones[i].quaternion.x
    q.y = bones[i].quaternion.y
    q.z = bones[i].quaternion.z
    r := matrix4_from_quaternion_f32(q)
    bone_matrix := s*r*t
    parent_bone_matrix := MATRIX4F32_IDENTITY
    
    if bone.parent > -1 {
      parent_bone_matrix = ref_pose[bone.parent]
    }
    ref_pose[i] = bone_matrix * parent_bone_matrix
    ref_pose_inv[i] = matrix4x4_inverse(ref_pose[i])
    ref_pose[i] *= ref_pose_inv[i]
  }
  constant_buffer : ^D3D11.IBuffer
  world_matrix := MATRIX4F32_IDENTITY 
  view_matrix : Matrix4f32
  projection_matrix : Matrix4f32
  {
    constant_buffer_desc := D3D11.BUFFER_DESC{
      ByteWidth        = size_of(Constants),
      Usage            = .DYNAMIC,
      BindFlags        = { .CONSTANT_BUFFER },
      CPUAccessFlags   = { .WRITE },
    }
    device->CreateBuffer(&constant_buffer_desc,nil,&constant_buffer)
 
    //view matrix
    cam_f : Vector3f32   =  {0,0,1}
    cam_u : Vector3f32   =  {0,1,0}
    cam_r : Vector3f32   =  {1,0,0}
    cam_p : Vector3f32   =  {0,1.5,-4}
    x:= -dot(cam_r,cam_p)
    y:= -dot(cam_u,cam_p)
    z:= -dot(cam_f,cam_p)
    view_matrix = {
      cam_r.x,cam_r.y,cam_r.z,x,
      cam_u.x,cam_u.y,cam_u.z,y,
      cam_f.x,cam_f.y,cam_f.z,z,
     0,0,0,1,
    }

    //perspective matrix
    f := f32(9)
    n := f32(1)
    x_scale := f32(1.4281)
    y_scale := f32(1.4281)
    projection_matrix = {
      x_scale,0,0,0,
      0,y_scale,0,0,
      0,0,f/(f-n),n*f/(n-f),
      0,0,1,0,
    }
  }

  //rasterizer
  rasterizer_state : ^D3D11.IRasterizerState
  {
    rasterizer_desc := D3D11.RASTERIZER_DESC {
      FillMode = .SOLID,
      CullMode = .BACK,
      DepthBias = 0,
      FrontCounterClockwise = true,
    }
    device->CreateRasterizerState(&rasterizer_desc,&rasterizer_state)
  }

  //viewport
  viewport := D3D11.VIEWPORT {
    0,0,
    f32(depth_buffer_desc.Width),
    f32(depth_buffer_desc.Height),
    0,1,
  }

  //sampler and textures  
  sampler_state : ^D3D11.ISamplerState
  body_texture_view : ^D3D11.IShaderResourceView
  exo_texture_view : ^D3D11.IShaderResourceView
  {
    sample_desc := D3D11.SAMPLER_DESC {
      Filter             = .MIN_MAG_MIP_POINT,
      AddressU           = .WRAP,
      AddressV           = .WRAP,
      AddressW           = .WRAP,
      ComparisonFunc     = .NEVER,
    }
    device->CreateSamplerState(&sample_desc,&sampler_state)
    
    TEXTURE_WIDTH  :: 2048
    TEXTURE_HEIGHT :: 2048

    texture_desc := D3D11.TEXTURE2D_DESC {
      Width                   = TEXTURE_WIDTH,
      Height                  = TEXTURE_HEIGHT,
      MipLevels               = 1,
      ArraySize               = 1,
      Format                  = .R8G8B8A8_UNORM_SRGB,
      SampleDesc              = { Count = 1 },
      Usage                   = .IMMUTABLE,
      BindFlags               = { .SHADER_RESOURCE },
    }
    
    // load body image and create a 2d texture
    body_img, err := png.load_from_file("./bin/BODY_diffuse.png")
    assert(err == nil)
    body_data := bytes.buffer_to_bytes(&body_img.pixels)
    body_texture_data := D3D11.SUBRESOURCE_DATA {
      pSysMem = &body_data[0],
      SysMemPitch = TEXTURE_WIDTH * 4,
    }
    body_texture : ^D3D11.ITexture2D
    device->CreateTexture2D(&texture_desc,&body_texture_data,&body_texture)
    device->CreateShaderResourceView(body_texture,nil,&body_texture_view)

    //load exo image and create a 2d texture
    exo_img, err_exo := png.load_from_file("./bin/EXO_diffuse.png")
    assert(err_exo == nil)
    exo_data := bytes.buffer_to_bytes(&exo_img.pixels)
    exo_texture_data := D3D11.SUBRESOURCE_DATA {
      pSysMem     = &exo_data[0],
      SysMemPitch = TEXTURE_WIDTH * 4,
    }
    exo_texture : ^D3D11.ITexture2D
    device->CreateTexture2D(&texture_desc,&exo_texture_data,&exo_texture)
    device->CreateShaderResourceView(exo_texture,nil,&exo_texture_view)
  }

  //shaders
  input_layout : ^D3D11.IInputLayout
  vertex_shader : ^D3D11.IVertexShader
  pixel_shader : ^D3D11.IPixelShader
  {
    shader_path := "shaders.hlsl"
    shaders_hlsl, ok := os.read_entire_file_from_filename(shader_path)

    //vertex shader
    vs_blob : ^D3D11.IBlob
    D3D.Compile(raw_data(shaders_hlsl),len(shaders_hlsl),
      "shaders.hlsl",nil,nil,"vs_main","vs_5_0",0,0,&vs_blob,nil)
    assert(vs_blob != nil)
    device->CreateVertexShader(
        vs_blob->GetBufferPointer(),
        vs_blob->GetBufferSize(),
        nil,
        &vertex_shader)

    //input layout
    input_element_desc := [?]D3D11.INPUT_ELEMENT_DESC {
		{"POS", 	0, .R32G32B32_FLOAT,	0,	0,	.VERTEX_DATA,0},
		{"NORM", 	0, .R32G32B32_FLOAT,	0,	D3D11.APPEND_ALIGNED_ELEMENT, .VERTEX_DATA,0},
		{"TEXCOORD",0, .R32G32_FLOAT,		0,	D3D11.APPEND_ALIGNED_ELEMENT, .VERTEX_DATA,0},
		{"BONES", 	0, .R32G32B32A32_UINT,	0,	D3D11.APPEND_ALIGNED_ELEMENT, .VERTEX_DATA,0},
		{"WEIGHT", 	0, .R32G32B32A32_FLOAT,	0,	D3D11.APPEND_ALIGNED_ELEMENT, .VERTEX_DATA,0},
	}
    device->CreateInputLayout(
      &input_element_desc[0],
      len(input_element_desc),
      vs_blob->GetBufferPointer(),
      vs_blob->GetBufferSize(),
      &input_layout)

    //pixel shader
    ps_blob : ^D3D11.IBlob
    D3D.Compile(
      raw_data(shaders_hlsl),
      len(shaders_hlsl),
      "shaders.hlsl",
      nil,nil,
      "ps_main","ps_5_0",0,0,
      &ps_blob,nil)
    device->CreatePixelShader(
      ps_blob->GetBufferPointer(),
      ps_blob->GetBufferSize(),
      nil,
      &pixel_shader)
  }

  anim_frame_index := 0
  cur_tick : u32 = SDL.GetTicks()
  last_tick := cur_tick 
  delta_tick := cur_tick - last_tick
  //sdl show window
  SDL.ShowWindow(window)
  for quit := false; !quit; {
    for e: SDL.Event; SDL.PollEvent(&e); {
      #partial switch e.type {
        case .QUIT:
          quit = true
        case .KEYDOWN:
          if e.key.keysym.sym == .ESCAPE {
            quit = true
          }
      }
    }
    
    last_tick = cur_tick
    cur_tick = SDL.GetTicks()//get millisec
    delta_tick += (cur_tick - last_tick)
    //update transform
    mapped_subresource : D3D11.MAPPED_SUBRESOURCE
    device_context->Map(constant_buffer,0,.WRITE_DISCARD,{},&mapped_subresource)
    {
      using linalg
      constants := (^Constants)(mapped_subresource.pData)
      constants.mvp = mul(projection_matrix,mul(view_matrix,world_matrix))

      num_anim_frame :: 86
      millisec_per_frame :: 1  * 1000
      if delta_tick > millisec_per_frame {
        anim_frame_index += 1
        anim_frame_index %= num_anim_frame
        delta_tick = 0
      }

      //anim_frame_index = 0
      //calculate idle anim bones
      anim_pose : [112]Matrix4f32
      for bone, i in bones {
        cur_anim_frame := anim_frames[anim_frame_index]
        cur_anim_frame_pos := cur_anim_frame.position[i]
        cur_anim_frame_quat := cur_anim_frame.quaternion[i]
        s :: MATRIX4F32_IDENTITY
        t := MATRIX4F32_IDENTITY
        t[3][0]=cur_anim_frame_pos.x
        t[3][1]=cur_anim_frame_pos.y
        t[3][2]=cur_anim_frame_pos.z
        q : Quaternionf32
        q.w = cur_anim_frame_quat.w
        q.x = cur_anim_frame_quat.x
        q.y = cur_anim_frame_quat.y
        q.z = cur_anim_frame_quat.z
        r := matrix4_from_quaternion_f32(q)
        anim_bone_matrix := s*r*t
        parent_anim_bone_matrix := MATRIX4F32_IDENTITY
        if bone.parent > -1 {
          parent_anim_bone_matrix = anim_pose[bone.parent]
        }
        anim_pose[i] = anim_bone_matrix * parent_anim_bone_matrix
      }
      
      skinned_pose : [112]Matrix4f32
      for bone, i in bones {
        skinned_pose[i] = ref_pose[i] * anim_pose[i]
      }
      constants.bone_matrix = skinned_pose
    }
    device_context->Unmap(constant_buffer,0)

    ////// rendering //////

    device_context->ClearRenderTargetView(framebuffer_view,&[4]f32{0,1,1,1})
    device_context->ClearDepthStencilView(depthbuffer_view,{.DEPTH},1,0)

    //input assembler stage
    device_context->IASetPrimitiveTopology(.TRIANGLELIST)
    device_context->IASetInputLayout(input_layout)

    //vertex stage
    device_context->VSSetShader(vertex_shader,nil,0)
    device_context->VSSetConstantBuffers(0,1,&constant_buffer)

    //pixel stage
    device_context->PSSetShader(pixel_shader,nil,0)
    device_context->PSSetSamplers(0,1,&sampler_state)

    //rasterize stage
    device_context->RSSetState(rasterizer_state)
    device_context->RSSetViewports(1,&viewport)

    for submesh,index in skinned_submeshes {
      
      vertex_data := submesh.vertex_data
      index_data := submesh.index_data

      //create a vertex_buffer
      vertex_buffer : ^D3D11.IBuffer
      {
        vertex_buffer_size := len(vertex_data) * vertex_size
        vertex_buffer_desc := D3D11.BUFFER_DESC {
          ByteWidth = (u32)(vertex_buffer_size),
          Usage     = .IMMUTABLE,
          BindFlags = { .VERTEX_BUFFER },
        }
        device->CreateBuffer(
        &vertex_buffer_desc,
        &D3D11.SUBRESOURCE_DATA{
          pSysMem = &vertex_data[0],
          SysMemPitch = 0,  
        },
        &vertex_buffer)
      }
      vertex_buffer_stride := (u32)(vertex_size)
      vertex_buffer_offset := (u32)(0)
      device_context->IASetVertexBuffers(0,1,
        &vertex_buffer,
        &vertex_buffer_stride,
        &vertex_buffer_offset)
        
      //create an index buffer
      index_buffer : ^D3D11.IBuffer
      {
        index_buffer_size := len(index_data) * 4
        index_buffer_desc := D3D11.BUFFER_DESC {
          ByteWidth = (u32)(index_buffer_size),
          Usage = .IMMUTABLE,
          BindFlags = { .INDEX_BUFFER },
        }
        device->CreateBuffer(
        &index_buffer_desc,
        &D3D11.SUBRESOURCE_DATA {
          pSysMem = &index_data[0],
          SysMemPitch = 0,
        },
        &index_buffer)
      }

      device_context->IASetIndexBuffer(index_buffer,.R32_UINT,0)
      if index == 1 || index == 2 || index == 5 {
        device_context->PSSetShaderResources(0,1,&body_texture_view)
      } else {
        device_context->PSSetShaderResources(0,1,&exo_texture_view)
      }

      //outer merger stage
      device_context->OMSetRenderTargets(1,&framebuffer_view,depthbuffer_view)
      device_context->DrawIndexed((u32)(len(index_data)),0,0)
    }

    swapchain->Present(1,0)
  }
}
