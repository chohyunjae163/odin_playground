# D3D11 Playground

## the overall process for drawing to the screen
1. get a CoreWindow for the app.
2. get an interface for Direct3D device and context
3. create the swap chain to display rendered image in the CoreWindow
4. create a render target for drawing and populte it with pixels
5. Present the swap chain

## Swap Chain
A swap chain is a collection of buffers that are used for displaying frames to the user.
Each time an application presents a new frame for display, the first buffer in the swap chain takes the place of the displayed buffer.
This process is called swapping or flipping.

## DirectX Graphics Infrastructure(DXGI)
DXGI is **a set of APIs** used to configure and manage
low-level graphics and graphics adapter resources

## BACK BUFFER
a location in GPU memory where you can draw the pixels
and then have it swapped and sent to the screen
on a refresh signal

## Depth Stencil Buffer
a particular form of texture resource, which is typically used to determine 
which pixels have draw priority during rasterization based on the distance of
the objects in the scene from the camera. 

## D3DDevice
provides a virtual representation of the GPU and its resources
configure and obtain the GPU resources to start processing the graphics in a scene

## D3DDeviceContext
represents the graphics processing for the pipeline
process resources at each appropriate shader stage in the graphics pipeline

## Input Assembler Stage
the first stage in the pipeline. the purpose of the input-assembler stage is
to read primitive data from user-filled buffers and assemble the data into
primitives that will be used by the other pipeline stages

## Outer-Merger Stage
generates the final rendered pixel color using a combination of pipeline state,
the pixel data generated by the pixel shaders, the contents of the render targets,
and the contents of the depth/stencil buffers.

## view matrix
zaxis = normal(At - Eye) // forward 
xaxis = normal(cross(Up, zaxis)) // right
yaxis = cross(zaxis, xaxis) // up

 xaxis.x           yaxis.x           zaxis.x          0
 xaxis.y           yaxis.y           zaxis.y          0
 xaxis.z           yaxis.z           zaxis.z          0
-dot(xaxis, eye)  -dot(yaxis, eye)  -dot(zaxis, eye)  1


## projection matrix
w = 1/tan(fov * 0.5)
h = 1/tan(fov * 0.5)
Q = far_plane / (far_plane - nearPlane)
w       0       0              0
0       h       0              0
0       0       Q              1
0       0   -Q*near_plane      0

## textures
a texture resource is a structured collection of data designed
to store texels.a texel represents the smallest unit of a texture
samplers that as they are read by shader units.

## dynamic resources
related APIs
ID3D11DeviceContext::Map
ID3D11DeviceContext::Unmap
D3D11_Usage
*** To change data in a dynamic resource ***
1. declare a d3d11_mapped_subresource type variable
2. disable gpu access to the data that you want to
change and get a pointer to the memory containing the data
3. write the new data
4. call Unmap to reenable GPU access to the data
