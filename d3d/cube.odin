package main

import SDL "vendor:sdl2"
import D3D11 "vendor:directx/d3d11"
import D3D "vendor:directx/d3d_compiler"
import DXGI "vendor:directx/dxgi"
import "core:os"
import "core:math/linalg"

main :: proc() {
  //setup a CoreWindow with SDL
  SDL.Init({.VIDEO })
  defer SDL.Quit()

  SDL.SetHintWithPriority(SDL.HINT_RENDER_DRIVER,"direct3d11", .OVERRIDE)
  window := SDL.CreateWindow("D3D11 Cube in Odin",
                SDL.WINDOWPOS_CENTERED,SDL.WINDOWPOS_CENTERED,
                800,800,
                {.ALLOW_HIGHDPI, .HIDDEN, .RESIZABLE},
  )

  defer SDL.DestroyWindow(window)

  window_system_info : SDL.SysWMinfo
  SDL.GetVersion(&window_system_info.version)
  SDL.GetWindowWMInfo(window,&window_system_info)
  assert(window_system_info.subsystem == .WINDOWS)
  //ok now i have a window to draw in!

  //D3D11 setup
  //initialize d3d device and device context
  base_device: ^D3D11.IDevice
  base_device_context: ^D3D11.IDeviceContext
  feature_levels := [?]D3D11.FEATURE_LEVEL{._11_0}
  D3D11.CreateDevice(nil,.HARDWARE,nil,{.BGRA_SUPPORT},
        &feature_levels[0],len(feature_levels),
        D3D11.SDK_VERSION,&base_device,nil,&base_device_context)

  //ok now i have an interface to send data and give commands to GPU
  
  //create the swap chain
  swapchain_desc := DXGI.SWAP_CHAIN_DESC1 {
    Width = 0,
    Height = 0,
    Format = .B8G8R8A8_UNORM_SRGB,
    Stereo = false,
    SampleDesc = {
      Count = 1,
      Quality = 0,
    },
    BufferUsage = {.RENDER_TARGET_OUTPUT},
    BufferCount = 2,
    Scaling = .STRETCH,
    SwapEffect = .DISCARD,
    AlphaMode = .UNSPECIFIED,
    Flags = 0,
  }
  dxgi_device : ^DXGI.IDevice
  base_device->QueryInterface(DXGI.IDevice_UUID,(^rawptr)(&dxgi_device))
  dxgi_adapter : ^DXGI.IAdapter
  dxgi_device->GetAdapter(&dxgi_adapter)
  dxgi_factory : ^DXGI.IFactory2
  dxgi_adapter->GetParent(DXGI.IFactory2_UUID,(^rawptr)(&dxgi_factory))
  
  hwnd := DXGI.HWND(window_system_info.info.win.window)
  swap_chain: ^DXGI.ISwapChain1
  dxgi_factory->CreateSwapChainForHwnd(base_device,hwnd,&swapchain_desc,nil,nil,&swap_chain)

  //create a render target for drawing
  framebuffer : ^D3D11.ITexture2D
  swap_chain->GetBuffer(0,D3D11.ITexture2D_UUID,(^rawptr)(&framebuffer))
  framebuffer_view : ^D3D11.IRenderTargetView
  base_device->CreateRenderTargetView(framebuffer,nil,&framebuffer_view)

  //create depth stencil buffer. but why..?
  depth_buffer_desc : D3D11.TEXTURE2D_DESC 
  framebuffer->GetDesc(&depth_buffer_desc)
  depth_buffer_desc.Format = .D24_UNORM_S8_UINT
  depth_buffer_desc.BindFlags = {.DEPTH_STENCIL}

  depth_buffer : ^D3D11.ITexture2D
  base_device->CreateTexture2D(&depth_buffer_desc,nil,&depth_buffer)
  depth_buffer_view : ^D3D11.IDepthStencilView
  base_device->CreateDepthStencilView(depth_buffer,nil,&depth_buffer_view)  
  
  //setup a viewport
  viewport := D3D11.VIEWPORT {
    TopLeftX = 0, TopLeftY = 0,
    Width = f32(depth_buffer_desc.Width),
    Height = f32(depth_buffer_desc.Height),
    MinDepth=0, MaxDepth=1,
  }
  base_device_context->RSSetViewports(1,&viewport)

  //define constant buffers to store uniform data
  using linalg
  Vector3 :: [3]f32
  up_vector :: Vector3{0,1,0}
  cube_pos :: Vector3 {0,0,0}  
  cam_pos :: Vector3{0,0,-3}
  cam_forward := normalize(cube_pos - cam_pos)
  cam_right := cross(up_vector,cam_forward)
  cam_up := cross(cam_forward,cam_right)
  x := -dot(cam_right,cam_pos)
  y := -dot(cam_up,cam_pos)
  z := -dot(cam_forward,cam_pos)
  Mat4f :: matrix[4,4]f32
  world_matrix : Mat4f = {
     1,0,0,0,
     0,1,0,0,
     0,0,1,0,
     0,0,0,1,
  }
  view_matrix : Mat4f  = {
   cam_right[0],cam_up[0],cam_forward[0],x,
   cam_right[1],cam_up[1],cam_forward[1],y,
   cam_right[2],cam_up[2],cam_forward[2],z,
   0,0,0,1,
  }
  f := f32(9)
  n := f32(1)
  x_scale := f32(1.4281)
  y_scale := f32(1.4281)
  projection_matrix : Mat4f = {
  	x_scale , 0,         0,           0,
	0,  y_scale,         0,           0,
	0,  0,      f / (f - n), n * f / (n - f),
	0,  0,               1,           0,
  }
  Constants :: struct #align 16 {
    world      :  Mat4f,
    view       :  Mat4f,
    projection :  Mat4f,
  }
  constants_data : Constants
  constants_data.world = world_matrix
  constants_data.view = view_matrix  
  constants_data.projection = projection_matrix
  constant_buffer_desc := D3D11.BUFFER_DESC {
    ByteWidth = size_of(Constants),
    Usage = .DYNAMIC,
    BindFlags = {.CONSTANT_BUFFER},
    CPUAccessFlags = {.WRITE},
  }
  constant_buffer : ^D3D11.IBuffer
  base_device->CreateBuffer(&constant_buffer_desc,nil,&constant_buffer)
  
  //define vertex buffers to hold objet vertex data.
  //vertex data position , color
  vertex_data := [?]f32 {
	-0.5,0.5,-0.5, 0.0,1.0,0.0,
	0.5,0.5,-0.5,  0.0,1.0,0.0,
	0.5,0.5,0.5,   0.0,1.0,1.0,
	-0.5,0.5,0.5,  0.0,1.0,0.0,

	-0.5,-0.5,0.5, 0.0,0.0,1.0,
	0.5, -0.5,0.5, 0.0,1.0,0.0,
	0.5, -0.5,-0.5,0.0,1.0,0.0,
	-0.5,-0.5,-0.5,0.0,1.0,1.0,
  }
  vertex_buffer_desc := D3D11.BUFFER_DESC {
    ByteWidth = size_of(vertex_data),
    Usage = .IMMUTABLE,
    BindFlags = {.VERTEX_BUFFER},
  }
  vertex_buffer : ^D3D11.IBuffer
  base_device->CreateBuffer(
                &vertex_buffer_desc,
                &D3D11.SUBRESOURCE_DATA{
                  pSysMem=&vertex_data[0],
                  SysMemPitch=size_of(vertex_data)},
                &vertex_buffer)
  vertex_stride := u32(6 * 4)
  vertex_offset := u32(0)
      
  //define corresponding index buffers to enable the vertex shader
  indices_data := [?]u32{
	0,1,2,
	0,2,3,

	4,5,6,
	4,6,7,

	3,2,5,
	3,5,4,

	2,1,6,
	2,6,5,

	1,7,6,
	1,0,7,

	0,3,4,
	0,4,7,
  }

  index_buffer_desc := D3D11.BUFFER_DESC {
    ByteWidth = size_of(indices_data),
    Usage = .IMMUTABLE,
    BindFlags = {.INDEX_BUFFER },
  }
  index_buffer : ^D3D11.IBuffer
  base_device->CreateBuffer(
                &index_buffer_desc,
                &D3D11.SUBRESOURCE_DATA{
                  pSysMem=&indices_data[0],
                  SysMemPitch=size_of(indices_data)},
                &index_buffer)

  //vertex shader
  vs_blob : ^D3D11.IBlob
  vs_filepath := "../vs_cube.hlsl"
  vs_data,vs_ok := os.read_entire_file_from_filename(vs_filepath,context.allocator)
  assert(vs_ok)
  D3D.Compile(raw_data(vs_data),len(vs_data),
              "vs_cube.hlsl",nil,nil,
              "vs_main","vs_5_0",
              0,0,&vs_blob,nil)
  assert(vs_blob != nil)
  vertex_shader : ^D3D11.IVertexShader
  base_device->CreateVertexShader(vs_blob->GetBufferPointer(),vs_blob->GetBufferSize(),
                                  nil,&vertex_shader)
       
  assert(vertex_shader != nil)
  input_element_desc := [?]D3D11.INPUT_ELEMENT_DESC{
    { "POS", 0, .R32G32B32_FLOAT, 0,                            0, .VERTEX_DATA, 0 },
    { "COL", 0, .R32G32B32A32_FLOAT, 0, D3D11.APPEND_ALIGNED_ELEMENT, .VERTEX_DATA, 0 },
  }
  input_layout : ^D3D11.IInputLayout
  base_device->CreateInputLayout(&input_element_desc[0],len(input_element_desc),
                                  vs_blob->GetBufferPointer(),vs_blob->GetBufferSize(),
                                  &input_layout)
  //pixel shader
  ps_blob : ^D3D11.IBlob
  ps_filepath := "../ps_color.hlsl"
  ps_data,ps_ok := os.read_entire_file_from_filename(ps_filepath,context.allocator)
  assert(ps_ok)
  ps_hs := D3D.Compile(raw_data(ps_data),
                      len(ps_data),
                      "ps_color.hlsl",
                      nil,nil,
                      "ps_main","ps_5_0",
                      0,0,&ps_blob,nil)
  pixel_shader : ^D3D11.IPixelShader
  base_device->CreatePixelShader(
                ps_blob->GetBufferPointer(),
                ps_blob->GetBufferSize(),
                nil,
                &pixel_shader)

  assert(pixel_shader != nil)
  //Show a window
  SDL.ShowWindow(window)

  rasterizer_desc := D3D11.RASTERIZER_DESC{
	FillMode = .WIREFRAME,
	CullMode = .BACK,
    DepthBias = 0,
    FrontCounterClockwise = true,
  }
  rasterizer_state: ^D3D11.IRasterizerState
  base_device->CreateRasterizerState(&rasterizer_desc, &rasterizer_state)
  
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
    
	mapped_subresource: D3D11.MAPPED_SUBRESOURCE
	base_device_context->Map(constant_buffer, 0, .WRITE_DISCARD, {}, &mapped_subresource)
	{
		constants := (^Constants)(mapped_subresource.pData)
        constants.world = world_matrix
        constants.view = view_matrix
		constants.projection = projection_matrix
	}
	base_device_context->Unmap(constant_buffer, 0)    
    
    //render
    base_device_context->ClearRenderTargetView(framebuffer_view,&[4]f32{0.0,0.0,0.0,1.0})
    base_device_context->ClearDepthStencilView(depth_buffer_view,{.DEPTH},1,0)

    //input assembler stage begins
    base_device_context->IASetPrimitiveTopology(.TRIANGLELIST)
    //define input layout before creating a vertex buffer
    base_device_context->IASetInputLayout(input_layout)
    base_device_context->IASetVertexBuffers(0,1,&vertex_buffer,&vertex_stride,&vertex_offset)
    base_device_context->IASetIndexBuffer(index_buffer,.R32_UINT,0)

    //vertex stage
    base_device_context->VSSetShader(vertex_shader,nil,0)
    base_device_context->VSSetConstantBuffers(0,1,&constant_buffer)
    //rasterize stage
    //base_device_context->RSSetViewports(1,&viewport)
    base_device_context->RSSetState(rasterizer_state)
    //pixel stage
    base_device_context->PSSetShader(pixel_shader,nil,0)

    //outer-merger stage
    base_device_context->OMSetRenderTargets(1,&framebuffer_view,depth_buffer_view)
    
    //executes the pipeline
    //this is when D3D communicates with the GPU to set drawing state, runs each
    //pipeline stage, and writes pixel results into the render target buffer 
    //resource for the display by the swap chain
    indices_len := len(indices_data)
    base_device_context->DrawIndexed((u32)(indices_len),0,0)

    swap_chain->Present(1,0)
  }
}
