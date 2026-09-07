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
    LOG "No mouse has been detected!"
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
    
    cmp byte [rel in_menu], 1
    jne .in_game

    ; width check for all buttons
    mov eax, dword [rel screen_w]
    shr eax, 1
    mov edi, eax
    sub edi, 150
    cmp ecx, edi
    jl .done
    add edi, 300
    cmp ecx, edi
    jge .done
    
    ; height check
    mov eax, dword [rel screen_h]
    shr eax, 1
    
    ; host btn
    mov edi, eax
    sub edi, 100
    cmp r8d, edi
    jl .done
    add edi, 50
    cmp r8d, edi
    jl .select_host
    
    ; join btn
    mov edi, eax
    cmp r8d, edi
    jl .done
    add edi, 50
    cmp r8d, edi
    jl .select_join
    
    ; offline btn
    mov edi, eax
    add edi, 100
    cmp r8d, edi
    jl .done
    add edi, 50
    cmp r8d, edi
    jl .select_offline
    jmp .done

.select_host:
    mov byte [rel net_role], 1
    mov byte [rel in_menu], 0
    jmp .done
.select_join:
    mov byte [rel net_role], 2
    mov byte [rel in_menu], 0
    jmp .done
.select_offline:
    mov byte [rel net_role], 0
    mov byte [rel in_menu], 0
    jmp .done
    
.in_game:
    ; LOG "Mouse Y = %d", r8
    cmp byte [rel match_state], 0
    je .game_is_active
    
    ; check if the click is inside the restart button
    mov edi, dword [rel btn_x]
    cmp ecx, edi
    jl .done                      ; too far left
    add edi, dword [rel btn_w]
    cmp ecx, edi
    jge .done                     ; too far right
    
    mov edi, dword [rel btn_y]
    cmp r8d, edi
    jl .done                      ; too far above
    add edi, dword [rel btn_h]
    cmp r8d, edi
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
    sub ecx, dword [rel board_x]
    jl .off_board                ; too far left
    
    mov eax, ecx
    xor edx, edx
    div dword [rel tile_size]
    cmp eax, 8
    jge .off_board               ; too far right
    mov ebx, eax                     ; EBX = column
    
    sub r8d, dword [rel board_y]
    jl .off_board                ; too high
    
    mov eax, r8d
    xor edx, edx
    div dword [rel tile_size]
    cmp eax, 8
    jge .off_board               ; too low
    

    shl eax, 4                       ; row * 16
    add eax, ebx                     ; + column
    mov r8, rax                      ; = index

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
    
    mov r10d, dword [rel tile_size]  ; load dynamic tile size
    imul r8, r10
    add r8d, dword [rel board_x]     ; R8 = screen x
    
    shr rax, 4
    imul rax, r10
    add eax, dword [rel board_y]     ; RAX = screen y
    
    ; check x bounds (menu will appear on the promoted column)
    cmp rcx, r8
    jl .not_intercepted
    add r8, r10                      ; add tile_size
    cmp rcx, r8
    jge .not_intercepted
    
    ; check y index (this will determine the option picked)
    mov r9, rdx              
    sub r9, rax              
    
    ; direction
    mov bl, byte [rel current_color]
    test bl, bl
    jnz .black_bounds
    
.white_bounds:
    cmp r9, 0
    jl .not_intercepted
    mov r11, r10
    imul r11, 4                      ; tile_size * 4
    cmp r9, r11
    jge .not_intercepted
    
    mov rax, r9
    xor rdx, rdx                 
    div r10                          ; divide by tile_size
    jmp .execute
    
.black_bounds:
    mov r9, rax
    add r9, r10                      ; add tile_size
    dec r9
    sub r9, rdx 

    cmp r9, 0
    jl .not_intercepted
    mov r11, r10
    imul r11, 4                      ; tile_size * 4
    cmp r9, r11
    jge .not_intercepted
    
    mov rax, r9
    xor rdx, rdx                 
    div r10                          ; divide by tile_size
    
.execute:
    call resolve_promotion
    mov rax, 1
    ret

.not_intercepted:
    xor rax, rax
    ret


; ------------------------------------------------------------------------------
; process_mouse_input
; Handles mouse input once mouse is initialized.
; Declutters the main loop for the most part.
; ------------------------------------------------------------------------------
process_mouse_input:
    push rbp
    mov rbp, rsp
    push r14
    push r15
    xor r15, r15                       
    mov r14, 16          ; ≤ 16 packets per frame please               
    
.read_loop:
    call update_mouse                  
    test rax, rax                      
    jnz .check_draw                    
    
    mov r15, 1                         
    dec r14                            
    jz .flush_queue                    
    jmp .read_loop                     

.flush_queue:
    mov rcx, [rel mouse_ptr]
    xor rdx, rdx                       
    mov rax, [rcx + EFI_SIMPLE_POINTER_PROTOCOL.Reset]          
    sub rsp, 32
    call rax
    add rsp, 32            
    

.check_draw:
    test r15, r15
    jz .done                             
    
    movzx eax, byte [rel mouse_state + 12] 
    movzx ebx, byte [rel prev_lmb_state]   

    cmp bl, 1
    jne .save_mouse_state
    cmp al, 0
    jne .save_mouse_state

    mov r12b, byte [rel in_menu]      
    call handle_mouse_click
    
    ; did the click happen inside the menu?
    cmp r12b, 1
    je .menu_click_post
    
    ; no, draw the game then
    cmp byte [rel net_role], 0
    je .skip_network
    call poll_network_events     
.skip_network:
    call render_playfield
    call swap_buffers               
    mov byte [rel cursor_is_saved], 0    
    jmp .save_mouse_state

.menu_click_post:
    ; yes, but it changed the game state, skip drawing for a while
    cmp byte [rel in_menu], 0
    je .save_mouse_state
    
    ; yes, redraw
    call render_main_menu
    call swap_buffers
    mov byte [rel cursor_is_saved], 0  

.save_mouse_state:
    mov byte [rel prev_lmb_state], al
    ; copy background from below cursor
    call restore_cursor_background
    
    ; embed the new cursor into the back
    mov rcx, [rel saved_cursor_x]
    mov rdx, [rel saved_cursor_y]
    call push_cursor_region

    ; save the background below the cursor
    movzx rcx, dword [rel mouse_x]
    movzx rdx, dword [rel mouse_y]
    mov [rel saved_cursor_x], rcx
    mov [rel saved_cursor_y], rdx
    call save_cursor_background
    mov byte [rel cursor_is_saved], 1

    ; draw the cursor onto the backbuffer
    call draw_cursor 

    ; draw the new cursor to the physical screen
    movzx rcx, dword [rel mouse_x]
    movzx rdx, dword [rel mouse_y]
    call push_cursor_region

.done:
    pop r15
    pop r14
    pop rbp
    ret