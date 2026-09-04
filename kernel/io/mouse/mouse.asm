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
    LOG "%d mouse protocols located.", [rel handle_count]

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
    
    ; get mouse coordinates
    mov ecx, dword [rel mouse_x]
    mov r8d, dword [rel mouse_y]
    LOG "Mouse Y = %d", r8
    
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
    LOG "Click is on the board, %x", r8
    call the_chess_state_machine
    jmp .done
    
.off_board:
    ; if off-board, clear
    mov byte [rel valid_moves_count], 0

.done:
    pop rdx
    pop rcx
    pop rax
    pop rbp
    ret