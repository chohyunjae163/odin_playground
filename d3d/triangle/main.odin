package main

import D3D11 "vendor:directx/d3d11"
import DXGI "vendor:directx/dxgi"
import D3D "vendor:directx/d3d_compiler"
import SDL "vendor:sdl2"
import "core:os"
import "core:math/linalg"

main ::proc() {
    //Get a CoreWindow for your app
    SDL.Init({.VIDEO})
	defer SDL.Quit()

	SDL.SetHintWithPriority(SDL.HINT_RENDER_DRIVER,"direct3d11",.OVERRIDE)
	window := SDL.CreateWindow("D3D11 in Odin",
								SDL.WINDOWPOS_CENTERED,SDL.WINDOWPOS_CENTERED,
								854,480,
								{.ALLOW_HIGHDPI,.HIDDEN,.RESIZABLE},)
	defer SDL.DestroyWindow(window)
	
	window_system_info : SDL.SysWMinfo
	SDL.GetVersion(&window_system_info.version)
	SDL.GetWindowWMInfo(window,&window_system_info)
	assert(window_system_info.subsystem == .WINDOWS)
	
	//get an interface for the Direct3D device and context
	//The first step to using Direct3D is to acquire an interface for the Direct3D hardware (the GPU)
	//Create the Direct3D 11 API device object and a corresponding context
	base_device: ^D3D11.IDevice  //a virtual representation of the GPU resources  
 	base_device_context: ^D3D11.IDeviceContext //a device-agnostic abstraction of the rendering pipeline and process
    feature_levels := [?]D3D11.FEATURE_LEVEL{._11_0}
	D3D11.CreateDevice(nil,.HARDWARE,nil,{.BGRA_SUPPORT},
	 					&feature_levels[0],len(feature_levels),D3D11.SDK_VERSION,&base_device,
	 					nil,&base_device_context)
	
	//Create the swap chain to display your rendered image in the CoreWindow.
	//call IDXGIFactory2::CreateSwapChainForHwnd 
    // must use the same DXGI factory that created the Direct3D device (and device context) in order to create the swap chain.
	swapchain_desc := DXGI.SWAP_CHAIN_DESC1{
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
		
	dxgi_device: ^DXGI.IDevice
	base_device->QueryInterface(DXGI.IDevice_UUID,(^rawptr)(&dxgi_device))
	dxgi_adapter: ^DXGI.IAdapter
	dxgi_device->GetAdapter(&dxgi_adapter)
	
	dxgi_factory : ^DXGI.IFactory2
	dxgi_adapter->GetParent(DXGI.IFactory2_UUID,(^rawptr)(&dxgi_factory))

	swapchain: ^DXGI.ISwapChain1
	native_window := DXGI.HWND(window_system_info.info.win.window)
	dxgi_factory->CreateSwapChainForHwnd(base_device,native_window,&swapchain_desc,nil,nil,&swapchain)

    //Create a render target for drawing and populate it with pixels
	framebuffer: ^D3D11.ITexture2D
	swapchain->GetBuffer(0,D3D11.ITexture2D_UUID,(^rawptr)(&framebuffer))
	framebuffer_view : ^D3D11.IRenderTargetView
	base_device->CreateRenderTargetView(framebuffer,nil,&framebuffer_view)

    // create a depth-stencil buffer.	
    depth_buffer_desc: D3D11.TEXTURE2D_DESC	
	framebuffer->GetDesc(&depth_buffer_desc)
	depth_buffer_desc.Format = .D24_UNORM_S8_UINT
	depth_buffer_desc.BindFlags = { .DEPTH_STENCIL }
	
	depth_buffer: ^D3D11.ITexture2D
	base_device->CreateTexture2D(
		&depth_buffer_desc,
		nil,
		&depth_buffer)
	depth_buffer_view: ^D3D11.IDepthStencilView
	base_device->CreateDepthStencilView(depth_buffer,nil,&depth_buffer_view)
	
	viewport := D3D11.VIEWPORT{
		0,0,
		f32(depth_buffer_desc.Width),f32(depth_buffer_desc.Height),
		0,1,
	}
	base_device_context->RSSetViewports(1,&viewport)
	
	//Define constant buffers to store your uniform data
	//define vertex shader
	vs_blob : ^D3D11.IBlob
	filepath := "triangle_vs.hlsl"
	data,ok := os.read_entire_file_from_filename(filepath,context.allocator)
	assert(ok)
	hs := D3D.Compile(
			raw_data(data), 
			len(data), 
			"triangle_vs.hlsl", 
			nil,nil, 
			"vs_main", "vs_5_0", 
			0, 0, &vs_blob, nil)
	assert(hs == 0)
	assert(vs_blob != nil)
	
	vertex_shader : ^D3D11.IVertexShader
	base_device->CreateVertexShader(vs_blob->GetBufferPointer(),vs_blob->GetBufferSize(),nil,&vertex_shader)
	
	//define input layout
	input_element_desc := [?]D3D11.INPUT_ELEMENT_DESC {
		{"POSITION",0,.R32G32_FLOAT,0,0,.VERTEX_DATA,0},
	}

	//define pixel shader
	ps_blob: ^D3D11.IBlob
	ps_filepath := "triangle_ps.hlsl"
	ps_data,ps_ok := os.read_entire_file_from_filename(ps_filepath,context.allocator)
	assert(ps_ok)
	ps_hs := D3D.Compile(
		raw_data(ps_data),len(ps_data),
		"triangle_ps.hlsl",
		nil,nil,
		"ps_main","ps_5_0",
		0,0,&ps_blob,nil)
	
	//Create an input-layout object to describe the 
	//input-buffer data for the input-assembler stage.
	input_layout : ^D3D11.IInputLayout
	base_device->CreateInputLayout(
				&input_element_desc[0],
				len(input_element_desc),
				vs_blob->GetBufferPointer(),
				vs_blob->GetBufferSize(),
				&input_layout)

	
	assert(ps_hs == 0)
	assert(ps_blob != nil)
	pixel_shader : ^D3D11.IPixelShader
	base_device->CreatePixelShader(
			ps_blob->GetBufferPointer(),
			ps_blob->GetBufferSize(),
			nil,
			&pixel_shader)
	
	//define a triangle
	//Define vertex buffers to hold your object vertex data, 
	//and corresponding index buffers to enable the vertex shader to walk the triangles correctly.
	triangle_vertices := [3]linalg.Vector2f32 {
		{ -0.5,-0.5 },
		{ 0.0, 0.5 },
		{ 0.5, -0.5},
	}
	triangle_indices := [3]u16 {
		0,1,2,
	}
	vertex_buffer_desc := D3D11.BUFFER_DESC {
		ByteWidth = size_of(triangle_vertices),
		Usage = .IMMUTABLE,
		BindFlags = { .VERTEX_BUFFER },
	}
	vertex_buffer : ^D3D11.IBuffer
	base_device->CreateBuffer(
					&vertex_buffer_desc,
					&D3D11.SUBRESOURCE_DATA{pSysMem = &triangle_vertices[0],SysMemPitch=size_of(triangle_vertices)},
					&vertex_buffer)

	//define index buffers
	index_buffer_desc := D3D11.BUFFER_DESC {
		ByteWidth = size_of(triangle_indices),
		Usage = .IMMUTABLE,
		BindFlags = { .INDEX_BUFFER },
	}
	index_buffer : ^D3D11.IBuffer
	base_device->CreateBuffer(
					&index_buffer_desc,
					&D3D11.SUBRESOURCE_DATA{pSysMem = &triangle_indices[0],SysMemPitch=size_of(triangle_indices)},
					&index_buffer,
	)
	vertex_buffer_stride := u32(size_of(linalg.Vector2f32))
	vertex_buffer_offset := u32(0)
	SDL.ShowWindow(window)
	for quit := false; !quit; {
		for e: SDL.Event; SDL.PollEvent(&e); {
			#partial switch e.type {
				case .QUIT:
					quit = true
				case .KEYDOWN:
					if e.key.keysym.sym == .ESCAPE {
						quit = true;
					}
			}
		}
		base_device_context->ClearRenderTargetView(framebuffer_view,&[4]f32{0.25,1,0,1.0})
		base_device_context->ClearDepthStencilView(depth_buffer_view,{.DEPTH},1,0)

		base_device_context->IASetPrimitiveTopology(.TRIANGLELIST)
		base_device_context->IASetInputLayout(input_layout)
		base_device_context->IASetVertexBuffers(0,1,&vertex_buffer,&vertex_buffer_stride,&vertex_buffer_offset)
		base_device_context->IASetIndexBuffer(index_buffer,.R32_UINT,0)
		base_device_context->VSSetShader(vertex_shader,nil,0)
		base_device_context->PSSetShader(pixel_shader,nil,0)
		base_device_context->OMSetRenderTargets(1,&framebuffer_view,depth_buffer_view)

		base_device_context->DrawIndexed(len(triangle_indices),0,0)
		swapchain->Present(1,0)
	}
}
