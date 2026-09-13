; ------------------------------------------------------------------------------
; check_san_ambiguity
; Inputs: 
;   DL  = origin square
;   R8B = destination square
;   CL  = piece ID
; Outputs: 
;   san_ambig_file and san_ambig_rank are set (0 or 1)
; ------------------------------------------------------------------------------
check_san_ambiguity:
    push rbp
    mov rbp, rsp
    push rax
    push rbx
    push rdi
    push rsi
    push r12


    mov byte [rel san_ambig_file], 0
    mov byte [rel san_ambig_rank], 0

    ; king and pawns don't need additional disambiguation*

    ; *while there exist scenarios with ambiguous pawn placements,
    ; they are not relevant, as pawn disambiguation is obligatory
    ; You must report a pawn capture as (e. g. ) exd5, regardless
    ; of whatever a pawn is present on the c-file.

    mov al, cl
    cmp al, W_KING
    je .done
    cmp al, B_KING
    je .done
    cmp al, W_PAWN
    je .done
    cmp al, B_PAWN
    je .done

    ; copy the valid moves list
    mov al, byte [rel valid_moves_count]
    mov byte [rel backup_moves_count], al
    mov al, byte [rel selected_square]
    mov byte [rel backup_selected], al
    
    mov rcx, 128
    lea rsi, [rel valid_moves_list]
    lea rdi, [rel backup_moves_list]
    rep movsb

    ; check if anything else can reach the square
    xor r12, r12
.sweep_loop:
    cmp r12, 0x78
    jge .restore_and_done
    test r12, 0x88
    jnz .next_square

    cmp r12b, dl                 ; is this the original piece?
    je .next_square              ; yes, skip then

    lea rbx, [rel board]
    mov al, byte [rbx + r12]     ; there's a piece here
    cmp al, cl                   ; is it the same kind of piece
    jne .next_square             ; no, skip

    ; yes; is it legally allowed to reach the target?

    ; note: this is not guaranteed, as another piece of the same type
    ; may be pinned -- in this case SAN does not require disambiguation
    ; as there is none to begin with.

    mov byte [rel selected_square], r12b
    call generate_moves_for_square
    
    movzx rax, byte [rel valid_moves_count]
    test rax, rax
    jz .next_square              ; the candidate alternative source is not allowed to reach the target for any reason
    
    lea rsi, [rel valid_moves_list]
.check_rival_target:
    cmp byte [rsi + rax - 1], r8b
    je .ambiguity_found          ; the alternative source may hit the target too
    dec rax
    jnz .check_rival_target
    jmp .next_square

.ambiguity_found:
    ; there is an overlap in avialable sources, how large?
    mov al, dl                   ; AL = original source square
    mov bl, r12b                 ; BL = alternative source square
    
    ; file (column) overlap
    mov ah, al
    and ah, 7
    mov bh, bl
    and bh, 7
    cmp ah, bh
    jne .flag_file
    
    ; yes, use rank disambiguation
    mov byte [rel san_ambig_rank], 1
    jmp .next_square
    
.flag_file:
    ; same file, use file disamb.
    mov byte [rel san_ambig_file], 1

.next_square:
    inc r12
    jmp .sweep_loop

.restore_and_done:
    ; restore the moves list for future use
    mov al, byte [rel backup_moves_count]
    mov byte [rel valid_moves_count], al
    mov al, byte [rel backup_selected]
    mov byte [rel selected_square], al
    
    mov rcx, 128
    lea rsi, [rel backup_moves_list]
    lea rdi, [rel valid_moves_list]
    rep movsb

.done:
    pop r12
    pop rsi
    pop rdi
    pop rbx
    pop rax
    mov rsp, rbp
    pop rbp
    ret

; ------------------------------------------------------------------------------
; build_san_string
; Creates a SAN half-move notation string based on the move info
; Inputs: DL = Origin, R8B = Destination, CL = Piece ID, R10B = Target Piece
; ------------------------------------------------------------------------------
build_san_string:
    push rbp
    mov rbp, rsp
    push rax
    push rbx
    push rdi

    ; fill the buffer with '       \0'
    mov rax, 0x0020202020202020      
    mov qword [rel san_temp_str], rax
    lea rdi, [rel san_temp_str]      ; RDI = string pointer

    ; process castling first
    mov al, cl
    cmp al, W_KING
    je .check_w_castle
    cmp al, B_KING
    je .check_b_castle
    jmp .not_castling
    
.check_w_castle:
    cmp r8b, 0x76                    ; WK -> G1?
    je .write_o_o
    cmp r8b, 0x72                    ; WK -> C1?
    je .write_o_o_o
    jmp .not_castling
    
.check_b_castle:
    cmp r8b, 0x06                    ; BK -> G8?
    je .write_o_o
    cmp r8b, 0x02                    ; BK -> C8?
    je .write_o_o_o
    jmp .not_castling

.write_o_o:
    mov dword [rdi], 0x204F2D4F      ; "O-O "
    add rdi, 3
    jmp .finalize_string
.write_o_o_o:
    mov dword [rdi], 0x2D4F2D4F      ; "O-O-"
    mov word [rdi+4], 0x204F         ; "O "
    add rdi, 5
    jmp .finalize_string

.not_castling:
    ; write the piece letter
    lea rbx, [rel san_letters]  ; use the lookup table
    movzx rax, cl
    mov al, byte [rbx + rax]         
    cmp al, 0x20                ; pawns are blanks anyway, skip
    je .pawn_logic
    mov byte [rdi], al               
    inc rdi

    ; attach disambiguation if necessary
    cmp byte [rel san_ambig_file], 1
    jne .check_rank_ambig
    mov al, dl
    and al, 7                        ; get rank 0-7
    add al, 'a'                      ; get rank (a-h)
    mov byte [rdi], al
    inc rdi
    
.check_rank_ambig:
    cmp byte [rel san_ambig_rank], 1
    jne .check_capture
    mov al, dl
    shr al, 4                        ; get row 0-7
    mov bl, 8
    sub bl, al                       ; [0, 7] -> [1, 8]
    add bl, '0'                      ; convert to char
    mov byte [rdi], bl
    inc rdi
    jmp .check_capture

.pawn_logic:
    ; pawns are handled separately because en passant
    ; it's a capture where the target square is empty, as as such, not detected by usual logic.
    ; make a simpler assumption: if target file != source file, a capture must have occurred
    ; SAN does not require denoting e.p. separately (allowed, but not required)

    mov al, dl
    and al, 7                        ; origin file
    mov bl, r8b
    and bl, 7                        ; target file
    cmp al, bl
    je .write_destination            ; same file -> no capture, straight push
    
    ; different files = always a capture
    add al, 'a'                      
    mov byte [rdi], al
    inc rdi
    mov byte [rdi], 'x'             
    inc rdi
    jmp .write_destination

.check_capture:
    test r10b, r10b
    jz .write_destination
    mov byte [rdi], 'x'
    inc rdi

.write_destination:
    ; file ('a'-'h')
    mov al, r8b
    and al, 7
    add al, 'a'
    mov byte [rdi], al
    inc rdi
    ; rank ('1'-'8')
    mov al, r8b
    shr al, 4
    mov bl, 8
    sub bl, al
    add bl, '0'
    mov byte [rdi], bl
    inc rdi

.finalize_string:
    ; most of the string is done
    
    ; most?
    ; post-move evalutations (+, #, =) must be appended later,
    ; after the game status is evaluated
    
    pop rdi
    pop rbx
    pop rax
    mov rsp, rbp
    pop rbp
    ret

; ------------------------------------------------------------------------------
; save_san_to_buffer
; Appends the contents of san_temp_str to the main transcript buffer.
; ------------------------------------------------------------------------------
save_san_to_buffer:
    push rbp
    mov rbp, rsp
    push rax
    push rcx
    push rdi
    push rsi

    movzx rax, word [rel transcript_count]
    shl rax, 3                       ; multiply by 8 bytes
    lea rdi, [rel transcript_buffer]
    add rdi, rax                     ; RDI = target slot
    
    lea rsi, [rel san_temp_str]
    mov rcx, 8                       ; copy exactly 8 bytes
    rep movsb
    
    inc word [rel transcript_count]  ; increment half-move counter

    pop rsi
    pop rdi
    pop rcx
    pop rax
    mov rsp, rbp
    pop rbp
    ret

; ------------------------------------------------------------------------------
; append_san_evaluations
; Appends promotion (=Q), check (+), or mate (#) to the temp string.
; ------------------------------------------------------------------------------
append_san_evaluations:
    push rbp
    mov rbp, rsp
    push rax
    push rbx
    push rcx
    push rdi

    ; rewind to a first empty space (it's guaranteed to be present)
    lea rdi, [rel san_temp_str]
    mov rcx, 7
.find_space:
    cmp byte [rdi], 0x20
    je .found
    inc rdi
    loop .find_space
.found:

    ; append a promotion, if any
    mov al, byte [rel last_local_move + MOVE_PAYLOAD.Promotion]
    test al, al
    jz .check_mate
    mov byte [rdi], '='
    inc rdi
    lea rbx, [rel san_letters]
    movzx rax, al
    mov al, byte [rbx + rax]
    mov byte [rdi], al
    inc rdi

.check_mate:
    
    cmp byte [rel match_state], 0
    je .check_check
    cmp byte [rel match_state], 3  ; draw?
    je .stalemate

    mov byte [rdi], '#'
    jmp .done_eval

.stalemate:
    mov byte[rdi], '='
    jmp .done_eval

.check_check:
    cmp byte [rel is_in_check], 0
    jne .done_eval
    mov byte [rdi], '+'

.done_eval:
    pop rdi
    pop rcx
    pop rbx
    pop rax
    mov rsp, rbp
    pop rbp
    ret