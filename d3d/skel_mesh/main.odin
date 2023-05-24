package main


import "core:fmt"
import "core:os"
import "core:math/linalg"

import SDL "vendor:sdl2"
import D3D11 "vendor:directx/d3d11"
import DXGI "vendor:directx/dxgi"
import D3D "vendor:directx/d3d_compiler"




main :: proc() {
	vertex_data,index_data := read_skel_mesh_from_file("./bin/YBot.dc")
	if(vertex_data == nil || index_data == nil) {
		fmt.eprintln("buffers are nil...")
		return
	}

	defer delete(vertex_data)
	defer delete(index_data)
	
/////////// SETUP WINDOW //////////
	
	SDL.Init( { .VIDEO } )
	defer SDL.Quit()

	SDL.SetHintWithPriority(SDL.HINT_RENDER_DRIVER,"direct3d11", .OVERRIDE)
	window := SDL.CreateWindow("D3D11 in Odin",
		SDL.WINDOWPOS_CENTERED,SDL.WINDOWPOS_CENTERED,
		800,800,
		{.ALLOW_HIGHDPI, .HIDDEN, .RESIZABLE},
	)
	defer SDL.DestroyWindow(window)

	window_sys_info : SDL.SysWMinfo
	SDL.GetVersion(&window_sys_info.version)
	SDL.GetWindowWMInfo(window,&window_sys_info)
	assert(window_sys_info.subsystem == .WINDOWS)

	/////////////////////// D3D11 SETUP ///////////////////////

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

	//frame buffer
	framebuffer : ^D3D11.ITexture2D
	swapchain->GetBuffer(0, D3D11.ITexture2D_UUID,(^rawptr)(&framebuffer))
	framebuffer_view : ^D3D11.IRenderTargetView
	device->CreateRenderTargetView(framebuffer,nil,&framebuffer_view)

	//depth buffer
	depthbuffer_desc: D3D11.TEXTURE2D_DESC
	framebuffer->GetDesc(&depthbuffer_desc)
	depthbuffer_desc.Format = .D24_UNORM_S8_UINT
	depthbuffer_desc.BindFlags = { .DEPTH_STENCIL }
	
	depthbuffer : ^D3D11.ITexture2D
	device->CreateTexture2D(&depthbuffer_desc,nil,&depthbuffer)
	depthbuffer_view : ^D3D11.IDepthStencilView
	device->CreateDepthStencilView(depthbuffer,nil,&depthbuffer_view)

	//viewport setting
	viewport := D3D11.VIEWPORT {
		0,0,
		f32(depthbuffer_desc.Width),
		f32(depthbuffer_desc.Height),
		0,1,
	}

	//constant data
	Constants :: struct {
		mvp : matrix[4,4]f32,
	}

	world_matrix : matrix[4,4]f32 = {
    	1,0,0,0,
    	0,1,0,0,
    	0,0,1,0,
    	0,0,0,1,		
	}

	cam_f :: linalg.Vector3f32 {0,0,1}
	cam_u :: linalg.Vector3f32 {0,1,0}
	cam_r :: linalg.Vector3f32 {1,0,0}
	cam_p :: linalg.Vector3f32 {0,0,-3.5}
	x := -linalg.dot(cam_r,cam_p)
	y := -linalg.dot(cam_u,cam_p)
	z := -linalg.dot(cam_f,cam_p)

	view_matrix : matrix[4,4]f32 = {
		cam_r.x,cam_r.y,cam_r.z,x,
		cam_u.x,cam_u.y,cam_u.z,y,
		cam_f.x,cam_f.y,cam_f.z,z,
		0,0,0,1,
	}
	f := f32(9)
	n := f32(1)
	x_scale := f32(1.4281)
	y_scale := f32(1.4281)
	projection_matrix : matrix[4,4]f32 = {
		x_scale,0,0,0,
		0,y_scale,0,0,
		0,0,f/(f-n),n*f/(n-f),
		0,0,1,0,
	}

	wvp := linalg.mul(projection_matrix,linalg.mul(view_matrix,world_matrix))

	//constant buffer
	constant_buffer : ^D3D11.IBuffer
	{
		constant_buffer_desc := D3D11.BUFFER_DESC {
			ByteWidth = size_of(Constants),
			Usage = .DYNAMIC,
			BindFlags = {.CONSTANT_BUFFER},
			CPUAccessFlags = {.WRITE},
		}
		
		device->CreateBuffer(&constant_buffer_desc,nil,&constant_buffer)		
	}

	//vertex buffer
// 	  vertex_data := [?]f32 {
// 	-0.5,0.5,-0.5, 0.0,1.0,0.0,
// 	0.5,0.5,-0.5,  0.0,1.0,0.0,
// 	0.5,0.5,0.5,   0.0,1.0,1.0,
// 	-0.5,0.5,0.5,  0.0,1.0,0.0,

// 	-0.5,-0.5,0.5, 0.0,0.0,1.0,
// 	0.5, -0.5,0.5, 0.0,1.0,0.0,
// 	0.5, -0.5,-0.5,0.0,1.0,0.0,
// 	-0.5,-0.5,-0.5,0.0,1.0,1.0,
  // }
	vertex_buffer : ^D3D11.IBuffer
	vertex_buffer_stride := (u32)(size_of(skinned_mesh_vertex))
	vertex_buffer_offset := (u32)(0)
	{
		vertex_buffer_desc := D3D11.BUFFER_DESC {
			ByteWidth = size_of(vertex_data),
			Usage = .IMMUTABLE,
			BindFlags = {.VERTEX_BUFFER},
		}
	
		device->CreateBuffer(&vertex_buffer_desc,
			&D3D11.SUBRESOURCE_DATA { 
				pSysMem = &vertex_data[0],
				SysMemPitch = size_of(vertex_data)},
			&vertex_buffer)
	}



	//index buffer
// 	  index_data := [?]u32{
// 	0,1,2,
// 	0,2,3,

// 	4,5,6,
// 	4,6,7,

// 	3,2,5,
// 	3,5,4,

// 	2,1,6,
// 	2,6,5,

// 	1,7,6,
// 	1,0,7,

// 	0,3,4,
// 	0,4,7,
  // }
	index_buffer : ^D3D11.IBuffer
	{
		index_buffer_desc := D3D11.BUFFER_DESC {
			ByteWidth = size_of(index_data),
			Usage = .IMMUTABLE,
			BindFlags = {.INDEX_BUFFER},
		}
	
		device->CreateBuffer(&index_buffer_desc,
			&D3D11.SUBRESOURCE_DATA {
				pSysMem = &index_data[0],
				SysMemPitch = size_of(index_data)},
			&index_buffer)
	}


	/////////////////////// SHADER ///////////////////////

	shader_path := "shaders.hlsl"
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
		{"POS", 	0, .R32G32B32_FLOAT,	0,	0,	.VERTEX_DATA,0},
		{"NORM", 	0, .R32G32B32_FLOAT,	0,	D3D11.APPEND_ALIGNED_ELEMENT, .VERTEX_DATA,0},
		{"UV", 		0, .R32G32_FLOAT,		0,	D3D11.APPEND_ALIGNED_ELEMENT, .VERTEX_DATA,0},
		{"BONES", 	0, .R32G32B32A32_UINT,	0,	D3D11.APPEND_ALIGNED_ELEMENT, .VERTEX_DATA,0},
		{"WEIGHT", 	0, .R32G32B32A32_FLOAT,	0,	D3D11.APPEND_ALIGNED_ELEMENT, .VERTEX_DATA,0},
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


	/////////////////////// SHOW WINDOW ///////////////////////
	
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
		device_context->Map(constant_buffer,0, .WRITE_DISCARD,{},&mapped_subresource)
		{
			constants := (^Constants)(mapped_subresource.pData)
			constants.mvp = wvp
		}
		device_context->Unmap(constant_buffer,0)


		/////////////////////// Render ///////////////////////
		{
			device_context->ClearRenderTargetView(framebuffer_view,&[4]f32{0.0,0.0,0.0,1.0})
			device_context->ClearDepthStencilView(depthbuffer_view,{.DEPTH},1,0)

			//INPUT ASSEMBLER STAGE
			device_context->IASetPrimitiveTopology(.TRIANGLELIST)
			device_context->IASetInputLayout(input_layout)
			device_context->IASetVertexBuffers(0,1,
			&vertex_buffer,&vertex_buffer_stride,&vertex_buffer_offset)
			device_context->IASetIndexBuffer(index_buffer,.R32_UINT,0)
	
			//VERTEX STAGE
			device_context->VSSetShader(vertex_shader,nil,0)
			device_context->VSSetConstantBuffers(0,1,&constant_buffer)
			
			//PIXEL STAGE
			device_context->PSSetShader(pixel_shader,nil,0)

			//RASETERIZE STAGE
			device_context->RSSetViewports(1,&viewport)

			//OUTER MERGER STAGE
			device_context->OMSetRenderTargets(1,&framebuffer_view,depthbuffer_view)
			index_len := len(index_data)
			device_context->DrawIndexed((u32)(index_len),0,0)

			swapchain->Present(1,0)
		}

	}	
}
