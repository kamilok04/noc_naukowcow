struc EFI_GRAPHICS_OUTPUT_PROTOCOL
    .QueryMode  resq 1   ; +0  
    .SetMode    resq 1   ; +8  
    .Blt        resq 1   ; +16 
    .Mode       resq 1   ; +24
endstruc

struc EFI_GRAPHICS_OUTPUT_MODE_INFORMATION
    .Version                resd 1 ; +0
    .HorizontalResolution   resd 1 ; +4
    .VerticalResolution     resd 1 ; +8
    .PixelFormat            resd 1 ; +12
    .PixelInformation       resd 4 ; +16 (4 x UINT32)
    .PixelsPerScanLine      resd 1 ; +32
endstruc