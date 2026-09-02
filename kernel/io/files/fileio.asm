%ifndef FILEIO
%define FILEIO
%endif
%include "iso_parser.asm"
%include "iso_reader.asm"
%include "malloc.asm"

; ------------------------------------------------------------------------------
; fopen
; Inputs: RCX - Pointer to target filename (e.g., "LOGO.BMP;1")
; Outputs: RAX - Pointer to allocated FILE struct (or 0 on error)
; ------------------------------------------------------------------------------
fopen:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    push r15
    mov r12, rcx                     
    mov r13, [rel root_dir_lba]      
    mov r14, [rel root_dir_size]     

.get_segment:
    ; następny kawałek ścieżki dopóki nie wjedziesz w '/' albo 0
    lea rdi, [rel path_token]
    xor rbx, rbx                     ; RBX = długość kawałka
.extract_char:
    mov al, byte [r12]
    cmp al, 0
    je .token_done
    cmp al, '/'
    je .token_done
    mov byte [rdi + rbx], al
    inc r12
    inc rbx
    
    jmp .extract_char
.token_done:
    
    mov byte [rdi + rbx], 0          ; Pobierz terminatora
    mov r15b, al                     ; R15B = co zostało zapisane?
    
    cmp r15b, '/'
    jne .do_search
    inc r12                          ; Przewiń przez '/'

.do_search:
    ; Zaokrąglij rozmiar do 2KB
    mov rdx, r14
    add rdx, 2047
    and rdx, ~0x7ff

    ; Zrób jakiś bufor na wpis katalogowy
    mov rcx, 2                       ; EfiLoaderData
    lea r8, [rel file_buffer]        ; tmp
    mov rbx, [rel boot_services_ptr]
    sub rsp, 32
    call [rbx + EFI_BOOT_SERVICES.AllocatePool]
    add rsp, 32
    
    ; wczytaj wpis
    mov r8, r13                      ; LBA
    mov r9, r14                      ; Rozmiar
    add r9, 2047
    and r9, ~0x7ff
    mov r10, [rel file_buffer]
    call read_sectors

    test rax, rax
    jnz .read_failure
    
    ; Poszukaj tu wpisu o żądanej nazwie
    mov rdi, [rel file_buffer]
    mov rcx, r14                     
    lea rsi, [rel path_token]
    ; LOG "Directory size is %x @ %x", rcx, rdi
    ; LOG "Looking for token %s", rsi
    call search_directory
    
    mov r13, rax                     ; nowe LBA
    mov r14, rdx                     ; nowy rozmiar
    
    ; wpis już niepotrzebny, usuń
    mov rcx, [rel file_buffer]
    mov rbx, [rel boot_services_ptr]
    sub rsp, 32
    call [rbx + EFI_BOOT_SERVICES.FreePool]
    add rsp, 32
    
    ; Udało się?
    test r13, r13
    jz .not_found                        ; jak 0, to nie
    
    ; '/', czyli jest jakiś folder pod spodem
    cmp r15b, 0
    jne .get_segment
    
    ; jest plik, utwórz strukturę FILE i ją oddaj
    mov rcx, 2
    mov rdx, 16
    lea r8, [rel file_buffer]        ; recykling :)
    
    
    mov rbx, [rel boot_services_ptr]
    sub rsp, 32 ; shadow spacing                                 
    call [rbx + EFI_BOOT_SERVICES.AllocatePool]
    add rsp, 32                                 

    ; populate the FILE struct
    mov r12, [rel file_buffer]       ; R12 == wskaźnik do FILE
    mov [r12 + FILE.FileSize], r14   ; rozmiar 

    mov rax, r14
    call malloc
    test rax, rax
    jz .allocation_failed
    mov [rel temp_buffer_ptr], rax

    ; read the file into memory
    mov [r12 + FILE.BufferPtr], rax  ; saving the struct could be useful tho
    mov qword [r12 + FILE.Cursor], 0

    mov r8, r13
    mov r9, r14                   ; R9 = rozmiar pliku
    add r9, 2047                  ; round up to the nearest
    and r9, ~0x7ff                 ; 2KB boundary
    mov r10, [rel temp_buffer_ptr]
    call read_sectors
    test rax, rax                 ; Check if EFI_SUCCESS
    jnz .not_found

    mov rax, r12
    jmp .done

.allocation_failed:
    LOG "Unable to allocate."
    xor rax, rax
    jmp .done

.read_failure:
    LOG "A generic read error occured."
    xor rax, rax
    jmp .done

.not_found:
    xor rax, rax                  ; Return NULL
    jmp .done
.done:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    mov rsp, rbp
    pop rbp
    ret

temp_buffer_ptr dq 0
temp_struct_ptr dq 0

; ------------------------------------------------------------------------------
; fread
; Inputs:
;   RCX - Destination buffer pointer
;   RDX - Number of bytes to read
;   R8  - Pointer to FILE struct
; Outputs: RAX - Number of bytes actually read
; ------------------------------------------------------------------------------
fread:
    mov rax, [r8 + FILE.FileSize]
    sub rax, [r8 + FILE.Cursor]   ; RAX = remaining bytes in file
    
    cmp rdx, rax
    cmova rdx, rax                ; if requested > remaining, only read remaining
    test rdx, rdx
    jz .eof                       ; nothing to read

    ; Copy memory
    push rsi
    push rdi
    push rcx
    
    mov rsi, [r8 + FILE.BufferPtr]
    add rsi, [r8 + FILE.Cursor]   ; source = buffer + cursor
    mov rdi, rcx                  ; destination = user buffer
    mov rcx, rdx                  ; bytes to read
    rep movsb                     

    pop rcx
    pop rdi
    pop rsi

    ; Update Cursor
    add [r8 + FILE.Cursor], rdx
    mov rax, rdx                  ; bytes read
    ret

.eof:
    xor rax, rax                  ; NULL
    ret

; ------------------------------------------------------------------------------
; fclose
; Frees the file data buffer (FreePages) and the FILE struct memory (FreePool).
; Inputs:
;   RCX - Pointer to FILE struct
; ------------------------------------------------------------------------------
fclose:
    push rbp
    mov rbp, rsp
    
    push rbx
    push r12             
    
    sub rsp, 32          

    mov r12, rcx         
    mov rbx, [rel boot_services_ptr]

    ; free the buffer, this needs the page count again
    mov rax, [r12 + FILE.FileSize]
    add rax, 4095
    shr rax, 12                      ; RAX = page count

    ; Setup arguments for FreePages
    mov rdx, rax                     ; page count
    mov rcx, [r12 + FILE.BufferPtr]  ; starting address
    
    call [rbx + EFI_BOOT_SERVICES.FreePages]

    ; free the file struct
    mov rcx, r12                     
    
    call [rbx + EFI_BOOT_SERVICES.FreePool]

    add rsp, 32
    pop r12
    pop rbx
    pop rbp
    ret

struc FILE
    .BufferPtr resq 1
    .FileSize  resq 1  
    .Cursor    resq 1 ; where are we?
endstruc
FILE_STRUCT_SIZE equ 24