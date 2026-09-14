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
    sub edi, 32               ; Subtract cursor width so it doesn't clip
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
    sub edi, 32                ; Subtract cursor height (10px)
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
; Happens to navigate the entire remainder of the UI too
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

    cmp byte [rel in_menu], 2
    jne .check_main_menu
    
    ; cancel btn check
    mov eax, dword [rel screen_h]
    shr eax, 1
    mov edi, eax
    add edi, 150                 ; top
    cmp r8d, edi
    jl .done
    add edi, 50                  ; bottom
    cmp r8d, edi
    jge .done
    
    ; cancelled, revert to main menu
    call network_teardown
    mov byte [rel in_menu], MENU_STATE_MAIN
    ; TCP abort will go here, eventually
    jmp .done
    

.check_main_menu:
    
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
    ;sub edi, 100
    cmp r8d, edi
    jl .done
    add edi, 50
    cmp r8d, edi
    jl .select_host
    
    ; join btn
    mov edi, eax
    cmp r8d, edi
    add edi, 100
    jl .done
    add edi, 50
    cmp r8d, edi
    jl .select_join
    
    ; offline btn
    mov edi, eax
    add edi, 200
    cmp r8d, edi
    jl .done
    add edi, 50
    cmp r8d, edi
    jl .select_offline
    jmp .done

.select_host:
    LOG "Server role picked."
    mov byte [rel net_role], NET_ROLE_SERVER
    mov byte [rel local_color], 0
    ;mov byte [rel in_menu], MENU_STATE_AWAITING_CONNECTION      
    call transition_to_network
    jmp .done
.select_join:
    LOG "Client role picked."
    mov byte [rel net_role], NET_ROLE_CLIENT
    mov byte [rel local_color], 1
    ;mov byte [rel in_menu], MENU_STATE_AWAITING_CONNECTION   
    call transition_to_network
    jmp .done
.select_offline:
    mov byte [rel net_role], NET_ROLE_OFFLINE
    mov byte [rel in_menu], MENU_STATE_IN_GAME       
    call calculate_board_layout           
    call render_playfield                 
    call swap_buffers                     
    mov byte [rel cursor_is_saved], 0
    jmp .done
    
.in_game:
    ; LOG "Mouse Y = %d", r8
    call handle_ui_click ; UI goes first because transcript
    test rax, rax
    jnz .done

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
    
    
    ; wydaj polecenie restartu
    cmp byte [rel net_role], NET_ROLE_OFFLINE
    je .do_reset
    
    mov cl, 0xBB                  ; 0xBB = pole-komenda
    mov dl, 0xBB
    xor r8b, r8b
    call send_network_move
.do_reset:
    xor byte [rel local_color], 1 ; podmień kolory
    call reset_game               ; ok; restart
    jmp .done                     ; nie pozwalaj na nic poza kliknięciem przycisku "rewanż"

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

    ; client-based logic
    ; mirror the square if black pieces are on the bottom
    cmp byte [rel local_color], 1
    jne .no_flip_click
    mov r9, 0x77
    sub r9, r8
    mov r8, r9
.no_flip_click:

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

    ; mirror the square based on client perspective
    movzx rax, byte [rel promotion_sq]
    cmp byte [rel local_color], 1
    jne .no_flip_pclick
    mov rbx, 0x77
    sub rbx, rax
    mov rax, rbx
.no_flip_pclick:
    
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
    xor bl, byte [rel local_color]

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
    
.menu_click_post:
    cmp byte [rel in_menu], MENU_STATE_MAIN
    je .draw_main
    cmp byte [rel in_menu], MENU_STATE_AWAITING_CONNECTION
    je .draw_awaiting

.draw_game:
    call render_playfield
    jmp .do_swap

.draw_main:
    call render_main_menu
    jmp .do_swap

.draw_awaiting:
    call render_awaiting_screen

.do_swap:  
    call swap_buffers               
    mov byte [rel cursor_is_saved], 0    
    jmp .save_mouse_state


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

; ------------------------------------------------------------------------------
; handle_ui_click
; Checks if the current mouse_x / mouse_y falls within any UI button.
; Outputs: RAX = 1 if a button was clicked, RAX = 0 otherwise.
; ------------------------------------------------------------------------------
handle_ui_click:
    push rbp
    mov rbp, rsp
    push rbx
    push rcx
    push rdx
    push r8

    mov ecx, dword [rel mouse_x]
    mov edx, dword [rel mouse_y]

    ; transcript back
    lea r8, [rel btn_back_box]
    call .check_collision
    test rax, rax
    jnz .clicked_back

    ; transcript forward
    lea r8, [rel btn_forward_box]
    call .check_collision
    test rax, rax
    jnz .clicked_forward

    ; other buttons don't count with the game done
    cmp byte [rel match_state], 0
    jne .done

    ; and when offline
    cmp byte [rel net_role], NET_ROLE_OFFLINE
    je .done

    ; 1/2
    lea r8, [rel btn_draw_box]
    call .check_collision
    test rax, rax
    jnz .clicked_draw

    ; giveup
    lea r8, [rel btn_giveup_box]
    call .check_collision
    test rax, rax
    jnz .clicked_giveup

    ; none of those
    xor rax, rax
    jmp .done

; individual btn handlers

.clicked_back:
    ; if auto-scroll active, go back
    mov ebx, dword [rel ui_manual_scroll]
    cmp ebx, -1
    jne .do_back    


    ; disengage autoscrolling
    movzx ebx, word [rel transcript_scroll]
    
.do_back:
    test ebx, ebx
    jz .handled                              ; @ the top
    
    dec ebx
    mov dword [rel ui_manual_scroll], ebx
    ; LOG "UI: Scrolled Transcript Back"
    jmp .handled

.clicked_forward:
    mov ebx, dword [rel ui_manual_scroll]
    cmp ebx, -1
    je .handled                              ; auto-scroll is active, so this is the bottom, skip
    
    ; get the max offset
    movzx eax, word [rel transcript_count]
    shr eax, 1
    mov ecx, dword [rel transcript_lines]
    
    cmp eax, ecx
    jle .snap_to_auto                        ; none, engage auto-scroll instead
    
    sub eax, ecx                             ; EAX = max scroll offset
    cmp ebx, eax
    jge .snap_to_auto                        ; it's the bottom, engage auto-scroll now
    
    inc ebx
    mov dword [rel ui_manual_scroll], ebx
    ;LOG "UI: Scrolled Transcript Forward"
    jmp .handled

.snap_to_auto:
    mov dword [rel ui_manual_scroll], -1
    LOG "UI: Transcript Snapped to Auto-Scroll"
    jmp .handled

.clicked_draw:
    mov ebx, dword [rel ui_action_state]
    cmp ebx, ACTION_STATE_DEFAULT
    je .init_draw_offer
    cmp ebx, ACTION_STATE_SURRENDER
    je .cancel_action            ; red 'X' cancels surrender
    cmp ebx, ACTION_STATE_DRAW
    je .confirm_draw_offer       ; green 'Check' confirms draw
    cmp ebx, ACTION_STATE_INCOMING_DRAW
    je .accept_draw              ; green 'Check' accepts incoming draw
    jmp .handled

.init_draw_offer:
    mov dword [rel ui_action_state], ACTION_STATE_DRAW
    jmp .handled
    
.confirm_draw_offer:
    mov dword [rel ui_action_state], ACTION_STATE_DEFAULT
    mov cl, 0xCC
    mov dl, 0xCC
    xor r8b, r8b
    call send_network_move
    LOG "UI: Sent Draw Offer"
    jmp .handled
    
.accept_draw:
    mov dword [rel ui_action_state], ACTION_STATE_DEFAULT
    mov byte [rel match_state], 3 ; end game locally
    mov cl, 0xCD
    mov dl, 0xCD
    xor r8b, r8b
    call send_network_move
    LOG "UI: Accepted Draw"
    jmp .handled

.clicked_giveup:
    mov ebx, dword [rel ui_action_state]
    cmp ebx, ACTION_STATE_DEFAULT
    je .init_giveup
    cmp ebx, ACTION_STATE_SURRENDER
    je .confirm_giveup           ; green 'Check' confirms surrender
    cmp ebx, ACTION_STATE_DRAW
    je .cancel_action            ; red 'X' cancels draw offer
    cmp ebx, ACTION_STATE_INCOMING_DRAW
    je .cancel_action            ; red 'X' denies incoming draw
    jmp .handled

.init_giveup:
    mov dword [rel ui_action_state], ACTION_STATE_SURRENDER
    jmp .handled
    
.confirm_giveup:
    mov dword [rel ui_action_state], ACTION_STATE_DEFAULT
    ; opponent wins
    mov al, byte [rel local_color]
    xor al, 1
    add al, 1
    mov byte [rel match_state], al
    mov cl, 0xCE
    mov dl, 0xCE
    xor r8b, r8b
    call send_network_move
    LOG "UI: Surrendered"
    jmp .handled

.cancel_action:
    mov dword [rel ui_action_state], ACTION_STATE_DEFAULT
    jmp .handled

.handled:
    mov rax, 1
    jmp .done

; check for mouse collision
; ECX = mouse_x, EDX = mouse_y, R8 = box pointer
.check_collision:
    xor rax, rax
    mov ebx, dword [r8]          
    cmp ecx, ebx
    jl .miss
    add ebx, dword [r8 + 8]      
    cmp ecx, ebx
    jg .miss                     
    mov ebx, dword [r8 + 4]      
    cmp edx, ebx
    jl .miss
    add ebx, dword [r8 + 12]     
    cmp edx, ebx
    jg .miss                     
    mov rax, 1                   ; hit
.miss:
    ret

.done:
    pop r8
    pop rdx
    pop rcx
    pop rbx
    mov rsp, rbp
    pop rbp
    ret