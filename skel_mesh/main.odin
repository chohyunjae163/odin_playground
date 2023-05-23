package main


import "core:fmt"
import "core:os"

import SDL "vendor:sdl2"
import D3D11 "vendor:directx/d3d11"
import DXGI "vendor:directx/dxgi"
import D3D "vendor:directx/d3d_compiler"




main :: proc() {
	/*vertex_buffer, index_buffer := read_skel_mesh_from_file("./bin/YBot.dc")
	if(vertex_buffer == nil || index_buffer == nil) {
		fmt.eprintln("buffers are nil...")
		return
	}

	defer delete(vertex_buffer)
	defer delete(index_buffer)
	*/
/////////// SETUP WINDOW //////////
	
	SDL.Init( { .VIDEO } )
	defer SDL.Quit()

	SDL.SetHintWithPriority(SDL.HINT_RENDER_DRIVER,"direct3d11", .OVERRIDE)
	window := SDL.CreateWindow("D3D11 in Odin",
		SDL.WINDOWPOS_CENTERED,SDL.WINDOWPOS_CENTERED,
		1600,900,
		{.ALLOW_HIGHDPI, .HIDDEN, .RESIZABLE},
	)
	defer SDL.DestroyWindow(window)

	window_sys_info : SDL.SysWMinfo
	SDL.GetVersion(&window_sys_info.version)
	SDL.GetWindowWMInfo(window,&window_sys_info)
	assert(window_sys_info.subsystem == .WINDOWS)

	/////////// D3D11 SETUP //////////

	feature_levels := [?]D3D11.FEATURE_LEVEL{ ._11_0 }
	device : ^D3D11.IDevice
	device_context : ^D3D11.IDeviceContext
	D3D11.CreateDevice(nil, .HARDWARE, nil, {.BGRA_SUPPORT}, &feature_levels[0],
		len(feature_levels), D3D11.SDK_VERSION, &device, nil, &device_context)

	dxgi_device : ^DXGI.IDevice
	device->QueryInterface(DXGI.IDevice_UUID,(^rawptr)(&dxgi_device))
	dxgi_adapter : ^DXGI.IAdapter
	dxgi_device->GetAdapter(&dxgi_adapter)
	dxgi_factory : ^DXGI.IFactory2
	dxgi_adapter->GetParent(DXGI.IFactory2_UUID,(^rawptr)(&dxgi_factory))

	swapchain_desc := DXGI.SWAP_CHAIN_DESC1 {
		Width = 0, Height = 0, Format = .B8G8R8A8_UNORM_SRGB,
		Stereo=false, SampleDesc= {Count = 1, Quality = 0 },
		BufferUsage= { .RENDER_TARGET_OUTPUT }, BufferCount = 2,
		Scaling = .STRETCH, SwapEffect = .DISCARD, AlphaMode =.UNSPECIFIED,
		Flags = 0,
	}

	hwnd := DXGI.HWND(window_sys_info.info.win.window)
	swapchain: ^DXGI.ISwapChain1
	dxgi_factory->CreateSwapChainForHwnd(device,hwnd,
		&swapchain_desc,nil,nil,&swapchain)

	framebuffer : ^D3D11.ITexture2D
	swapchain->GetBuffer(0, D3D11.ITexture2D_UUID,(^rawptr)(&framebuffer))
	framebuffer_view : ^D3D11.IRenderTargetView
	device->CreateRenderTargetView(framebuffer,nil,&framebuffer_view)

	depthbuffer_desc: D3D11.TEXTURE2D_DESC
	framebuffer->GetDesc(&depthbuffer_desc)
	depthbuffer_desc.Format = .D24_UNORM_S8_UINT
	depthbuffer_desc.BindFlags = { .DEPTH_STENCIL }
	depthbuffer : ^D3D11.ITexture2D
	device->CreateTexture2D(&depthbuffer_desc,nil,&depthbuffer)
	depthbuffer_view : ^D3D11.IDepthStencilView
	device->CreateDepthStencilView(depthbuffer,nil,&depthbuffer_view)


	/////////// SHADER //////////

	shader_path := "../shaders.hlsl"
	shaders_hlsl,ok := os.read_entire_file_from_filename(shader_path,context.allocator)
	vs_blob : ^D3D11.IBlob
	D3D.Compile(raw_data(shaders_hlsl),len(shaders_hlsl), 
		"shaders.hlsl",nil,nil, "vs_main" ,"vs_5_0",0,0,&vs_blob,nil)
	assert(vs_blob != nil)
	vertex_shader : ^D3D11.IVertexShader
	device->CreateVertexShader(
		vs_blob->GetBufferPointer(),
		vs_blob->GetBufferSize(),
		nil,&vertex_shader)

	input_element_desc := [?]D3D11.INPUT_ELEMENT_DESC {
		{"POS", 0, .R32G32B32_FLOAT,0,0, .VERTEX_DATA,0},
	}
	input_layout : ^D3D11.IInputLayout
	device->CreateInputLayout(
		&input_element_desc[0],
		len(input_element_desc),
		vs_blob->GetBufferPointer(),
		vs_blob->GetBufferSize(),
		&input_layout)

	ps_blob: ^D3D11.IBlob
	D3D.Compile(raw_data(shaders_hlsl),len(shaders_hlsl),"shaders.hlsl",
		nil,nil,"ps_main","ps_5_0",0,0,&ps_blob,nil)

	pixel_shader : ^D3D11.IPixelShader
	device->CreatePixelShader(
		ps_blob->GetBufferPointer(),
		ps_blob->GetBufferSize(),
		nil,
		&pixel_shader)


	/////////// SHOW WINDOW //////////
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

		/////////// Render //////////
		device_context->ClearRenderTargetView(framebuffer_view,&[4]f32{0.0,0.0,0.0,1.0})
		device_context->ClearDepthStencilView(depthbuffer_view,{.DEPTH},1,0)

		//INPUT ASSEMBLER STAGE
		device_context->IASetPrimitiveTopology(.TRIANGLELIST)
		device_context->IASetInputLayout(input_layout)
		//vertex buffer
		//index buffer

		//VERTEX STAGE
		device_context->VSSetShader(vertex_shader,nil,0)

		//PIXEL STAGE
		device_context->PSSetShader(pixel_shader,nil,0)

		//OUTER MERGER STAGE
		device_context->OMSetRenderTargets(1,&framebuffer_view,depthbuffer_view)

		swapchain->Present(1,0)
		
	}	
}