; ==============================================================================
; iso9660.inc - Primary Volume Descriptor & Directory Records
; ==============================================================================

%ifndef ISO9660_INC
%define ISO9660_INC

; ==============================================================================
; ISO 9660 Directory Record
; Used for both the Root Directory and all files/folders on the disk.
; ==============================================================================
struc ISO9660_DIR_RECORD
    .RecordLength        resb 1  ; +0: 0 = end of directory
    .ExtAttrLength       resb 1  ; +1
    .ExtentLocationLE    resd 1  ; +2
    .ExtentLocationBE    resd 1  ; +6
    .DataLengthLE        resd 1  ; +10
    .DataLengthBE        resd 1  ; +14
    .RecordingDate       resb 7  ; +18: Year, Month, Day, Hour, Minute, Second, GMT offset
    .FileFlags           resb 1  ; +25: 0x02 set = directory
    .FileUnitSize        resb 1  ; +26
    .InterleaveGap       resb 1  ; +27
    .VolumeSeqNumLE      resw 1  ; +28
    .VolumeSeqNumBE      resw 1  ; +30
    .FileNameLength      resb 1  ; +32:
    .FileName            resb 1  ; +33: start of string (variable length)
endstruc

; ==============================================================================
; ISO 9660 Primary Volume Descriptor (PVD)
; Always located at Logical Block Address (LBA) 16 on the disk.
; ==============================================================================
struc ISO9660_PVD
    .Type                resb 1  ; +0: Must be 1 for PVD
    .StandardId          resb 5  ; +1: Magic string "CD001"
    .Version             resb 1  ; +6: Must be 1
    .Unused1             resb 1  ; +7
    .SystemId            resb 32 ; +8
    .VolumeId            resb 32 ; +40
    .Unused2             resb 8  ; +72
    .VolumeSpaceSizeLE   resd 1  ; +80
    .VolumeSpaceSizeBE   resd 1  ; +84
    .Unused3             resb 32 ; +88
    .VolumeSetSizeLE     resw 1  ; +120
    .VolumeSetSizeBE     resw 1  ; +122
    .VolumeSeqNumLE      resw 1  ; +124
    .VolumeSeqNumBE      resw 1  ; +126
    .LogicalBlockSizeLE  resw 1  ; +128: Sector size, standard is 2048
    .LogicalBlockSizeBE  resw 1  ; +130
    .PathTableSizeLE     resd 1  ; +132
    .PathTableSizeBE     resd 1  ; +136
    .Type1PathTableLE    resd 1  ; +140
    .OptType1PathTableLE resd 1  ; +144
    .TypeMPathTableBE    resd 1  ; +148
    .OptTypeMPathTableBE resd 1  ; +152
    .RootDirectoryRecord resb 34 ; +156: ISO9660_DIR_RECORD (34 bytes)
    ; ~1800 bytes left
endstruc

%endif ; ISO9660_INC