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
    push r8
    push r9
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
    pop r9
    pop r8
    pop rdx
    pop rcx
    pop rax
    pop rdi
    ret

; ------------------------------------------------------------------------------
; draw_bitmap_scaled
; Draws a 32-bit uncompressed BMP, scaling it via NN interpolation, filling the square
; Inputs:
;   RDI - Framebuffer Base Address
;   RSI - PixelsPerScanLine (Pitch)
;   RCX - Start X (Screen)
;   RDX - Start Y (Screen)
;   R8  - Pointer to the BMP file in memory
; ------------------------------------------------------------------------------
; NN interpolation
; in short: if a bitmap pixel cannot be mapped cleanly to a screen pixel,
; select the closest available one.
; as this is a piece-wise assignment, the final result will not have gaps.
draw_bitmap_scaled:
    push rbp
    mov rbp, rsp
    push rax
    push rbx
    push rcx
    push rdx
    push rdi
    push rsi
    push r8
    push r9
    push r10
    push r11
    push r12
    push r13
    push r14
    push r15

    ; allocate cache space
    sub rsp, 16

    mov r9, rdx

    ; parse the BMP Header
    movzx r12, dword [r8 + 0x12]     ; R12 = width
    movzx r13, dword [r8 + 0x16]     ; R13 = height
    movzx rbx, dword [r8 + 0x0a]     
    add r8, rbx                      ; R8 = data pointer
    
    mov r14d, dword [rel tile_size] 
    test r14, r14
    jz .done

    ; calculate pieces pixels will be assigned into
    ; step_x = (r12 << 16) / r14
    ; fixed-point float logic this is
    mov rax, r12
    shl rax, 16
    xor rdx, rdx
    div r14
    mov r10, rax                     ; R10 = step_x
    
    ; step_y = (r13 << 16) / r14
    mov rax, r13
    shl rax, 16
    xor rdx, rdx
    div r14
    mov r11, rax                     ; R11 = step_y

    ; BMPs are bottom up, start y at (height-1)
    mov rbx, r13
    dec rbx
    shl rbx, 16                      ; RBX = y accumulator
    
    ; R15 = width in bytes
    mov r15, r12
    shl r15, 2

    mov rax, r13
    dec rax
    imul rax, r15
    add r8, rax                      ; R8 = address of visual top row

    xor rbx, rbx                     
    push r14                         ;

.row_loop:
    ; RDI = x Accumulator
    xor rdi, rdi                     
    mov rax, rcx                     ; RAX = Screen X
    mov r13d, dword [rel tile_size]          
    
    ; get source y  
    ; R8 + (y * width_bytes) + (x * 4)
    mov rdx, rbx
    shr rdx, 16                         
    imul rdx, r15                   ; RAX = y * row_bytes

    mov [rbp - 128], rdx            ; voodoo time!
                                    ; in the prologue, 15 registers are pushed
                                    ; rbp doesn't count, though
                                    ; 14 * 8 = (rbp -) 112
                                    ; then another 16 bytes of cache were allocated
                                    ; 112 + 16 = (rbp -) 128
                                    ; this places slot 1 of assigned cache at [rbp - 128]
                                    ; another slot is at [rbp - 120]

                                    ; note: this math is RBP-relative
                                    ; if it were, as usual, RSP-relative
                                    ; then nested loops would throw the count off
                                    ; RBP does not concern itself with what the method does

                                    ; another voodoo note here: this call is *very* fast
                                    ; I'm afraid the details are beyond my understanding,
                                    ; but it has to do with near jumps [-128;127] of the x86 arch
                                    ; disp8-based addressing can fit within the L1 cache,
                                    ; while others cannot -- this is my guess

    ; compute dest y
    mov rdx, r9
    imul rdx, rsi
    mov [rbp - 120], rdx ; cache
    
.pixel_loop:
    mov r12, rdi                     ; RDI is X accumulator
    shr r12, 16

    mov rdx, r12
    shl rdx, 2                       ; RDX = x * 4
    sub rdx, [rbp - 128]                     ; RDX = (x * 4) - (y * row_bytes)
    lea rdx, [r8 + rdx]              ; RAX = addr
    
    mov edx, dword [rdx]            ; EDX = color
    
    mov r12d, edx               
    and r12d, 0x00FFFFFF              
    cmp r12d, COLOR_KEY          
    je .skip_pixel                   
    
    
    ; destination address = backbuffer + (y * pitch + x) * 4
    mov r14, [rbp - 120]              ; load cached y * pitch
    add r14, rax                     ; + x
    shl r14, 2                       ; * 4
    add r14, [rel backbuffer_ptr]    ; RDX = dest
    
    mov dword [r14], edx

.skip_pixel:
    add rdi, r10                     ; x acc+= step_x
    inc rax                          ; screen x += 1
    
    dec r13
    jnz .pixel_loop
    
    ; Row complete
    add rbx, r11                     ; y acc -= step_y (moving upwards)
    inc r9                           ; screen y += 1
    
    pop r14                          
    dec r14
    push r14                         
    jnz .row_loop
    
    pop r14                          

.done:
    add rsp, 16
    pop r15
    pop r14
    pop r13
    pop r12
    pop r11
    pop r10
    pop r9
    pop r8
    pop rsi
    pop rdi
    pop rdx
    pop rcx
    pop rbx
    pop rax
    mov rsp, rbp
    pop rbp
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

; Draw a 32x32 mouse pointer
draw_cursor:
    push rbp
    mov rbp, rsp
    
    mov r8, qword [rel bmp_cursor]
    test r8, r8
    jz .done                       ; Safety check: don't crash if BMP failed to load
    
    mov rdi, [rel backbuffer_ptr]
    mov rsi, [rel framebuffer_pitch]
    
    mov ecx, dword [rel mouse_x]   ; RCX = Start X
    mov edx, dword [rel mouse_y]   ; RDX = Start Y
    
    call draw_bitmap
    
.done:
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

; ------------------------------------------------------------------------------
; draw_string
; Inputs: R8  = Pointer to null-terminated string
;         RCX = start x, RDX = start y, R10D = color
;         R13 = scale factor (1 = 8x8, 2 = 16x16, 3 = 24x24, ...)
; ------------------------------------------------------------------------------
draw_string:
    push rbp
    mov rbp, rsp
    push rax
    push rcx
    push rsi
    push r8
    push r9
    push r11

    mov rsi, r8                  ; RSI = string ptr

.loop:
    movzx rax, byte [rsi]        ; char-by-char read, as some characters take multiple bytes
    test al, al
    jz .done                     ; terminator

    cmp al, 0xC0
    jae .utf8_char               ; UTF-8 lead

    ; ASCII
    jmp .draw_glyph

; Idea behind reading UTF chars
; The character has 1 or more bytes
; If the character is more than 1 byte long,
; its first byte (the lead) must fall within a particular range
; detect that and process future bytes into a mapping
; this parser only support 1- and 2-byte long characters (U+0000 - U+07FF)
; passing a longer character would probably cause corruption and other fun stuff

.utf8_char:
    mov r9b, al                  ; R9B = lead
    inc rsi                      ; next byte
    mov r11b, byte [rsi]         ; R11B = trail
    
    push rsi                     ; save ptr
    lea rbx, [rel utf8_pl_map]
    
.map_scan:
    mov al, byte [rbx]           
    test al, al
    jz .unknown_char             ; terminated without resolving, print '?'
    
    cmp al, r9b                  ; lead byte match?
    jne .next_map_entry
    
    mov al, byte [rbx + 1]
    cmp al, r11b                 ; trail byte match?
    je .map_found
    
.next_map_entry:
    add rbx, 3                   ; Jump 3 bytes forward in map
    jmp .map_scan
    
.map_found:
    movzx rax, byte [rbx + 2]    ; get the mapped extended index (128-145)
    pop rsi
    jmp .draw_glyph
    
.unknown_char:
    pop rsi
    mov rax, '?'                 ; if you don't know, print a question mark

.draw_glyph:
    ; calculate pointer: font_full_ascii + (index * 8)
    shl rax, 3                   
    lea r8, [rel font_full_ascii]
    add r8, rax                  

    push rcx
    push rsi
    call draw_char            ; R8 = pointer, RCX = X, RDX = Y
    pop rsi
    pop rcx

    lea rcx, [rcx + 8 * r13]       
    inc rsi                      ; next char
    jmp .loop

.done:
    pop r11
    pop r9
    pop r8
    pop rsi
    pop rcx
    pop rax
    pop rbp
    ret

; ------------------------------------------------------------------------------
; draw_char
;   Renders a single 8x8 1-bit glyph to the linear backbuffer.
; Inputs:
;   R8   - Pointer to character data (from font array)
;   RCX  - X (top-left of char)
;   RDX  - Y (top-left of char)
;   R10D - 32-bit XXRRGGBB color
;   R13 - scale factor (1 = 8x8, 2 = 16x16, ...)
; ------------------------------------------------------------------------------
draw_char:
    push rbp
    mov rbp, rsp
    push rax
    push rcx
    push rdx
    push rdi
    push r8
    push r9
    push r11
    push r12
    push r14
    push r15



    mov r9, 8                         ; 8 rows high by default
  ;  mul r9, r13                       ; apply scaling
.row_loop:
    mov r12b, byte [r8]               ; load a byte
    mov r11, 8                        ; 8 columns wide
   ; mul r11, r13                      ; scale
    
    push rcx                          

.pixel_loop:
    shl r12b, 1                       ; check the leftmost bit
    jnc .skip_pixel                   ; CF = 0: transparency flag, skip
    
    mov r14, r13                      
.fill_y:
    mov r15, r13                     
.fill_x:

    ; Address = backbuffer + [ (Y + r14 - 1)* pitch + (X + r15 - 1) ] * 4
    mov rax, rdx
    add rax, r14
    dec rax
    imul rax, [rel framebuffer_pitch]
    
    mov rbx, rcx
    add rbx, r15
    dec rbx
    
    add rax, rbx
    shl rax, 2                        
    
    mov rdi, [rel backbuffer_ptr]
    add rdi, rax
    mov dword [rdi], r10d             

    dec r15
    jnz .fill_x
    dec r14
    jnz .fill_y  

.skip_pixel:
    add rcx, r13                         
    dec r11                           
    jnz .pixel_loop                
    
    pop rcx                           
    add rdx, r13                         
    inc r8                            
    dec r9                            
    jnz .row_loop                     
    
    pop r15
    pop r14
    pop r12
    pop r11
    pop r9
    pop r8
    pop rdi
    pop rdx
    pop rcx
    pop rax
    pop rbp
    ret