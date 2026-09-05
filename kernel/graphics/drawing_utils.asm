; ==============================================================================
; drawing_utils.inc
; ==============================================================================

; ------------------------------------------------------------------------------
; draw_rectangle
; Draws a filled rectangle to the linear framebuffer.
; Inputs:
;   RDI  - framebuffer ptr
;   RSI  - PixelsPerScanLine (Pitch)
;   RCX  - left padding
;   RDX  - top padding
;   R8   - width (in pixels)
;   R9   - height (in pixels)
;   R10D - 32bit color
; ------------------------------------------------------------------------------
draw_rectangle:
    push rdi
    push rax
    push rcx
    push rdx
    push r11

    ; offset = (Y * pitch + X) * 4 [bytes]
    mov rax, rdx       
    mul rsi            
    add rax, rcx       
    shl rax, 2         
    add rdi, rax       ; RDI = Absolute memory address of top-left pixel

    ; row stride
    mov r11, rsi
    shl r11, 2         ; R11 = Pitch * 4

.row_loop:
    test r9, r9        ; remaining height
    jz .done

    push rdi           ; start-of-row address
    mov rcx, r8        ; RCX = width 
    mov eax, r10d      ; EAX = color
    rep stosd          ; usually used for strings
    pop rdi            

    add rdi, r11       
    dec r9
    jmp .row_loop

.done:
    pop r11
    pop rdx
    pop rcx
    pop rax
    pop rdi
    ret

; ------------------------------------------------------------------------------
; draw_bitmap
; Draws a 32-bit uncompressed BMP image to the screen.
; Inputs:
;   RDI - Framebuffer Base Address
;   RSI - PixelsPerScanLine (Pitch)
;   RCX - Start X (Screen)
;   RDX - Start Y (Screen)
;   R8  - Pointer to the BMP file in memory
; ------------------------------------------------------------------------------
draw_bitmap:
    push rbp
    mov rbp, rsp
    push r12
    push r13
    push r14
    push r15

    ; 1. Parse the BMP Header
    ; Offset 0x12 (18) = width
    ; Offset 0x16 (22) = height 
    ; Offset 0x0A (10) = pixel data offset 
    movzx r12, dword [r8 + 0x12]      
    movzx r13, dword [r8 + 0x16]
    movzx rbx, dword [r8 + 0x0a]

    
    add r8, rbx  

    ; BMPs are stored bottom-to-top. 
    ; screen Y starts at (start Y + height - 1)
    mov r14, rdx
    add r14, r13
    dec r14           

    ; R15 = row width (in bytes)
    mov r15, r12
    shl r15, 2

.row_loop:
    test r13, r13  
    jz .done

    ; (x, y) to mem address = base + (Y * pitch + X) * 4
    mov rax, r14
    mul rsi                         
    add rax, rcx                    
    shl rax, 2                       
    add rax, rdi                     

    push rcx                         
    push rdi                       
    push rsi                         

    mov rdi, rax                     ; RDI = destination (sreen)
    mov rsi, r8                      ; RSI = source (pixels)
    mov rcx, r12                     ; RCX = pixel count
.pixel_loop:
    test rcx, rcx                    ; Check if the row is finished
    jz .pixel_loop_done

    mov eax, dword [rsi]             
    
    mov ebx, eax                     
    and ebx, 0x00FFFFFF              
    cmp ebx, COLOR_KEY          
    je .skip_pixel                   
    
    mov dword [rdi], eax             

.skip_pixel:
    add rsi, 4                       ; Advance source pointer to the next BMP pixel
    add rdi, 4                       ; Advance destination pointer to the next screen pixel
    dec rcx
    jmp .pixel_loop

.pixel_loop_done:

    pop rsi
    pop rdi
    pop rcx

    add r8, r15                      
    dec r14                          ; bottom-to-top, we're going up
    dec r13                         
    jmp .row_loop

.done:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbp
    ret

; Draw a 10x10 red square.
; Intended to show where the mouse pointer currently is
; but can be used anywhere
draw_cursor:
    push rbp
    mov rbp, rsp
    
    mov rdi, [rel backbuffer_ptr]
    mov rsi, [rel framebuffer_pitch]
    
    mov ecx, dword [rel mouse_x]   ; RCX = Start X
    mov edx, dword [rel mouse_y]   ; RDX = Start Y
    
    mov r8, 10                     ; Width
    mov r9, 10                     ; Height
    mov r10d, 0x00FF0000           ; 32-bit Color (ARGB format: Red)
    
    call draw_rectangle
    
    pop rbp
    ret


; ------------------------------------------------------------------------------
; save_cursor_background
; Copies a block from the backbuffer to cursor_bg_buffer
; Inputs: RCX = newX, RDX = newY
; ------------------------------------------------------------------------------
save_cursor_background:
    push rbp
    mov rbp, rsp

    ; Calculate backbuffer offset: (Y * Pitch + X) * 4
    mov rax, rdx
    mul qword [rel framebuffer_pitch]    
    add rax, rcx                         
    shl rax, 2                           
    mov rsi, [rel backbuffer_ptr]
    add rsi, rax                         ; source = backed buffer

    lea rdi, [rel cursor_bg_buffer]      ; destination = new temp buffer
    mov r8, cursor_size                  

.save_row:
    mov rcx, cursor_size                 
    rep movsd                            
    
    ; Jump to the next row in the backbuffer
    mov rax, [rel framebuffer_pitch]
    shl rax, 2
    sub rax, (cursor_size * 4)           ; subtract whatever was read
    add rsi, rax                         
    
    dec r8
    jnz .save_row

    pop rbp
    ret

; ------------------------------------------------------------------------------
; restore_cursor_background
; Restores a block from cursor_bg_buffer back to the backbuffer
; ------------------------------------------------------------------------------
restore_cursor_background:
    push rbp
    mov rbp, rsp

    cmp byte [rel cursor_is_saved], 0
    jz .done                             ; Skip if nothing is saved

    ; Calculate backbuffer offset: (saved_Y * pitch + savedX) * 4
    mov rax, [rel saved_cursor_y]
    mul qword [rel framebuffer_pitch]    
    add rax, [rel saved_cursor_x]                         
    shl rax, 2 
    mov rdi, [rel backbuffer_ptr]
    add rdi, rax                         ; draw to backed buffer

    lea rsi, [rel cursor_bg_buffer]      ; from our buffer
    mov r8, cursor_size                  

.restore_row:
    mov rcx, cursor_size
    rep movsd
    
    mov rax, [rel framebuffer_pitch]
    shl rax, 2
    sub rax, (cursor_size * 4)
    add rdi, rax
    
    dec r8
    jnz .restore_row

.done:
    pop rbp
    ret