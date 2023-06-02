package main

/*
/ hyunjaecho
/ 2023-05-31
/ skinning 
/ vertex blending 
/ enveloping, or 
/ skeleton-subspace deformation
*/


import SDL "vendor:sdl2"
import D3D11 "vendor:directx/d3d11"
import DXGI "vendor:directx/dxgi"
import D3D "vendor:directx/d3d_compiler"
import "core:image/png"
import "core:bytes"
import "core:math/linalg"
import "core:os"

main :: proc() {
  //load vertex data and index data
  skinned_submeshes := read_skel_mesh_from_file("./bin/YBot.dc")
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
  Constants :: struct {
    transform : matrix[4,4]f32,
  }
  using linalg
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
    cam_p : Vector3f32   =  {0,0,-2}
    x:= -dot(cam_r,cam_p)
    y:= -dot(cam_u,cam_p)
    z:= -dot(cam_f,cam_p)
    view_matrix : Matrix4f32 = {
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
    projection_matrix : Matrix4f32 = {
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
    
    //update transform
    mapped_subresource : D3D11.MAPPED_SUBRESOURCE
    device_context->Map(constant_buffer,0,.WRITE_DISCARD,{},&mapped_subresource)
    {
      using linalg
      constants := (^Constants)(mapped_subresource.pData)
      constants.transform = mul(projection_matrix,mul(view_matrix,world_matrix))
    }
    device_context->Unmap(constant_buffer,0)

    ////// rendering //////
    device_context->ClearRenderTargetView(framebuffer_view,&[4]f32{0,1,0,1})
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
