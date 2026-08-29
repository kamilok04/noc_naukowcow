; Various structures defined within the UEFI standard


struc EFI_BLOCK_IO_MEDIA
    .MediaId          resd 1  ; Offset 0: The current ID of the media
    .RemovableMedia   resb 1  ; Offset 4
    .MediaPresent     resb 1  ; Offset 5
    .LogicalPartition resb 1  ; Offset 6
    .ReadOnly         resb 1  ; Offset 7
    .WriteCaching     resb 1  ; Offset 8
    .Pad1             resb 3  ; Offset 9: Padding for 4-byte alignment
    .BlockSize        resd 1  ; Offset 12: Sector size (usually 2048 for CD)
    .IoAlign          resd 1  ; Offset 16: Required memory alignment for buffers
    .Pad2             resb 4  ; Offset 20: Padding for 8-byte alignment
    .LastBlock        resq 1  ; Offset 24: Max LBA
    ; Further fields (Revision 2+) omitted for brevity
endstruc

struc EFI_BLOCK_IO_PROTOCOL
    .Revision    resq 1  ; Offset 0
    .Media       resq 1  ; Offset 8: Pointer to EFI_BLOCK_IO_MEDIA
    .Reset       resq 1  ; Offset 16
    .ReadBlocks  resq 1  ; Offset 24: EFI_STATUS (*)(This, MediaId, LBA, BufferSize, Buffer)
    .WriteBlocks resq 1  ; Offset 32
    .FlushBlocks resq 1  ; Offset 40
endstruc

; UEFI standard @ 4.4.1
struc EFI_BOOT_SERVICES
    .Hdr                                 resb 24 ; Offset 0: EFI_TABLE_HEADER
    
    ; Task Priority Services
    .RaiseTPL                            resq 1  ; Offset 24
    .RestoreTPL                          resq 1  ; Offset 32
    
    ; Memory Services
    .AllocatePages                       resq 1  ; Offset 40
    .FreePages                           resq 1  ; Offset 48
    .GetMemoryMap                        resq 1  ; Offset 56
    .AllocatePool                        resq 1  ; Offset 64
    .FreePool                            resq 1  ; Offset 72
    
    ; Event & Timer Services
    .CreateEvent                         resq 1  ; Offset 80
    .SetTimer                            resq 1  ; Offset 88
    .WaitForEvent                        resq 1  ; Offset 96
    .SignalEvent                         resq 1  ; Offset 104
    .CloseEvent                          resq 1  ; Offset 112
    .CheckEvent                          resq 1  ; Offset 120
    
    ; Protocol Handler Services
    .InstallProtocolInterface            resq 1  ; Offset 128
    .ReinstallProtocolInterface          resq 1  ; Offset 136
    .UninstallProtocolInterface          resq 1  ; Offset 144
    .HandleProtocol                      resq 1  ; Offset 152
    .Reserved                            resq 1  ; Offset 160
    .RegisterProtocolNotify              resq 1  ; Offset 168
    .LocateHandle                        resq 1  ; Offset 176
    .LocateDevicePath                    resq 1  ; Offset 184
    .InstallConfigurationTable           resq 1  ; Offset 192
    
    ; Image Services
    .LoadImage                           resq 1  ; Offset 200
    .StartImage                          resq 1  ; Offset 208
    .Exit                                resq 1  ; Offset 216
    .UnloadImage                         resq 1  ; Offset 224
    .ExitBootServices                    resq 1  ; Offset 232
    
    ; Miscellaneous Services
    .GetNextMonotonicCount               resq 1  ; Offset 240
    .Stall                               resq 1  ; Offset 248
    .SetWatchdogTimer                    resq 1  ; Offset 256
    
    ; DriverSupport Services
    .ConnectController                   resq 1  ; Offset 264
    .DisconnectController                resq 1  ; Offset 272
    
    ; Open and Close Protocol Services
    .OpenProtocol                        resq 1  ; Offset 280
    .CloseProtocol                       resq 1  ; Offset 288
    .OpenProtocolInformation             resq 1  ; Offset 296
    
    ; Library Services
    .ProtocolsPerHandle                  resq 1  ; Offset 304
    .LocateHandleBuffer                  resq 1  ; Offset 312
    .LocateProtocol                      resq 1  ; Offset 320 (0x140)
    .InstallMultipleProtocolInterfaces   resq 1  ; Offset 328
    .UninstallMultipleProtocolInterfaces resq 1  ; Offset 336
    
    ; 32-bit CRC Services
    .CalculateCrc32                      resq 1  ; Offset 344
    
    ; Miscellaneous Services
    .CopyMem                             resq 1  ; Offset 352
    .SetMem                              resq 1  ; Offset 360
    .CreateEventEx                       resq 1  ; Offset 368
endstruc