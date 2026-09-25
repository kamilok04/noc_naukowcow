; -----------------------------------------------
; make_move
; Executes a chess move independently of the UI
; Promotion handling not included, as it's strictly tied to the UI
; Inputs:
; RDX: destination
; R8: target
; Outputs:
; the raw board state
; ------------------------------------------------
make_move:
    push rbp
    mov rbp, rsp
    push rax
    push rbx
    push rcx
    push rdx
    push r8
    push r9
    push r10
    push r11
    push rdi
    push rsi

    ; move the piece

    lea rbx, [rel board]
    mov cl, byte [rbx + rdx]
    mov r10b, byte [rbx + r8]       ; r10b: target square's piece
    mov byte [rbx + r8], cl
    
    ; clear the square the piece just left
    mov byte [rbx + rdx], EMPTY


.castling_and_rights:                     
    cmp cl, W_KING
    je .handle_white_king
    cmp cl, B_KING
    je .handle_black_king
    
    ; not a king
    jmp .check_rook_violations       

.handle_white_king:
    cmp r8b, byte [rel WRh_start]    
    jne .check_wq
    cmp byte [rel w_castle_k], 1    
    je .wk_kingside
.check_wq:
    cmp r8b, byte [rel WRa_start]    
    jne .revoke_all_rights_w
    cmp byte [rel w_castle_q], 1    
    je .wk_queenside
    jmp .revoke_all_rights_w

.wk_kingside:
    movzx r9, byte [rel WRh_start]
    mov byte [rbx + r9], EMPTY       ; clear WRh starting square
    mov byte [rbx + 0x75], W_ROOK    ; WRh -> F1
    mov byte [rbx + 0x76], W_KING    ; WK -> G1 (Chess960 edge case)
    jmp .revoke_all_rights_w

.wk_queenside:
    movzx r9, byte [rel WRa_start]
    mov byte [rbx + r9], EMPTY
    mov byte [rbx + 0x73], W_ROOK    ; WRa -> D1
    mov byte [rbx + 0x72], W_KING    ; WK -> C1
    jmp .revoke_all_rights_w

.revoke_all_rights_w:
    mov byte [rel w_castle_k], 0
    mov byte [rel w_castle_q], 0
    jmp .is_capture

.handle_black_king:
    cmp r8b, byte [rel BRh_start]   ; BK -> BRh?
    jne .check_bq
    cmp byte [rel b_castle_k], 1 
    je .bk_kingside
.check_bq:
    cmp r8b, byte [rel BRa_start]   ; BK -> BRa?
    jne .revoke_all_rights_b
    cmp byte [rel b_castle_q], 1 
    je .bk_queenside
    jmp .revoke_all_rights_w

.bk_kingside:
    movzx r9, byte [rel BRh_start]
    mov byte [rbx + r9], EMPTY
    mov byte [rbx + 0x05], B_ROOK    ; BRh -> F8
    mov byte [rbx + 0x06], B_KING    ; BK -> G8
    jmp .revoke_all_rights_b

.bk_queenside:
    movzx r9, byte [rel BRa_start]
    mov byte [rbx + r9], EMPTY
    mov byte [rbx + 0x03], B_ROOK    ; BRa -> D8
    mov byte [rbx + 0x02], B_KING    ; BK -> C8
    jmp .revoke_all_rights_b

.revoke_all_rights_b:
    mov byte [rel b_castle_k], 0
    mov byte [rel b_castle_q], 0
    jmp .is_capture

.check_rook_violations:

    ; check for rights violations
    ; 12 possible castling-right-voiding scenarios:
    ; - WK/BK moves
    ; - WRa/BRa moves
    ; - WRh/BRh moves
    ; - any of the 4 rooks is captured
    ; - B/W already castled

    ; there are also temporary blocks:
    ; - path occupied
    ; - path under attack
    ; - currently in check

    cmp dl, byte [rel WRa_start]     ; did WRa move?
    je .revoke_WQ
    cmp r8b, byte [rel WRa_start]    ; was WRa captured?
    je .revoke_WQ
    jmp .check_WRh

.revoke_WQ:
    mov byte [rel w_castle_q], 0

.check_WRh:
    cmp dl, byte [rel WRh_start]
    je .revoke_WK
    cmp r8b, byte [rel WRh_start]
    je .revoke_WK
    jmp .check_BRa

.revoke_WK:
    mov byte [rel w_castle_k], 0

.check_BRa:
    cmp dl, byte [rel BRa_start]
    je .revoke_BQ
    cmp r8b, byte [rel BRa_start]
    je .revoke_BQ
    jmp .check_BRh

.revoke_BQ:
    mov byte [rel b_castle_q], 0

.check_BRh:
    cmp dl, byte [rel BRh_start]
    je .revoke_BK
    cmp r8b, byte [rel BRh_start]
    je .revoke_BK
    jmp .is_capture

.revoke_BK:
    mov byte [rel b_castle_k], 0
    jmp .is_capture

    
.is_capture:
    cmp r10b, 12
    jg .invalid_capture
    jmp .capture_check_done
.invalid_capture:
    LOG "An invalid capture of piece ID %d was attempted.", r10
    jmp .done

.capture_check_done:

    ; if the move was EP, clear the EP target
    ; EP happens when:
    ; 1. EP target is not null
    ; 2. a pawn capture just occurred
    ; 3. moved pawn is now directly in front/back of the EP_target (color-relative)
    ; 3. holds because a double push must skip an empty square
.ep_check:
    cmp byte [rel en_passant_target], 0xff
    je .ep_check_done

    cmp r8b, byte [rel en_passant_target]
    jne .ep_check_done

    cmp cl, W_PAWN
    je .white_is_ep
    cmp cl, B_PAWN
    je .black_is_ep
    jmp .ep_check_done

.white_is_ep:
    ; white pawn moving up
    ; the captured black pawn is 0x10 below the target.
    movzx r9, r8b
    add r9, 0x10
    mov byte [rbx + r9], EMPTY
    jmp .ep_check_done

.black_is_ep:
    ; black pawn moving down
    ; the captured white pawn is 0x10 above the target.
    movzx r9, r8b
    sub r9, 0x10
    mov byte [rbx + r9], EMPTY
.ep_check_done:    
    ; only a double push can set the EP
    cmp cl, W_PAWN
    je .check_white_double_push
    cmp cl, B_PAWN
    je .check_black_double_push
    jmp .clear_ep                    ; any non-pawn move MUST clear the EP target

.check_white_double_push:
    mov rax, r8                      ; copy target square
    add rax, 0x20
    cmp rax, rdx                     ; target + 0x20 == source?
    jne .clear_ep                    ; if not, clear the EP
    
    mov rax, r8
    add rax, 0x10
    mov byte [rel en_passant_target], al
    jmp .done         ; don't clear EP target, is was just set

.check_black_double_push:
    mov rax, r8
    sub rax, 0x20
    cmp rax, rdx                     ; target - 0x20 == source?
    jne .clear_ep
    
    mov rax, r8
    sub rax, 0x10
    mov byte [rel en_passant_target], al
    jmp .done       

.clear_ep:
    mov byte [rel en_passant_target], 0xFF 

.done:
    pop rsi
    pop rdi
    pop r11
    pop r10
    pop r9
    pop r8
    pop rdx
    pop rcx
    pop rbx 
    pop rax
    mov rsp, rbp
    pop rbp
    ret