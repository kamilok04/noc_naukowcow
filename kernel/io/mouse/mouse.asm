; ------------------------------------------------------------------------------
; init_mouse
; Locates and resets the EFI_SIMPLE_POINTER_PROTOCOL
; ------------------------------------------------------------------------------
init_mouse:
    push rbp
    mov rbp, rsp
    push rbx
    
    ; 8 bytes for the 5th argument and align to 64 bytes
    sub rsp, 56
    mov rbx, [rel boot_services_ptr]
    
    ; get all mouse handles
    mov rcx, 2                           ; search by protocol
    lea rdx, [rel GUID_SIMPLE_POINTER]   
    xor r8, r8                           
    lea r9, [rel handle_count]           
  
    
    lea rax, [rel handle_buffer]
    mov [rsp + 32], rax                  
    
    call [rbx + EFI_BOOT_SERVICES.LocateHandleBuffer]                     ; 
    test rax, rax
    jnz .error
    ; LOG "%d mouse protocols located.", [rel handle_count]

    ; get the last mouse ptr handle because VMs do stupid stuff sometimes
    mov rax, [rel handle_count]
    dec rax                              ; [-1]
    mov rdx, [rel handle_buffer]
    mov rcx, [rdx + rax * 8]             ; RCX = target hw handle
    
    lea rdx, [rel GUID_SIMPLE_POINTER]
    lea r8, [rel mouse_ptr]
    call [rbx + EFI_BOOT_SERVICES.HandleProtocol]     
    
    test rax, rax
    jnz .error
    
    mov rcx, [rel mouse_ptr]
    mov rdx, 1                           ; ExtendedVerification = TRUE
    mov rax, [rcx]
    call rax
    jmp .done

.error:
    LOG "Mouse Hardware Bind Failed! Code: %x", rax
.done:
    add rsp, 56
    pop rbx
    pop rbp
    ret

; ------------------------------------------------------------------------------
; update_mouse
; Polls the mouse state and updates absolute coordinates.
; ------------------------------------------------------------------------------
update_mouse:
    push rbp
    mov rbp, rsp
    sub rsp, 32
    
    mov rcx, [rel mouse_ptr]
    test rcx, rcx
    jz .no_mouse                 ; Safety check if mouse isn't loaded

    lea rdx, [rel mouse_state]
    mov rax, [rcx + EFI_SIMPLE_POINTER_PROTOCOL.GetState]
    call rax
    
    test rax, rax            ; EFI_SUCCESS (0)?
    jnz .done                ; If not 0 (e.g., EFI_NOT_READY), no movement happened

    ; get deltas
    lea rbx, [rel mouse_state]
    mov eax, dword [rbx + EFI_SIMPLE_POINTER_STATE.RelativeMovementX]
    mov edx, dword [rbx + EFI_SIMPLE_POINTER_STATE.RelativeMovementY]
    
    ; sensitivity 
    imul eax, 2
    imul edx, 2

    mov ecx, dword [rel mouse_x]
    add ecx, eax               ; Apply delta

    ; Clamp < 0
    test ecx, ecx
    jns .check_x_max
    xor ecx, ecx               ; Force to 0 if negative
    jmp .save_x

.check_x_max:
    mov edi, dword [rel screen_w]
    sub edi, 10                ; Subtract cursor width (10px) so it doesn't clip
    cmp ecx, edi
    jle .save_x
    mov ecx, edi               ; Clamp to max width

.save_x:
    mov dword [rel mouse_x], ecx


    mov ecx, dword [rel mouse_y]
    add ecx, edx               ; Apply delta

    ; Clamp < 0
    test ecx, ecx
    jns .check_y_max
    xor ecx, ecx               ; Force to 0 if negative
    jmp .save_y

.check_y_max:
    mov edi, dword [rel screen_h]
    sub edi, 10                ; Subtract cursor height (10px)
    cmp ecx, edi
    jle .save_y
    mov ecx, edi               ; Clamp to max height

.save_y:
    mov dword [rel mouse_y], ecx
    xor rax, rax
    jmp .done

.no_mouse:
    ;  LOG "No mouse has been detected!"
.done:
    add rsp, 32
    pop rbp
    ret

; ------------------------------------------------------------------------------
; handle_mouse_click
; Converts mouse coordinates to a 0x88 index and generates legal moves.
; ------------------------------------------------------------------------------
handle_mouse_click:
    push rbp
    mov rbp, rsp
    push rax
    push rcx
    push rdx
    push r10
    push r11

    ; get mouse coordinates
    mov ecx, dword [rel mouse_x]
    mov r8d, dword [rel mouse_y]

    mov r10, rcx        ; keep the mouse coords
    mov r11, r8         

    ; LOG "Mouse Y = %d", r8
    cmp byte [rel match_state], 0
    je .game_is_active
    
    ; check if the click is inside the restart button
    cmp rcx, BTN_X
    jl .done                      ; too far left
    cmp rcx, BTN_X + BTN_W
    jge .done                     ; too far right
    
    cmp r8, BTN_Y
    jl .done                      ; too far above
    cmp r8, BTN_Y + BTN_H
    jge .done                     ; too far below
    
    call reset_game               ; ok; restart
    jmp .done                     ; block all else, the game is done

    
.game_is_active:
    mov rdx, r11 
    call check_promotion_click
    test rax, rax
    jnz .done                    ; if intercepted by the menu, exit immediately

    cmp byte [rel promotion_pending], 1
    je .done                     ; ignore clicks outside the promotion menu
    
    mov rcx, r10
    mov r8, r11

    ; normalize
    sub rcx, BOARD_START_X
    jl .off_board                    ; too far left
    cmp rcx, 8 * SQUARE_SIZE
    jge .off_board                   ; too far right
    
    sub r8, BOARD_START_Y
    jl .off_board                    ; too far up
    cmp r8, 8 * SQUARE_SIZE
    jge .off_board                   ; too far down

    mov r9, SQUARE_SIZE
    
    ; get the column
    mov rax, rcx
    xor rdx, rdx                 
    div r9                           
    mov rcx, rax                     ; RCX = column
    
    mov rax, r8
    xor rdx, rdx
    div r9
    mov r8, rax                      ; R8 = row
    ; see what moves are legal
    ; grab the index
    shl r8, 4
    or rcx, r8

    mov r8, rcx
    ; LOG "Click is on the board, %x", r8
    call the_chess_state_machine
    jmp .done
    
.off_board:
    ; if off-board, clear
    mov byte [rel valid_moves_count], 0

.done:
    pop r11
    pop r10
    pop rdx
    pop rcx
    pop rax
    pop rbp
    ret

; ------------------------------------------------------------------------------
; check_promotion_click
; Inputs: RCX = screen x, RDX = screen y
; Outputs: RAX = 1 if click was intercepted, RAX = 0 if normal board click
; ------------------------------------------------------------------------------
check_promotion_click:
    cmp byte [rel promotion_pending], 1
    jne .not_intercepted
    
    movzx rax, byte [rel promotion_sq]
    mov r8, rax
    and r8, 0x0F
    imul r8, SQUARE_SIZE
    add r8, BOARD_START_X   ; R8 = screen x
    
    shr rax, 4
    imul rax, SQUARE_SIZE
    add rax, BOARD_START_Y   ; RAX = screen y
    
    ; check x bounds (menu will appear on the promoted column)
    cmp rcx, r8
    jl .not_intercepted
    add r8, SQUARE_SIZE
    cmp rcx, r8
    jge .not_intercepted
    
    ; check y index (this willl determine the option picked)
    mov r9, rdx              
    sub r9, rax              
    
    ; Direction branch
    mov bl, byte [rel current_color]
    test bl, bl
    jnz .black_bounds
    
.white_bounds:
    ; white menu goes down: 
    ; difference from menu's start must be 0 to (4*SQUARE_SIZE - 1)
    cmp r9, 0
    jl .not_intercepted
    mov r10, SQUARE_SIZE
    imul r10, 4
    cmp r9, r10
    jge .not_intercepted
    
    mov rax, r9
    xor rdx, rdx                 
    mov r10, SQUARE_SIZE         
    div r10                      ; rax = clicked index
    jmp .execute
    
.black_bounds:
    
    mov r9, rax
    add r9, SQUARE_SIZE
    dec r9
    sub r9, rdx ; distance to the bottom of the tile

    cmp r9, 0
    jl .not_intercepted
    mov r10, SQUARE_SIZE
    imul r10, 4
    cmp r9, r10
    jge .not_intercepted
    
    mov rax, r9
    xor rdx, rdx                 
    mov r10, SQUARE_SIZE         
    div r10           
    
.execute:
    call resolve_promotion
    
    mov rax, 1               ; tell mouse handler to skip standard processing
    ret

.not_intercepted:
    xor rax, rax             ; normal click
    ret