; Various structures defined within the UEFI standard


struc EFI_BLOCK_IO_MEDIA
    .MediaId          resd 1  ; +0: The current ID of the media
    .RemovableMedia   resb 1  ; +4
    .MediaPresent     resb 1  ; +5
    .LogicalPartition resb 1  ; +6
    .ReadOnly         resb 1  ; +7
    .WriteCaching     resb 1  ; +8
    .Pad1             resb 3  ; +9: Padding for 4-byte alignment
    .BlockSize        resd 1  ; +12: Sector size (usually 2048 for CD)
    .IoAlign          resd 1  ; +16: Required memory alignment for buffers
    .Pad2             resb 4  ; +20: Padding for 8-byte alignment
    .LastBlock        resq 1  ; +24: Max LBA
    ; Further fields (Revision 2+) omitted for brevity
endstruc

struc EFI_BLOCK_IO_PROTOCOL
    .Revision    resq 1  ; +0
    .Media       resq 1  ; +8: Pointer to EFI_BLOCK_IO_MEDIA
    .Reset       resq 1  ; +16
    .ReadBlocks  resq 1  ; +24: EFI_STATUS (*)(This, MediaId, LBA, BufferSize, Buffer)
    .WriteBlocks resq 1  ; +32
    .FlushBlocks resq 1  ; +40
endstruc

; UEFI standard @ 4.4.1
struc EFI_BOOT_SERVICES
    .Hdr                                 resb 24 ; +0: EFI_TABLE_HEADER
    
    ; Task Priority Services
    .RaiseTPL                            resq 1  ; +24
    .RestoreTPL                          resq 1  ; +32
    
    ; Memory Services
    .AllocatePages                       resq 1  ; +40
    .FreePages                           resq 1  ; +48
    .GetMemoryMap                        resq 1  ; +56
    .AllocatePool                        resq 1  ; +64
    .FreePool                            resq 1  ; +72
    
    ; Event & Timer Services
    .CreateEvent                         resq 1  ; +80
    .SetTimer                            resq 1  ; +88
    .WaitForEvent                        resq 1  ; +96
    .SignalEvent                         resq 1  ; +104
    .CloseEvent                          resq 1  ; +112
    .CheckEvent                          resq 1  ; +120
    
    ; Protocol Handler Services
    .InstallProtocolInterface            resq 1  ; +128
    .ReinstallProtocolInterface          resq 1  ; +136
    .UninstallProtocolInterface          resq 1  ; +144
    .HandleProtocol                      resq 1  ; +152
    .Reserved                            resq 1  ; +160
    .RegisterProtocolNotify              resq 1  ; +168
    .LocateHandle                        resq 1  ; +176
    .LocateDevicePath                    resq 1  ; +184
    .InstallConfigurationTable           resq 1  ; +192
    
    ; Image Services
    .LoadImage                           resq 1  ; +200
    .StartImage                          resq 1  ; +208
    .Exit                                resq 1  ; +216
    .UnloadImage                         resq 1  ; +224
    .ExitBootServices                    resq 1  ; +232
    
    ; Miscellaneous Services
    .GetNextMonotonicCount               resq 1  ; +240
    .Stall                               resq 1  ; +248
    .SetWatchdogTimer                    resq 1  ; +256
    
    ; DriverSupport Services
    .ConnectController                   resq 1  ; +264
    .DisconnectController                resq 1  ; +272
    
    ; Open and Close Protocol Services
    .OpenProtocol                        resq 1  ; +280
    .CloseProtocol                       resq 1  ; +288
    .OpenProtocolInformation             resq 1  ; +296
    
    ; Library Services
    .ProtocolsPerHandle                  resq 1  ; +304
    .LocateHandleBuffer                  resq 1  ; +312
    .LocateProtocol                      resq 1  ; +320 (0x140)
    .InstallMultipleProtocolInterfaces   resq 1  ; +328
    .UninstallMultipleProtocolInterfaces resq 1  ; +336
    
    ; 32-bit CRC Services
    .CalculateCrc32                      resq 1  ; +344
    
    ; Miscellaneous Services
    .CopyMem                             resq 1  ; +352
    .SetMem                              resq 1  ; +360
    .CreateEventEx                       resq 1  ; +368
endstruc

struc EFI_SIMPLE_POINTER_PROTOCOL
    .Reset        resq 1 ; +0
    .GetState     resq 1 ; +8
    .WaitForInput resq 1 ; +16
    .Mode         resq 1 ; +24
endstruc

struc EFI_SIMPLE_POINTER_STATE
    .RelativeMovementX resd 1 ; +0  (INT32)
    .RelativeMovementY resd 1 ; +4  (INT32)
    .RelativeMovementZ resd 1 ; +8  (INT32)
    .LeftButton        resb 1 ; +12 (BOOLEAN)
    .RightButton       resb 1 ; +13 (BOOLEAN)
    ; 14 bytes, but pad for alignment
    ._Padding           resb 2
endstruc

struc EFI_ABSOLUTE_POINTER_PROTOCOL
    .Reset        resq 1 ; +0x00
    .GetState     resq 1 ; +0x08
    .WaitForInput resq 1 ; +0x10
    .Mode         resq 1 ; +0x18
endstruc

struc EFI_ABSOLUTE_POINTER_STATE
    .AbsoluteMinX resq 1 ; +0x00
    .AbsoluteMinY resq 1 ; +0x08
    .AbsoluteMinZ resq 1 ; +0x10
    .AbsoluteMaxX resq 1 ; +0x18
    .AbsoluteMaxY resq 1 ; +0x20
    .AbsoluteMaxZ resq 1 ; +0x28
    .Attributes   resd 1 ; +0x30
endstruc

struc EFI_TCP4_CONFIG_DATA
    .TypeOfService     resb 1
    .TimeToLive        resb 1
    .UseDefaultAddress resb 1
    .StationAddress    resb 4     ; IPv4 array
    .SubnetMask        resb 4     ; IPv4 array
    ._Padding          resb 1
    .StationPort       resw 1     
    .RemoteAddress     resb 4     ; IPv4 array
    .RemotePort        resw 1
    .ActiveFlag        resb 1     ; 0 = listen, 1 = connect
    
    alignb 8                      ; 64-bit alignment
    .ControlOption     resq 1     ; Pointer to EFI_TCP4_OPTION
endstruc

struc EFI_TCP4_COMPLETION_TOKEN
    .Event       resq 1      ; EFI_EVENT 
    .Status      resq 1      ; EFI_STATUS (SUCCESS, NOT_READY, ...)
endstruc

struc EFI_TCP4_LISTEN_TOKEN
    .CompletionToken resb 16 ;
    .NewChildHandle  resq 1  ; incoming client's handle here
endstruc

struc EFI_SIMPLE_FILE_SYSTEM_PROTOCOL
    .Revision       resq 1 ; +0x00
    .OpenVolume     resq 1 ; +0x08
endstruc

struc EFI_FILE_PROTOCOL
    .Revision       resq 1 ; +0x00
    .Open           resq 1 ; +0x08
    .Close          resq 1 ; +0x10
    .Delete         resq 1 ; +0x18
    .Read           resq 1 ; +0x20
    .Write          resq 1 ; +0x28
    .GetPosition    resq 1 ; +0x30
    .SetPosition    resq 1 ; +0x38
    .GetInfo        resq 1 ; +0x40
    .SetInfo        resq 1 ; +0x48
    .Flush          resq 1 ; +0x50
endstruc

struc EFI_LOADED_IMAGE_PROTOCOL
    .Revision        resd 1 ; +0x00 (UINT32)
    .Pad1            resd 1 ; +0x04 (64-bit alignment padding)
    .ParentHandle    resq 1 ; +0x08 (EFI_HANDLE)
    .SystemTable     resq 1 ; +0x10 (EFI_SYSTEM_TABLE *)
    .DeviceHandle    resq 1 ; +0x18 (EFI_HANDLE)
    .FilePath        resq 1 ; +0x20 (EFI_DEVICE_PATH_PROTOCOL *)
    .Reserved        resq 1 ; +0x28 (VOID *)
    .LoadOptionsSize resd 1 ; +0x30 (UINT32)
    .Pad2            resd 1 ; +0x34 (64-bit alignment padding)
    .LoadOptions     resq 1 ; +0x38 (VOID *)
    .ImageBase       resq 1 ; +0x40 (VOID *)
    .ImageSize       resq 1 ; +0x48 (UINT64)
    .ImageCodeType   resd 1 ; +0x50 (EFI_MEMORY_TYPE)
    .ImageDataType   resd 1 ; +0x54 (EFI_MEMORY_TYPE)
    .Unload          resq 1 ; +0x58 (EFI_IMAGE_UNLOAD)
endstruc