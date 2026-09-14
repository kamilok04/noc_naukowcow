; ------------------------------------------------------------------------------
; update_match_state
; Evaluates if the current player has any valid moves left.
; Ends the game.
; ------------------------------------------------------------------------------
update_match_state:
    ; LOG "Checking game state..."
    push rbx
    push rcx
    push rdx
    push r8

    ; copy the board before making the move
    ; both boards need to be synced - for move detection and for SAN
    lea rsi, [rel board]
    lea rdi, [rel sandbox_board]
    mov rcx, 128                     ; 0x88 board is 128 bytes
    rep movsb

    
    mov rbx, 0                       ; iterate over the board

.scan_loop:
    test rbx, 0x88                   ; is it a valid square?
    jne .next_square
    ; empty?
    lea rcx, [rel board]
    mov dl, byte [rcx + rbx]
    test dl, dl
    jz .next_square
    
    ; of current player?
    mov al, byte [rel current_color]
    test al, al
    jnz .check_black_piece
    
.check_white_piece:
    cmp dl, 7
    jge .next_square                 ; skip black pieces
    jmp .test_moves
    
.check_black_piece:
    cmp dl, 7
    jl .next_square                  ; skip white pieces

.test_moves:
    ; the idea is simple:
    ; we can check every piece the player has
    ; if any legal move is present, continue
    ; if not, check if the king is attacked:
    ; if it is: mate, the player lost
    ; if not: stalemate
    mov byte [rel selected_square], bl
    mov r8, rbx
    call generate_moves_for_square
    ; any valid moves?
    cmp byte [rel valid_moves_count], 0
    jg .game_active                  ; yes; carry on
    ;  "No valid moves for sq. %x", rbx
.next_square:
    inc rbx
    cmp rbx, 0x80
    jl .scan_loop

    ; fallthrough: none of the player's pieces has a legal move

    ; is the king attacked?
    call verify_king_safety ; 1 = safe
    test rax, rax
    jnz .is_stalemate
    

    ; mate! The other colour wins.
    LOG "Mate!"
    movzx rax, byte[rel match_state]
    mov al, byte [rel current_color]
    xor al, 1
    add al, 1                        ; 1 = white, 2 = black
    mov byte [rel match_state], al
    jmp .cleanup

.is_stalemate:
    LOG "Stalemate!"
    mov byte [rel match_state], 3
    jmp .cleanup

.game_active:
    mov byte [rel match_state], 0
    ; Clear the generator so that the next game/next move works from a clean state
    mov byte [rel selected_square], 0xFF
    mov byte [rel valid_moves_count], 0

    ; the move has been made, sync the boards
    ; otherwise SAN would be one move behind
    lea rsi, [rel board]
    lea rdi, [rel sandbox_board]
    mov rcx, 128                     ; 0x88 board is 128 bytes
    rep movsb

    

    call verify_king_safety
    mov byte [rel is_in_check], al ; 1 -> check
    jmp .exit_update
    ; LOG "Game on."

.cleanup:
    ; only used on game conclusion
    mov byte [rel selected_square], 0xFF
    mov byte [rel valid_moves_count], 0

.exit_update:
    pop r8
    pop rdx
    pop rcx
    pop rbx
    ret