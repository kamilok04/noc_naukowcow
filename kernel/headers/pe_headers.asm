[bits 64]
[org 0] 
; RVA calculations start from 0

; ==============================================================================
; DOS HEADER & PE SIGNATURE
; ==============================================================================
DOS_HEADER:
    dw 0x5a4d
    times 58 db 0
    dd pe_header - DOS_HEADER

pe_header:
    db "PE", 0, 0
    dw 0x8664
    dw 2           ; 2 sections (.text, .data)
    dd 0           ; timestamp
    dd 0, 0        ; symbols
    dw opt_header_size
    dw 0x022E      ; Executable | Large Address Aware | Stripped

; ==============================================================================
; OPTIONAL HEADER
; ==============================================================================
opt_header:
    dw 0x020b      ; PE32+ (64-bit)
    dw 0
    dd text_size
    dd data_size
    dd 0
    dd text_rva    ; Entry point
    dd text_rva    ; Base of code
    dq 0x400000    ; ImageBase
    
    ; 1:1 Memory to Disk Mapping
    dd 0x1000      ; SectionAlignment
    dd 0x1000      ; FileAlignment
    
    dw 0, 0, 0, 0, 2, 0
    dd 0
    dd image_size
    dd header_size
    dd 0
    dw 10          ; 10 = EFI_APPLICATION
    dw 0
    dq 0x10000, 0x10000, 0x10000, 0
    dd 0, 16
    times 16 dq 0  ; Data Directories
opt_header_size equ $ - opt_header

; ==============================================================================
; SECTION TABLE
; As intended by Microsoft
; https://learn.microsoft.com/en-us/windows/win32/debug/pe-format#section-table-section-headers
; ==============================================================================
section_table:
    ; --- .text Section ---
    dq ".text"           ; Name (8 bytes)
    dd text_vsize        ; VirtualSize (4 bytes)
    dd text_rva          ; VirtualAddress (4 bytes)
    dd text_raw_size     ; SizeOfRawData (4 bytes)
    dd text_raw_ptr      ; PointerToRawData (4 bytes)
    dd 0                 ; PointerToRelocations (4 bytes)
    dd 0                 ; PointerToLinenumbers (4 bytes)
    dw 0                 ; NumberOfRelocations (2 bytes)
    dw 0                 ; NumberOfLinenumbers (2 bytes)
    dd 0x60000020        ; Characteristics: r-x | code (4 bytes)
    
    ; --- .data Section ---
    db ".data",0,0,0     ; Name padded to 8 bytes
    dd data_vsize        
    dd data_rva          
    dd data_raw_size     
    dd data_raw_ptr      
    dd 0                 
    dd 0                 
    dw 0                 
    dw 0                 
    dd 0xC0000040        ; Characteristics: rw- | initialized data

; Pad the entire header block to exactly 4096 bytes
align 4096, db 0
header_size equ $ - DOS_HEADER