; ------------------------------------------------------------------------------
; init_mouse
; Triggers the first device scan and returns the active pointer for the event loop.
; ------------------------------------------------------------------------------
init_mouse:
    push rbp
    mov rbp, rsp
    sub rsp, 32
    
    ; Reset tracking variables (Reusing existing .data variables)
    mov qword [rel temp_ptr], 0          
    mov qword [rel init_count], 0        
    
    call rescan_devices

    ; Return the active pointer in RCX for efi_main's .set_event
    mov rcx, [rel mouse_ptr]

    add rsp, 32
    pop rbp
    ret

; ------------------------------------------------------------------------------
; update_mouse
; Polls the mouse state and updates absolute coordinates.
; ------------------------------------------------------------------------------
update_mouse:
    push rbp
    mov rbp, rsp
    push rbx
    sub rsp, 40
    
    mov rcx, [rel mouse_ptr]
    test rcx, rcx
    jz .no_mouse                 ; Safety check if mouse isn't loaded

    ; ; zero the state because Life™
    ; mov qword [rel mouse_state], 0
    ; mov qword [rel mouse_state + 8], 0
    ; mov qword [rel mouse_state + 16], 0
    ; mov qword [rel mouse_state + 24], 0

    lea rdx, [rel mouse_state]
    mov rax, [rcx + EFI_SIMPLE_POINTER_PROTOCOL.GetState]
    call rax
    
    test rax, rax            ; EFI_SUCCESS (0)?
    ;jnz .done                ; If not 0 (e.g., EFI_NOT_READY), no movement happened
    jz .process_movement

    mov rbx, 0x8000000000000006
    cmp rax, rbx
    je .done                 ; No new devices, but the device is healthy
    
    ; something died, rescan
    LOG "Forced mouse rescan."
    mov qword [rel mouse_ptr], 0
    jmp .done

.process_movement:
    ; get deltas
    lea rbx, [rel mouse_state]

    ; kill all inputs while RMB is held
    ; what?
    ; this is a Real Life™ fix
    ; some UEFI is garbage and throws garbage into 
    ; mouse registers while RMB is held, saves ROM apparently
    ; dislike it? leave the boot services :)

    cmp byte [rbx + 13], 0
    je .apply_deltas

    xor eax, eax
    xor edx, edx
    jmp .apply_sensitivity

.apply_deltas:
    mov eax, dword [rbx + EFI_SIMPLE_POINTER_STATE.RelativeMovementX]
    mov edx, dword [rbx + EFI_SIMPLE_POINTER_STATE.RelativeMovementY]
.apply_sensitivity:
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
    inc rax
.done:
    add rsp, 40
    pop rbx
    mov rsp, rbp
    pop rbp
    ret

; ------------------------------------------------------------------------------
; rescan_devices
; Discovers the latest simple pointer device and updates the hardware event loop.
; ------------------------------------------------------------------------------
rescan_devices:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    sub rsp, 40
    mov rbx, [rel boot_services_ptr]

    mov qword [rel handle_buffer_size], 128
    mov rcx, 2                           
    lea rdx, [rel GUID_SIMPLE_POINTER]   
    xor r8, r8                           
    lea r9, [rel handle_buffer_size]           
    lea rax, [rel handle_buffer]
    mov [rsp + 32], rax                  
    
    call [rbx + EFI_BOOT_SERVICES.LocateHandle]                     
    
    test rax, rax
    jnz .done

    mov r12, [rel handle_buffer_size]
    shr r12, 3 ; /8                          
    test r12, r12
    jz .done
    
    ; handle disconnection too, iterate over all connected devices
    mov r13, r12
    dec r13
    lea r14, [rel handle_buffer]

.test_handle:
    cmp r13, 0
    jl .done ; all devices done

    mov rcx, [r14 + r13 * 8]

    ; what's that device, give me its protocol
    lea rdx, [rel GUID_SIMPLE_POINTER]
    lea r8, [rel temp_ptr]
    mov rax, [rbx + EFI_BOOT_SERVICES.HandleProtocol]
    call rax  

    test rax, rax
    jnz .next_handle 

    ; it's responding, try enabling it
    mov rcx, [rel temp_ptr]
    mov rdx, 1
    mov rax, [rcx + EFI_SIMPLE_POINTER_PROTOCOL.Reset]
    call rax

    test rax, rax
    jz .found_ok

.next_handle:
    dec r13
    jmp .test_handle

.found_ok:
    mov rcx, [rel temp_ptr]

    cmp rcx, [rel mouse_ptr]
    je .done

    mov [rel mouse_ptr], rcx
    mov rax, [rcx + 16]                  
    mov [rel wait_event_array], rax

.done:
    add rsp, 40
    pop r14
    pop r13
    pop r12
    pop rbx
    mov rsp, rbp
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
    push r12

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
    add edi, 400
    cmp ecx, edi
    jge .done

    ; compute Y, like in graphics
    mov r12d, dword [rel screen_h]
    shr r12d, 1
    mov edi, r12d
    add edi, 350
    cmp edi, dword [rel screen_h]
    jle .hitbox_y_ok
    
    mov r12d, dword [rel screen_h]
    sub r12d, 350
    cmp r12d, 10
    jge .hitbox_y_ok
    mov r12d, 10

.hitbox_y_ok:
    
    ; host btn
    mov edi, r12d ; R12D is the base Y
    cmp r8d, edi
    jl .select_c960
    add edi, 50
    cmp r8d, edi
    jl .select_host
    
    ; join btn
    mov edi, r12d
    add edi, 100
    cmp r8d, edi
    jl .select_c960
    add edi, 50
    cmp r8d, edi
    jl .select_join
    
    ; offline btn
    mov edi, r12d
    add edi, 200
    cmp r8d, edi
    jl .select_c960
    add edi, 50
    cmp r8d, edi
    jl .select_offline


    ; c960 btn
    mov edi, r12d
    add edi, 300
    cmp r8d, edi
    jl .done
    add edi, 50
    cmp r8d, edi
    jl .select_c960
    jmp .done


.select_host:
    LOG "Server role picked."
    mov byte [rel net_role], NET_ROLE_SERVER
    mov byte [rel local_color], 0
    cmp byte [rel chess960_mode], 1
    je .do_960_host
    mov rdi, 518                     
    jmp .generate_host
.do_960_host:
    call generate_random_seed        
.generate_host:
    call generate_chess960_board     
    mov word [rel sync_payload + 1], di
    lea rsi, [rel initial_board]
    lea rdi, [rel board]
    mov rcx, 128
    rep movsb
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

    cmp byte [rel chess960_mode], 1
    je .do_960_offline
    mov rdi, 518                    ; you have been fooled
                                    ; Chess960 mode is always active
                                    ; when picking host/offline,
                                    ; simply skip the RNG and always output
                                    ; the seed corresponding to the standard layout
                                    ; 
    jmp .generate_offline
.do_960_offline:
    call generate_random_seed        ; 1: Generates random seed into RDI
.generate_offline:
    call generate_chess960_board     ; Sets up initial_board and start trackers

    lea rsi, [rel initial_board]
    lea rdi, [rel board]
    mov rcx, 128
    rep movsb

    mov byte [rel in_menu], MENU_STATE_IN_GAME       
    call calculate_board_layout           
    call render_playfield                 
    call swap_buffers                     
    mov byte [rel cursor_is_saved], 0
    jmp .done

.select_c960:
    ; get bounding box
    mov eax, dword [rel screen_w]
    shr eax, 1
    sub eax, 150
    cmp ecx, eax
    jl .done          ; too far left
    add eax, 250      ; width (32px box + text width)
    cmp ecx, eax
    jg .done          ; too far right


    mov eax, r12d
    add eax, 300
    cmp r8d, eax
    jl .done           ; too high
    add eax, 32        ; btn height
    cmp r8d, eax
    jg .done         ; too low

    LOG "Chess960 btn click"
    ; ok; toggle the state
    xor byte [rel chess960_mode], 1

    jmp .done
    
.in_game:
    call handle_ui_click 
    test rax, rax
    jnz .done

    cmp byte [rel match_state], 0
    je .game_is_active
    
    ; exit btn
    mov edi, dword [rel btn2_x]
    cmp ecx, edi
    jl .check_rematch_btn                    ; too far left
    add edi, dword [rel btn2_w]
    cmp ecx, edi
    jge .check_rematch_btn                   ; too far right
    
    mov edi, dword [rel btn2_y]
    cmp r8d, edi
    jl .check_rematch_btn                    ; too high
    add edi, dword [rel btn2_h]
    cmp r8d, edi
    jge .check_rematch_btn                   ; too low

    ; hit - back to menu btn
    cmp byte [rel net_role], NET_ROLE_OFFLINE
    je .do_exit

    ; we're online? not anymore, eat dust
    mov cl, 0xCF                     
    mov dl, 0xCF
    xor r8b, r8b
    call send_network_move
    
.do_exit:
    call network_teardown
    call reset_game
    mov byte [rel in_menu], MENU_STATE_MAIN
    jmp .done

  
.check_rematch_btn:
    cmp byte [rel rematch_state], 3
    je .done                                 ; opp dared to leave, ignore
    cmp byte [rel rematch_state], 1
    je .done                                 ; response already pending, ignore

    mov edi, dword [rel btn_x]
    cmp ecx, edi
    jl .done                                
    add edi, dword [rel btn_w]
    cmp ecx, edi
    jge .done                               
    
    mov edi, dword [rel btn_y]
    cmp r8d, edi
    jl .done                            
    add edi, dword [rel btn_h]
    cmp r8d, edi
    jge .done                     ; too far below

    LOG "rematch clicked"


    cmp byte [rel net_role], NET_ROLE_OFFLINE
    je .do_reset

    ; online? it's a rematch then, send a "rematch accepted" packet
    mov cl, 0xBB                  
    mov dl, 0xBB
    xor r8b, r8b

    ; only the server is allowed to generate a seed.
    cmp byte [rel chess960_mode], 1
    jne .send_bb
    cmp byte [rel net_role], NET_ROLE_SERVER
    jne .send_bb
    
    call generate_random_seed
    call generate_chess960_board
    
    mov dl, dil                              
    mov r8w, di
    shr r8w, 8                              
    
.send_bb:
    call send_network_move

    cmp byte [rel rematch_state], 2
    je .do_reset                             ; we accepted, ready to reset

    mov byte [rel rematch_state], 1          ; we offered, wait for opponent
    jmp .done

.do_reset:
    xor byte [rel local_color], 1            
    
    ; offline play - don't communicate seed regeneration over the wire
    cmp byte [rel net_role], NET_ROLE_OFFLINE
    jne .finish_reset
    cmp byte [rel chess960_mode], 1
    jne .finish_reset
    
    call generate_random_seed
    call generate_chess960_board
    
.finish_reset:
    call reset_game                  
    jmp .done                        

    
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
    pop r12 
    pop r11
    pop r10
    pop rdx
    pop rcx
    pop rax
    pop rbp
    ret

; ------------------------------------------------------------------------------
; check_promotion_click
; Inputs: RCX = screen x, RDX = screen y (mouse coordinates)
; Outputs: RAX = 1 if click was intercepted, RAX = 0 if normal board click
; ------------------------------------------------------------------------------
check_promotion_click:
    cmp byte [rel promotion_pending], 1
    jne .not_intercepted

    ; we still need to check the color
    ; in offline play, black is up, white is down
    ; in online play, the player is always up
    movzx rax, byte [rel promotion_sq]
    cmp byte [rel local_color], 1
    jne .no_flip_pclick
    mov rbx, 0x77
    sub rbx, rax
    mov rax, rbx
.no_flip_pclick:

    ; get menu column
    mov r8, rax
    and r8, 0x0F
    
    mov r10d, dword [rel tile_size] 
    imul r8, r10
    add r8d, dword [rel board_x]  ; x of base of the board
    
    ;get the row
    shr rax, 4
    mov r15, rax                     ; R15 = row
    imul rax, r10
    add eax, dword [rel board_y]     
    
    ; check x
    cmp rcx, r8
    jl .not_intercepted ; too far left
    add r8, r10                      
    cmp rcx, r8
    jge .not_intercepted ; too far right
    
    ; check direction and y
    cmp r15, 4                       
    jl .menu_goes_down
    
.menu_goes_up:
    ; this branch is unlikely
    ; it requires a player of opposite color to promote in offline mode
    mov r9, rax                      ; r9 = screen_y
    add r9, r10                      ; r9 = screen_y + tile_size
    dec r9                           ; r9 = screen_y + tile_size - 1 (bottom row of the tile)
    sub r9, rdx                      ; r9 = (mouse_y - bottom_of_tile_y)
    
    ; tile index should be 0, 1, 2 or 3
    cmp r9, 0
    jl .not_intercepted
    mov r11, r10
    imul r11, 4
    cmp r9, r11
    jge .not_intercepted
    
    mov rax, r9
    xor rdx, rdx                 
    div r10
    jmp .execute

.menu_goes_down:
    ; goin' down now
    mov r9, rdx                      ; r9 = mouse_y
    sub r9, rax                      ; r9 = mouse_y - screen_y

    ; same border logic, but mirrored
    cmp r9, 0
    jl .not_intercepted
    mov r11, r10
    imul r11, 4
    cmp r9, r11
    jge .not_intercepted
    
    mov rax, r9
    xor rdx, rdx                 
    div r10                          
    
.execute:
    call resolve_promotion
    mov rax, 1                       ; that's a menu click
    ret

.not_intercepted:
    xor rax, rax                     ; nope
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
    sub rsp, 32  

    cmp qword [rel mouse_ptr], 0
    jne .skip_rescan

    rdtsc
    shr eax, 27
    cmp al, byte [rel init_count]
    je .skip_rescan 

    mov byte [rel init_count], al
    call rescan_devices

.skip_rescan:
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

    test rcx, rcx
    jz .check_draw 

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
    add rsp, 32
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