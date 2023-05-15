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
DXGI is ** a set of APIs ** used to configure and manage
low-level graphics and graphics adapter resources

## BACK BUFFER
a location in GPU memory where you can draw the pixels
and then have it swapped and sent to the screen
on a refresh signal
