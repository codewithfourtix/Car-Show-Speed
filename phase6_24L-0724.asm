[org 0x0100]
mov ax, 3508h
int 21h
mov word [old_isr], bx
mov word [old_isr+2], es
jmp start
; ==========================================================
; === MULTITASKING MUSIC KERNEL (INTERRUPT HANDLER) ===
; ==========================================================
; Variable to store the original BIOS timer interrupt address
old_isr: dd 0
; Timer logic variables
music_tick_count: dw 0 ; Counts down ticks until next note
note_index: dw 0 ; Current position in the song
current_music: dw music_menu
; Music Data: [Frequency (Hz), Duration (ticks)]
; 0 = Silence/Rest
; -1 = End of Song (Loop)
music_menu:
    dw 523, 3 ; C5
    dw 392, 3 ; G4
    dw 330, 3 ; E4
    dw 440, 3 ; A4
    dw 494, 3 ; B4
    dw 440, 3 ; A4
    dw 392, 6 ; G4
    dw 0, 2 ; Rest
    dw 523, 3 ; C5
    dw 392, 3 ; G4
    dw 330, 3 ; E4
    dw 440, 3 ; A4
    dw 494, 3 ; B4
    dw 440, 3 ; A4
    dw 392, 6 ; G4
    dw 0, 6 ; Rest
    dw -1, -1 ; Loop
music_game:
    dw 440, 2 ; A4
    dw 494, 2 ; B4
    dw 523, 2 ; C5
    dw 587, 2 ; D5
    dw 659, 2 ; E5
    dw 698, 2 ; F5
    dw 784, 2 ; G5
    dw 880, 2 ; A5
    dw 0, 2 ; Rest
    dw 880, 2 ; A5
    dw 784, 2 ; G5
    dw 698, 2 ; F5
    dw 659, 2 ; E5
    dw 587, 2 ; D5
    dw 523, 2 ; C5
    dw 494, 2 ; B4
    dw 440, 2 ; A4
    dw 0, 2 ; Rest
    dw -1, -1 ; Loop
; ------------------------------------------------------------------
; ISR: Interrupt Service Routine (Background Process)
; This runs automatically every 55ms
; ------------------------------------------------------------------
timer_isr:
    pusha ; Save all general registers
    push ds ; Save Data Segment
    push es ; Save Extra Segment
    mov ax, cs ; Ensure DS points to our code/data
    mov ds, ax
    ; --- 1. Decrement Duration Counter ---
    cmp word [music_tick_count], 0
    jg dec_timer ; If > 0, just decrement and exit
    jmp load_next_note ; If <= 0, time to change note
dec_timer:
    dec word [music_tick_count]
    jmp chain_interrupt
load_next_note:
    ; --- 2. Load Note from Array ---
    mov si, [note_index]
    mov bx, [current_music]
    mov ax, [bx + si] ; Read Frequency
    cmp ax, -1 ; Check for Loop Terminator
    je reset_song
    mov cx, [bx + si + 2] ; Read Duration
    mov [music_tick_count], cx
    add word [note_index], 4 ; Advance index (2 bytes freq + 2 bytes dur)
    ; --- 3. Check for Silence ---
    cmp ax, 0
    je silence_speaker
    ; --- 4. Play Sound (PIT Hardware Manipulation) ---
    ; Frequency Divisor = 1193180 / Frequency
    mov dx, 0x0012
    mov ax, 0x34DC ; DX:AX = 1,193,180
    mov cx, [bx + si] ; Get Frequency again
    div cx ; AX = Divisor result
    mov bx, ax ; Save divisor in BX
    ; Send Command to PIT (Port 43h)
    mov al, 0xB6 ; Channel 2, LSB+MSB, Square Wave
    out 0x43, al
    ; Send Frequency Divisor to PIT (Port 42h)
    mov ax, bx
    out 0x42, al ; Send Low Byte
    mov al, ah
    out 0x42, al ; Send High Byte
    ; Enable Speaker (Port 61h)
    in al, 0x61
    or al, 00000011b ; Set bits 0 and 1 (Gate + Data)
    out 0x61, al
    jmp chain_interrupt
silence_speaker:
    in al, 0x61
    and al, 11111100b ; Clear bits 0 and 1
    out 0x61, al
    jmp chain_interrupt
reset_song:
    mov word [note_index], 0 ; Reset index to 0
    mov word [music_tick_count], 1 ; Trigger load immediately
    jmp chain_interrupt
chain_interrupt:
    pop es ; Restore segments
    pop ds
    popa ; Restore registers
    ; IMPORTANT: Jump to original BIOS handler
    ; This allows Int 1Ah (Timer Tick) to keep working for the game speed
    jmp far [cs:old_isr]
; ------------------------------------------------------------------
; SETUP: Hook the Interrupt
; ------------------------------------------------------------------
hook_timer:
    push ax
    push bx
    push ds
    mov dx, timer_isr ; Offset of our ISR
    mov ax, cs
    mov ds, ax
    mov ax, 0x2508 ; Set Interrupt Vector
    int 0x21
    pop ds
    pop bx
    pop ax
    ret
; ------------------------------------------------------------------
; CLEANUP: Restore the Interrupt
; ------------------------------------------------------------------
unhook_timer:
    push ax
    push dx
    push ds
    ; Turn off speaker immediately
    in al, 0x61
    and al, 11111100b
    out 0x61, al
    ; Restore original vector
    mov dx, [old_isr]
    mov ds, [old_isr+2]
    mov ax, 0x2508
    int 0x21
    pop ds
    pop dx
    pop ax
    ret
; ============ MENU SYSTEM ============
draw_background:
    push ax
    push bx
    push cx
    push dx
    push di
    push si
    ; 1. Fill screen with green grass
    mov ax,0xb800
    mov es,ax
    mov di,0
    mov cx,2000
    mov ax,0x2020 ; green solid
    rep stosw
    ; ============ STATIC TREE PLANTING ============
    ; --- ZONE 1: TOP FOREST (Row 4) ---
    ; Trees sit on row 4 (foliage goes up to row 0)
    mov cx, 12 ; Draw 12 trees across the top
    mov dx, 2 ; Start at column 2
top_forest_loop:
    push 4 ; Row 4
    push dx ; Column
    call make_tree
    add dx, 7 ; Move 7 spaces right
    loop top_forest_loop
    ; --- ZONE 2: BOTTOM FOREST (Rows 21 & 24) ---
    ; Row 21
    mov cx, 12
    mov dx, 4 ; Start offset
bot_forest_1:
    push 21
    push dx
    call make_tree
    add dx, 7
    loop bot_forest_1
    ; Row 24 (The very bottom edge)
    mov cx, 12
    mov dx, 2
bot_forest_2:
    push 24
    push dx
    call make_tree
    add dx, 7
    loop bot_forest_2
    ; --- ZONE 3: LEFT FLANK (Rows 9, 13, 17) ---
    ; We draw two columns of trees on the left side
    ; Row 9
    push 9 ; Row
    push 3 ; Col
    call make_tree
    push 9
    push 10
    call make_tree
    ; Row 13
    push 13
    push 5 ; Staggered
    call make_tree
    push 13
    push 12
    call make_tree
    ; Row 17
    push 17
    push 3
    call make_tree
    push 17
    push 10
    call make_tree
    ; --- ZONE 4: RIGHT FLANK (Rows 9, 13, 17) ---
    ; We draw two columns of trees on the right side
    ; Row 9
    push 9
    push 70
    call make_tree
    push 9
    push 77
    call make_tree
    ; Row 13
    push 13
    push 68 ; Staggered
    call make_tree
    push 13
    push 75
    call make_tree
    ; Row 17
    push 17
    push 70
    call make_tree
    push 17
    push 77
    call make_tree
    ; ============ DRAW THE MENU BOX (Unchanged) ============
box_top equ 5
box_bottom equ 19
box_left equ 15
box_right equ 65
    ; Draw top border
    mov bl,box_top
    mov al,80
    mul bl
    add ax,box_left
    shl ax,1
    mov di,ax
    mov cx, box_right - box_left +1
    mov ax,0x66DB ; brown solid
    rep stosw
    ; Draw bottom border
    mov bl,box_bottom
    mov al,80
    mul bl
    add ax,box_left
    shl ax,1
    mov di,ax
    mov cx, box_right - box_left +1
    mov ax,0x66DB
    rep stosw
    ; Draw left border
    mov cx, box_bottom - box_top -1
    mov bl,box_top +1
left_border_loop:
    mov al,80
    mul bl
    add ax,box_left
    shl ax,1
    mov di,ax
    mov word [es:di],0x66DB
    inc bl
    loop left_border_loop
    ; Draw right border
    mov cx, box_bottom - box_top -1
    mov bl,box_top +1
right_border_loop:
    mov al,80
    mul bl
    add ax,box_right
    shl ax,1
    mov di,ax
    mov word [es:di],0x66DB
    inc bl
    loop right_border_loop
    ; Clear inside the box to black
    mov cx, box_bottom - box_top -1
    mov bl,box_top +1
clear_inner_loop:
    mov al,80
    mul bl
    add ax,box_left +1
    shl ax,1
    mov di,ax
    push cx
    mov cx, box_right - box_left -1
    mov ax,0x0020 ; black space
    rep stosw
    pop cx
    inc bl
    loop clear_inner_loop
    pop si
    pop di
    pop dx
    pop cx
    pop bx
    pop ax
    ret
draw_menu:
    push ax
    push bx
    push cx
    push dx
    push di
    push si
    call draw_background
    ; Draw simple title
    mov di, (box_top +1) *160 + box_left*2
    mov si,title_text
    mov cx,14
    mov ah,0xCE
    call draw_centered_in_box
    ; Draw options inside the box
    mov di, (box_top +4) *160 + box_left*2
    mov si,play_text
    mov cx,20
    mov ah,0x2F
    call draw_centered_in_box
    mov di, (box_top +6) *160 + box_left*2
    mov si,instructions_text
    mov cx,24
    mov ah,0x1F
    call draw_centered_in_box
    mov di, (box_top +8) *160 + box_left*2
    mov si,credits_text
    mov cx,19
    mov ah,0x6F ; white on brown
    call draw_centered_in_box
    mov di, (box_top +10) *160 + box_left*2
    mov si,quit_text
    mov cx,15
    mov ah,0x4F
    call draw_centered_in_box
    pop si
    pop di
    pop dx
    pop cx
    pop bx
    pop ax
    ret
show_instructions:
    push ax
    push bx
    push cx
    push dx
    push di
    push si
    call draw_background
    ; Draw title
    mov di,(box_top +1) *160 + box_left*2
    mov si,instructions_title
    mov cx,17
    mov ah,0x9E ; yellow on blue
    call draw_centered_in_box
    ; Draw instructions
    mov di,(box_top +3) *160 + box_left*2
    mov si,instr1
    mov cx,37
    mov ah,0x0F ; white on black
    call draw_centered_in_box
    mov di,(box_top +4) *160 + box_left*2
    mov si,instr2
    mov cx,31
    mov ah,0x0F
    call draw_centered_in_box
    mov di,(box_top +5) *160 + box_left*2
    mov si,instr3
    mov cx,30
    mov ah,0x0F
    call draw_centered_in_box
    mov di,(box_top +6) *160 + box_left*2
    mov si,instr4
    mov cx,29
    mov ah,0x0F
    call draw_centered_in_box
    mov di,(box_top +7) *160 + box_left*2
    mov si,instr5
    mov cx,27
    mov ah,0x0F
    call draw_centered_in_box
    ; Draw return prompt
    mov di,(box_bottom -3) *160 + box_left*2
    mov si,return_text
    mov cx,28
    mov ah,0x2F ; white on green
    call draw_centered_in_box
instr_wait:
    mov ah,0
    int 0x16 ; wait for key
    cmp al,0x1B ; ESC key
    je instr_exit
    cmp al,'m'
    je instr_exit
    cmp al,'M'
    je instr_exit
    jmp instr_wait
instr_exit:
    pop si
    pop di
    pop dx
    pop cx
    pop bx
    pop ax
    ret
show_credits:
    push ax
    push bx
    push cx
    push dx
    push di
    push si
    call draw_background
    ; Draw title
    mov di,(box_top +1) *160 + box_left*2
    mov si,credits_title
    mov cx,7
    mov ah,0x9E
    call draw_centered_in_box
    ; Draw names
    mov di,(box_top +3) *160 + box_left*2
    mov si,name1
    mov cx,22
    mov ah,0x0F
    call draw_centered_in_box
    mov di,(box_top +4) *160 + box_left*2
    mov si,name2
    mov cx,19
    mov ah,0x0F
    call draw_centered_in_box
    ; Draw return prompt
    mov di,(box_bottom -3) *160 + box_left*2
    mov si,return_text
    mov cx,28
    mov ah,0x2F
    call draw_centered_in_box
credits_wait:
    mov ah,0
    int 0x16
    cmp al,0x1B
    je credits_exit
    cmp al,'m'
    je credits_exit
    cmp al,'M'
    je credits_exit
    jmp credits_wait
credits_exit:
    pop si
    pop di
    pop dx
    pop cx
    pop bx
    pop ax
    ret
draw_centered_in_box:
    push ax
    push bx
    push cx
    push dx
    push di
    ; si = text
    ; cx = text length
    ; ah = attribute
    ; di = start of box-left
    ; compute correct box width = box_right - box_left + 1
    mov bx, box_right - box_left + 1 ; 51 chars
    sub bx, cx ; free chars
    shr bx, 1 ; half -> left padding
    shl bx, 1 ; convert chars -> bytes
    add di, bx ; shift inside box
text_draw_loop:
    lodsb
    stosw
    loop text_draw_loop
    pop di
    pop dx
    pop cx
    pop bx
    pop ax
    ret
menu_input:
    push ax
    push bx
menu_wait:
    mov ah,0
    int 0x16 ; wait for key press
    cmp al,'p'
    je go_to_player_info
    cmp al,'P'
    je go_to_player_info
    cmp al,'i'
    je show_instr
    cmp al,'I'
    je show_instr
    cmp al,'c'
    je show_cred
    cmp al,'C'
    je show_cred
    cmp al,'q'
    je quit_game
    cmp al,'Q'
    je quit_game
    jmp menu_wait
show_instr:
    call show_instructions
    call draw_menu
    jmp menu_wait
show_cred:
    call show_credits
    call draw_menu
    jmp menu_wait
go_to_player_info:
    call get_player_info
    jmp start_game
start_game:
    mov word [current_music], music_game
    mov word [note_index], 0
    mov word [music_tick_count], 1
    pop bx
    pop ax
    ret
quit_game:
    call unhook_timer ; <--- IMPORTANT: STOP MUSIC BEFORE EXIT
    mov ax,0x4c00
    int 0x21
set_scr:
    push bp
    mov bp,sp
    push ax
    push bx
    push cx
    push dx
    push di
    push si
    mov ax,0xb800
    mov es,ax
    mov di,0
    ; make the screen deserted
    ; fill entire screen black
color_the_screen:
mov word[es:di],0x0020 ; black space
add di,2
cmp di,4000
jne color_the_screen
; overlay grass only in cols 0-59
mov dx,0 ; row 0-24
grass_outer:
mov al,80
mul dl
add ax,0 ; start col 0
shl ax,1
mov di,ax
mov cx,60 ; 60 cols
grass_inner:
mov word[es:di],0x2020 ; solid green
add di,2
loop grass_inner
inc dl
cmp dl,25
jne grass_outer
;now draw black road
    mov cx,[bp+4]
    mov dx,[bp+8]
    jmp make_road
;making the formula for index
    set_fromula:
    mov al,80
    mov bl,dl ; current row
    mul bl
    add ax,[bp+6] ; add starting column
    shl ax,1
    ret
;making road structure
    make_road:
    call set_fromula
    push cx
    mov di,ax
    mov cx,33 ;num of blocks
    set_road_bg:
    mov word[es:di],0x08DB ; grey solid
    add di,2
    loop set_road_bg
    pop cx
    inc dx
    loop make_road
    mov dx,[bp+8] ;reset the value of dx to point to the first row
mov cx,[bp+4]
    push bx
    mov bx,0 ; dash counter
set_left_lane:
    ;making the formula
    mov al,80
    mul dl
    add ax,[bp + 6]
    add ax,11
shl ax,1
;now making the lanes
mov di,ax
cmp bx,4
jb draw_left
mov word[es:di],0x08DB ; gap
jmp next_left
draw_left:
mov word[es:di],0x0EB3 ; yellow vertical line
next_left:
inc bx
cmp bx,6
jb no_reset_left
mov bx,0
no_reset_left:
add dl,1
loop set_left_lane
pop bx
mov dx,[bp+8]
mov cx,[bp+4]
    push bx
    mov bx,0 ; dash counter
set_right_lane:
     ;making the formula
    mov al,80
    mul dl
    add ax,[bp + 6]
    add ax,22
shl ax,1
 ;now making the lanes
mov di,ax
cmp bx,4
jb draw_right
mov word[es:di],0x08DB ; gap
jmp next_right
draw_right:
mov word[es:di],0x0EB3 ; yellow vertical line
next_right:
inc bx
cmp bx,6
jb no_reset_right
mov bx,0
no_reset_right:
add dl,1
loop set_right_lane
pop bx
mov dx,[bp+8]
mov cx,[bp+4]
; setting the left side border
set_left_border_lane:
    ;making the formula
    mov al,80
    mul dl
    add ax,[bp + 6]
shl ax,1
;now making the lanes
mov di,ax
mov ax,0x7020 ; white bg space
test dl,1
jz even_left
mov ax,0x4020 ; red bg space
even_left:
mov word[es:di],ax
add dl,1
loop set_left_border_lane
mov dx,[bp+8]
mov cx,[bp+4]
set_right_border_lane:
    ;making the formula
    mov al,80
    mul dl
    add ax,[bp + 6]
add ax,33
shl ax,1
;now making the lanes
mov di,ax
mov ax,0x7020 ; white bg space
test dl,1
jz even_right
mov ax,0x4020 ; red bg space
even_right:
mov word[es:di],ax
add dl,1
loop set_right_border_lane
    pop si
    pop di
    pop dx
    pop cx
    pop bx
    pop ax
    pop bp
    ret 6
make_tree:
    push bp
    mov bp,sp
    push ax
    push bx
    push cx
    push dx
    push di
    mov ax,0xb800
    mov es,ax
    mov bl,[bp+6] ; base row
    mov dx,[bp+4] ; center col
    mov si,bx ; save base
    sub bl,4 ; top row
    ; top foliage: 1 block
    mov al,80
    mul bl
    add ax,dx
    shl ax,1
    mov di,ax
    mov word[es:di],0x2ADB ; bright green solid
    ; next row: 3 blocks
    inc bl
    mov al,80
    mul bl
    add ax,dx
    sub ax,1
    shl ax,1
    mov di,ax
    mov cx,3
fol_loop1:
    mov word[es:di],0x2ADB
    add di,2
    loop fol_loop1
    ; next row: 5 blocks
    inc bl
    mov al,80
    mul bl
    add ax,dx
    sub ax,2
    shl ax,1
    mov di,ax
    mov cx,5
fol_loop2:
    mov word[es:di],0x2ADB
    add di,2
    loop fol_loop2
    ; trunk first
    inc bl
    mov al,80
    mul bl
    add ax,dx
    shl ax,1
    mov di,ax
    mov word[es:di],0x66DB ; brown solid
    ; trunk second
    inc bl
    mov al,80
    mul bl
    add ax,dx
    shl ax,1
    mov di,ax
    mov word[es:di],0x66DB
    pop di
    pop dx
    pop cx
    pop bx
    pop ax
    pop bp
    ret 4
make_Action_Cruiser:
    push bp
    mov bp,sp
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    mov ax,0xb800
    mov es,ax
    mov bl,[bp+6] ; rear row (base)
    mov dx,[bp+4] ; center col
    ; Rear row (bl): body body body body body
    mov al,80
    mul bl
    sub dx,2 ; start col -2
    add ax,dx
    shl ax,1
    mov di,ax
    mov ax,0x0CDB ; red body
    mov cx,5
    rep stosw ; pos-2 to +2
    ; Rear wheels row (bl-1): wheel body body body wheel
    dec bl
    mov al,80
    mul bl
    mov dx,[bp+4]
    sub dx,2
    add ax,dx
    shl ax,1
    mov di,ax
    mov ax,0x0F4F ; white O wheel
    stosw ; pos-2
    mov ax,0x0CDB ; body
    mov cx,3
    rep stosw ; pos-1 to +1
    mov ax,0x0F4F ; wheel
    stosw ; pos+2
    ; Cabin row (bl-2): body window window window body
    dec bl
    mov al,80
    mul bl
    mov dx,[bp+4]
    sub dx,2
    add ax,dx
    shl ax,1
    mov di,ax
    mov ax,0x0CDB ; body (changed from side)
    stosw ; pos-2
    mov ax,0x0BB1 ; cyan ▒ window
    mov cx,3
    rep stosw ; pos-1 to +1
    mov ax,0x0CDB ; body (changed from side)
    stosw ; pos+2
    ; Front wheels row (bl-3): wheel body body body wheel (changed from hood)
    dec bl
    mov al,80
    mul bl
    mov dx,[bp+4]
    sub dx,2
    add ax,dx
    shl ax,1
    mov di,ax
    mov ax,0x0F4F ; wheel
    stosw ; pos-2
    mov ax,0x0CDB ; body
    mov cx,3
    rep stosw ; pos-1 to +1
    mov ax,0x0F4F
    stosw ; pos+2
    ; Front lights row (bl-4): light body body body light (changed, no spaces)
    dec bl
    mov al,80
    mul bl
    mov dx,[bp+4]
    sub dx,2
    add ax,dx
    shl ax,1
    mov di,ax
    mov ax,0x0E2A ; yellow * light
    stosw ; pos-2
    mov ax,0x0CDB ; body
    mov cx,3
    rep stosw ; pos-1 to +1
    mov ax,0x0E2A ; light
    stosw ; pos+2
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    pop bp
    ret 4
clear_Action_Cruiser:
    push bp
    mov bp,sp
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    mov ax,0xb800
    mov es,ax
    mov bl,[bp+6] ; rear row (base)
    mov dx,[bp+4] ; center col
    ; Rear row (bl): body body body body body
    mov al,80
    mul bl
    sub dx,2 ; start col -2
    add ax,dx
    shl ax,1
    mov di,ax
    mov ax,0x08DB ; grey solid
    mov cx,5
    rep stosw ; pos-2 to +2
    ; Rear wheels row (bl-1): wheel body body body wheel
    dec bl
    mov al,80
    mul bl
    mov dx,[bp+4]
    sub dx,2
    add ax,dx
    shl ax,1
    mov di,ax
    mov ax,0x08DB ; grey solid
    stosw ; pos-2
    mov ax,0x08DB ; grey solid
    mov cx,3
    rep stosw ; pos-1 to +1
    mov ax,0x08DB ; grey solid
    stosw ; pos+2
    ; Cabin row (bl-2): body window window window body
    dec bl
    mov al,80
    mul bl
    mov dx,[bp+4]
    sub dx,2
    add ax,dx
    shl ax,1
    mov di,ax
    mov ax,0x08DB ; grey solid
    stosw ; pos-2
    mov ax,0x08DB ; grey solid
    mov cx,3
    rep stosw ; pos-1 to +1
    mov ax,0x08DB ; grey solid
    stosw ; pos+2
    ; Front wheels row (bl-3): wheel body body body wheel (changed from hood)
    dec bl
    mov al,80
    mul bl
    mov dx,[bp+4]
    sub dx,2
    add ax,dx
    shl ax,1
    mov di,ax
    mov ax,0x08DB ; grey solid
    stosw ; pos-2
    mov ax,0x08DB ; grey solid
    mov cx,3
    rep stosw ; pos-1 to +1
    mov ax,0x08DB ; grey solid
    stosw ; pos+2
    ; Front lights row (bl-4): light body body body light (changed, no spaces)
    dec bl
    mov al,80
    mul bl
    mov dx,[bp+4]
    sub dx,2
    add ax,dx
    shl ax,1
    mov di,ax
    mov ax,0x08DB ; grey solid
    stosw ; pos-2
    mov ax,0x08DB ; grey solid
    mov cx,3
    rep stosw ; pos-1 to +1
    mov ax,0x08DB ; grey solid
    stosw ; pos+2
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    pop bp
    ret 4
draw_obstacle_row:
    push bp
    mov bp,sp
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    mov ax,0xb800
    mov es,ax
    mov dx,[bp+4] ; center col
    mov bl,[bp+6] ; phase (0-4)
    cmp bl,0
    jne not_phase0
    ; Phase 0: rear body
    mov ax,dx
    sub ax,2
    shl ax,1
    mov di,ax
    mov ax,0x09DB
    mov cx,5
    rep stosw
    jmp obs_row_done
not_phase0:
    cmp bl,1
    jne not_phase1
    ; Phase 1: rear wheels
    mov ax,dx
    sub ax,2
    shl ax,1
    mov di,ax
    mov ax,0x0F4F
    stosw
    mov ax,0x09DB
    mov cx,3
    rep stosw
    mov ax,0x0F4F
    stosw
    jmp obs_row_done
not_phase1:
    cmp bl,2
    jne not_phase2
    ; Phase 2: cabin
    mov ax,dx
    sub ax,2
    shl ax,1
    mov di,ax
    mov ax,0x09DB
    stosw
    mov ax,0x0FB1
    mov cx,3
    rep stosw
    mov ax,0x09DB
    stosw
    jmp obs_row_done
not_phase2:
    cmp bl,3
    jne not_phase3
    ; Phase 3: front wheels
    mov ax,dx
    sub ax,2
    shl ax,1
    mov di,ax
    mov ax,0x0F4F
    stosw
    mov ax,0x09DB
    mov cx,3
    rep stosw
    mov ax,0x0F4F
    stosw
    jmp obs_row_done
not_phase3:
    ; Phase 4: front lights
    mov ax,dx
    sub ax,2
    shl ax,1
    mov di,ax
    mov ax,0x0E2A
    stosw
    mov ax,0x09DB
    mov cx,3
    rep stosw
    mov ax,0x0E2A
    stosw
obs_row_done:
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    pop bp
    ret 4
make_obstacle_car:
    push bp
    mov bp,sp
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    mov ax,0xb800
    mov es,ax
    mov bl,[bp+6] ; rear row
    mov dx,[bp+4] ; center col
    ; Rear row (bl): body body body body body (changed, no spaces)
    mov al,80
    mul bl
    sub dx,2
    add ax,dx
    shl ax,1
    mov di,ax
    mov ax,0x09DB ; blue body
    mov cx,5
    rep stosw ; pos-2 to +2
    ; Rear wheels (bl-1)
    dec bl
    mov al,80
    mul bl
    mov dx,[bp+4]
    sub dx,2
    add ax,dx
    shl ax,1
    mov di,ax
    mov ax,0x0F4F ; wheel
    stosw ; pos-2
    mov ax,0x09DB ; body
    mov cx,3
    rep stosw ; pos-1 to +1
    mov ax,0x0F4F
    stosw ; pos+2
    ; Cabin row (bl-2)
    dec bl
    mov al,80
    mul bl
    mov dx,[bp+4]
    sub dx,2
    add ax,dx
    shl ax,1
    mov di,ax
    mov ax,0x09DB ; body (changed from side)
    stosw ; pos-2
    mov ax,0x0FB1 ; white ▒ window
    mov cx,3
    rep stosw ; pos-1 to +1
    mov ax,0x09DB ; body (changed from side)
    stosw ; pos+2
    ; Front wheels (bl-3) (changed from hood)
    dec bl
    mov al,80
    mul bl
    mov dx,[bp+4]
    sub dx,2
    add ax,dx
    shl ax,1
    mov di,ax
    mov ax,0x0F4F ; wheel
    stosw ; pos-2
    mov ax,0x09DB ; body
    mov cx,3
    rep stosw ; pos-1 to +1
    mov ax,0x0F4F
    stosw ; pos+2
    ; Front lights (bl-4) (changed, no spaces)
    dec bl
    mov al,80
    mul bl
    mov dx,[bp+4]
    sub dx,2
    add ax,dx
    shl ax,1
    mov di,ax
    mov ax,0x0E2A ; yellow * light
    stosw ; pos-2
    mov ax,0x09DB ; body
    mov cx,3
    rep stosw ; pos-1 to +1
    mov ax,0x0E2A
    stosw ; pos+2
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    pop bp
    ret 4
make_coin:
    push bp
    mov bp,sp
    push ax
    push dx
    push di
    mov ax,0xb800
    mov es,ax
    mov bl,[bp+6] ; row
    mov al,80
    mul bl
    add ax,[bp+4] ; col
    shl ax,1
    mov di,ax
    mov word[es:di],0x8E4F ; yellow 'O' with dark gray background
    pop di
    pop dx
    pop ax
    pop bp
    ret 4
make_fuel:
    push bp
    mov bp,sp
    push ax
    push dx
    push di
    mov ax,0xb800
    mov es,ax
    mov bl,[bp+6] ; row
    mov al,80
    mul bl
    add ax,[bp+4] ; col
    shl ax,1
    mov di,ax
    mov word[es:di],0x8246 ; green 'F' on dark gray
    pop di
    pop dx
    pop ax
    pop bp
    ret 4
scroll_down:
    push ax
    push cx
    push si
    push di
    push ds
    push es
    mov ax,0xb800
    mov es,ax
    mov ds,ax
    mov di,3840
    mov cx,24
sloop:
    mov si,di
    sub si,160
    push cx
    mov cx,60
    rep movsw
    pop cx
    sub di,280
    loop sloop
    pop es
    pop ds
    pop di
    pop si
    pop cx
    pop ax
    ret
draw_bg_row:
    push ax
    push bx
    push cx
    push dx
    push di
    push si
    mov ax,0xb800
    mov es,ax
    mov di,0
    mov cx,60
    mov ax,0x2020
    rep stosw
    mov cx,20
    mov ax,0x0020
    rep stosw
    mov di,28
    mov cx,33
    mov ax,0x08DB
    rep stosw
    mov al,[border_phase]
    mov ah,0x70
    test al,1
    jz even_b
    mov ah,0x40
even_b:
    mov al,0x20
    mov di,28
    mov [es:di],ax
    mov di,94
    mov [es:di],ax
    mov bl,[dash_phase]
    mov ax,0x08DB
    cmp bl,4
    jae gap_d
    mov ax,0x0EB3
gap_d:
    mov di,50
    mov [es:di],ax
    mov di,72
    mov [es:di],ax
    ; draw left tree if any
    push ax
    push bx
    push cx
    push dx
    push di
    mov bl,[tree_phase_left]
    cmp bl,5
    je no_tree_left
    cmp bl,0
    jne no_rand_left
    mov ah,0
    int 1ah
    mov ax,dx
    mov bx,8
    xor dx,dx
    div bx
    add dl,2
    mov [tree_col_left],dl
no_rand_left:
    movzx ax, [tree_col_left]
    shl ax,1
    mov di,ax
    mov ax,0x2ADB
    cmp bl,2
    jae no_trunk_l
    mov ax,0x66DB
no_trunk_l:
    cmp bl,4
    je draw_single_l
    cmp bl,3
    je draw_three_l
    cmp bl,2
    je draw_five_l
draw_single_l:
    stosw
    jmp tree_done_left
draw_three_l:
    sub di,2
    stosw
    stosw
    stosw
    jmp tree_done_left
draw_five_l:
    sub di,4
    mov cx,5
    rep stosw
    jmp tree_done_left
tree_done_left:
no_tree_left:
    pop di
    pop dx
    pop cx
    pop bx
    pop ax
    ; draw right tree if any
    push ax
    push bx
    push cx
    push dx
    push di
    mov bl,[tree_phase_right]
    cmp bl,5
    je no_tree_right
    cmp bl,0
    jne no_rand_right
    mov ah,0
    int 1ah
    mov ax,dx
    mov bx,7
    xor dx,dx
    div bx
    add dl,51
    mov [tree_col_right],dl
no_rand_right:
    movzx ax, [tree_col_right]
    shl ax,1
    mov di,ax
    mov ax,0x2ADB
    cmp bl,2
    jae no_trunk_r
    mov ax,0x66DB
no_trunk_r:
    cmp bl,4
    je draw_single_r
    cmp bl,3
    je draw_three_r
    cmp bl,2
    je draw_five_r
draw_single_r:
    stosw
    jmp tree_done_right
draw_three_r:
    sub di,2
    stosw
    stosw
    stosw
    jmp tree_done_right
draw_five_r:
    sub di,4
    mov cx,5
    rep stosw
    jmp tree_done_right
tree_done_right:
no_tree_right:
    pop di
    pop dx
    pop cx
    pop bx
    pop ax
    ; draw obstacle row if spawning active
    cmp byte [obs_phase],5
    jae no_obs_draw
    push word [obs_phase]
    push word [obs_col]
    call draw_obstacle_row
    inc byte [obs_phase]
    cmp byte [obs_phase],5
    jne no_obs_draw
    mov byte [obs_phase],0xff
no_obs_draw:
    pop si
    pop di
    pop dx
    pop cx
    pop bx
    pop ax
    ret
spawn_obstacle:
    push ax
    push bx
    push cx
    push dx
    mov ah,0
    int 1ah
    mov ax,cx
    xor ax,dx
    mov bx,3
    xor dx,dx
    div bx
    mov ax,20
    cmp dx,0
    je glane
    mov ax,31
    cmp dx,1
    je glane
    mov ax,42
glane:
    mov [obs_spawn_col],ax
    mov [obs_col],ax
    mov byte [obs_phase],0
    pop dx
    pop cx
    pop bx
    pop ax
    ret
spawn_coin:
    push ax
    push bx
    push cx
    push dx
    mov ah,0
    int 1ah
    mov ax,cx
    xor ax,dx
    mov bx,3
    xor dx,dx
    div bx
    mov ax,20
    cmp dx,0
    je coin_lane
    mov ax,31
    cmp dx,1
    je coin_lane
    mov ax,42
coin_lane:
    cmp word [obs_spawn_col],0
    je no_conf
    cmp ax, [obs_spawn_col]
    jne no_conf
    add ax,11
    cmp ax,53
    jb no_wrap_c
    sub ax,33
no_wrap_c:
no_conf:
    mov [coin_spawn_col],ax
    push 0
    push ax
    call make_coin
    pop dx
    pop cx
    pop bx
    pop ax
    ret
spawn_fuel:
    push ax
    push bx
    push cx
    push dx
    mov ah,0
    int 1ah
    mov ax,cx
    xor ax,dx
    mov bx,3
    xor dx,dx
    div bx
    mov ax,20
    cmp dx,0
    je fuel_lane
    mov ax,31
    cmp dx,1
    je fuel_lane
    mov ax,42
fuel_lane:
    cmp word [obs_spawn_col],0
    je check_coin_f
    cmp ax, [obs_spawn_col]
    jne check_coin_f
    add ax,11
    cmp ax,53
    jb check_coin_f
    sub ax,33
check_coin_f:
    cmp word [coin_spawn_col],0
    je no_conf_f
    cmp ax, [coin_spawn_col]
    jne no_conf_f
    add ax,11
    cmp ax,53
    jb no_conf_f
    sub ax,33
no_conf_f:
    push 0
    push ax
    call make_fuel
    pop dx
    pop cx
    pop bx
    pop ax
    ret
wait_tick:
    push ax
    push bx
    push cx ; <--- ADD THIS
    push dx
    mov ah,0
    int 1ah
    mov bx,dx
wtloop:
    mov ah,0
    int 1ah
    cmp dx,bx
    je wtloop
    pop dx
    pop cx ; <--- ADD THIS
    pop bx
    pop ax
    ret
draw_fuel_bar:
    push ax
    push bx
    push cx
    push dx
    push di
    mov ax,0xb800
    mov es,ax
    mov di,290
    mov word [es:di],0x075B ; [
    add di,2
    mov ax,[fuel]
    mov bx,10
    xor dx,dx
    div bx
    mov cx,ax ; filled = fuel // 10
    cmp cx,5
    ja green_bar
    cmp cx,2
    ja yellow_bar
    mov ax,0x04DB ; red solid
    jmp set_bar_char
yellow_bar:
    mov ax,0x0EDB ; yellow solid
    jmp set_bar_char
green_bar:
    mov ax,0x02DB ; green solid
set_bar_char:
    mov bx,cx ; bx = filled
    mov cx,10 ; total bar segments
bar_loop:
    or bx,bx
    jz empty_char
    stosw ; filled segment
    dec bx
    jmp next_bar
empty_char:
    push ax
    mov ax,0x0720 ; space
    stosw
    pop ax
next_bar:
    loop bar_loop
    mov word [es:di],0x075D ; ]
    pop di
    pop dx
    pop cx
    pop bx
    pop ax
    ret
draw_score:
    push ax
    push bx
    push cx
    push dx
    push di
    mov ax,0xb800
    mov es,ax
    mov di,440 ; row 2, col 60
    mov word [es:di],0x0753 ; S
    add di,2
    mov word [es:di],0x0743 ; C
    add di,2
    mov word [es:di],0x074F ; O
    add di,2
    mov word [es:di],0x0752 ; R
    add di,2
    mov word [es:di],0x0745 ; E
    add di,2
    mov word [es:di],0x073A ; :
    add di,2
    add di,2 ; space
    mov ax,[score]
    mov bx,1000
    xor dx,dx
    div bx
    add al,'0'
    mov ah,0x07
    stosw
    mov ax,dx
    mov bx,100
    xor dx,dx
    div bx
    add al,'0'
    mov ah,0x07
    stosw
    mov ax,dx
    mov bx,10
    xor dx,dx
    div bx
    add al,'0'
    mov ah,0x07
    stosw
    add dl,'0'
    mov al,dl
    mov ah,0x07
    stosw
    pop di
    pop dx
    pop cx
    pop bx
    pop ax
    ret
would_collide:
    push bp
    mov bp,sp
    push bx
    push cx
    push dx
    push di
    push si
    mov ax,0xb800
    mov es,ax
    mov bl,[bp+6] ; rear row
    mov dx,[bp+4] ; col
    mov cx,5 ; rows
wcoll_row:
    push cx ; <--- Save Outer Loop Counter
    mov si,dx
    sub si,2
    mov cx,5 ; cols
wcoll_col:
    mov al,80
    mul bl
    add ax,si
    shl ax,1
    mov di,ax
    mov ax,[es:di]
    cmp ax,0x08DB ; road
    je wnext
    cmp ax,0x8E4F ; coin
    je wnext
    cmp ax,0x8246 ; fuel
    je wnext
    ; === COLLISION DETECTED ===
    pop cx ; <--- CRITICAL FIX: Restore Stack before jumping!
    mov ax,1 ; Return 1 (Collision)
    jmp wexit ; Now it is safe to exit
wnext:
    inc si
    loop wcoll_col
    pop cx ; Restore Outer Loop Counter (Standard loop)
    dec bl
    loop wcoll_row
    mov ax,0 ; No collision found
wexit:
    pop si
    pop di
    pop dx
    pop cx
    pop bx
    pop bp
    ret 4
show_spark:
    push bp
    mov bp,sp
    push ax
    push bx
    push dx
    push di
    mov ax,0xb800
    mov es,ax
    mov bl,[bp+6] ; rear
    sub bl,4 ; front
    mov dx,[bp+4] ; col
    sub dx,3
    mov al,80
    mul bl
    add ax,dx
    shl ax,1
    mov di,ax
    mov ax,0x0E2A ; yellow *
    stosw ; col-3
    add di,4
    stosw ; col-1
    add di,4
    stosw ; col+1
    add di,4
    stosw ; col+3
    pop di
    pop dx
    pop bx
    pop ax
    pop bp
    ret 4
show_game_over:
    mov word [current_music], music_menu
    mov word [note_index], 0
    mov word [music_tick_count], 1
    push ax
    push bx
    push cx
    push dx
    push di
    push si
    call draw_background ; Draw the grass/box theme
    ; --- 1. Draw "GAME OVER" Title ---
    mov di, (box_top + 2) * 160 + box_left * 2
    mov si, game_over_title
    mov cx, 9
    mov ah, 0x4F ; Red background, White text
    call draw_centered_in_box
    ; --- 2. Draw Player Name ---
    ; Row: box_top + 4
    mov ax, box_top + 4
    mov bl, 160
    mul bl
    mov di, ax
    add di, box_left * 2 + 4 ; Slightly indented
    ; Draw "Player: "
    mov si, player_label_txt
    mov cx, 8
    mov ah, 0x0F
    call draw_text_linear_go
    ; Draw Actual Name
    mov si, player_name_buf
    mov cx, 15 ; Max len
    call draw_text_linear_go
    ; --- 3. Draw Score ---
    ; Row: box_top + 6
    mov ax, box_top + 6
    mov bl, 160
    mul bl
    mov di, ax
    add di, box_left * 2 + 4
    ; Draw "Score: "
    mov si, score_label_txt
    mov cx, 7
    mov ah, 0x0F
    call draw_text_linear_go
    ; Convert Score Number to String and Draw
    mov ax, [score]
    mov bx, 10
    mov cx, 0
push_score_digits:
    xor dx, dx
    div bx
    push dx
    inc cx
    or ax, ax
    jnz push_score_digits
pop_print_score:
    pop dx
    add dl, '0'
    mov al, dl
    mov ah, 0x0E ; Yellow Score
    stosw
    loop pop_print_score
    ; --- 4. Draw Reason (Crash vs Fuel) ---
    mov di, (box_top + 9) * 160 + box_left * 2
    cmp byte [game_over_reason], 0
    jne show_fuel_msg
    ; Case: Crash
    mov si, reason_crash_txt
    mov cx, 19
    mov ah, 0x4F ; Red Background
    jmp draw_reason_final
show_fuel_msg:
    ; Case: Fuel
    mov si, reason_fuel_txt
    mov cx, 19
    mov ah, 0x6F ; Brown/Orange Background
draw_reason_final:
    call draw_centered_in_box
    ; --- 5. Draw Return Prompt ---
    mov di, (box_bottom - 2) * 160 + box_left * 2
    mov si, menu_return_txt
    mov cx, 20
    mov ah, 0x8F ; Blink/Grey
    call draw_centered_in_box
    ; --- Wait for Enter Key ---
wait_go_enter:
    mov ah, 0
    int 16h
    cmp al, 0x0D ; Enter key
    jne wait_go_enter
    pop si
    pop di
    pop dx
    pop cx
    pop bx
    pop ax
    ; JUMP TO START (Main Menu)
    ; We reset the stack pointer to prevent overflow after many games
    mov sp, 0xFFFE
    jmp start
; Helper for Game Over text drawing
draw_text_linear_go:
    lodsb
    cmp al, 0 ; Check for end of name string
    je dtl_end
    stosw
    loop draw_text_linear_go
dtl_end:
    ret
; ============ PLAYER INFO SCREEN ============
get_player_info:
    push ax
    push bx
    push cx
    push dx
    push di
    push si
    call draw_background ; Re-draw the grass/box background
    ; --- Draw Title ---
    mov di, (box_top + 2) * 160 + box_left * 2
    mov si, info_title_text
    mov cx, 14
    mov ah, 0xCE ; Light Red/Yellow (Matches Menu Theme)
    call draw_centered_in_box
    ; --- Draw "Name:" Prompt ---
    ; Calculate position: Row = box_top + 5, Col = box_left + 4
    mov ax, box_top + 5
    mov bl, 160
    mul bl
    mov di, ax
    mov ax, box_left + 4
    shl ax, 1
    add di, ax
    mov si, info_name_prompt
    mov cx, 6
    mov ah, 0x0F ; White on Black
    call draw_text_linear ; Draw "Name: "
    ; --- Input Name ---
    mov si, player_name_buf
    mov cx, 15 ; Max characters
    call input_string_gui
    ; --- Draw "Roll No:" Prompt ---
    ; Calculate position: Row = box_top + 7, Col = box_left + 4
    mov ax, box_top + 7
    mov bl, 160
    mul bl
    mov di, ax
    mov ax, box_left + 4
    shl ax, 1
    add di, ax
    mov si, info_roll_prompt
    mov cx, 9
    mov ah, 0x0F
    call draw_text_linear ; Draw "Roll No: "
    ; --- Input Roll No ---
    mov si, player_roll_buf
    mov cx, 15 ; Max characters
    call input_string_gui
    ; --- Draw Start Prompt ---
    mov di, (box_bottom - 3) * 160 + box_left * 2
    mov si, info_start_msg
    mov cx, 20
    mov ah, 0x2F ; White on Green
    call draw_centered_in_box
wait_for_enter_start:
    mov ah, 0
    int 16h
    cmp al, 0x0D ; Enter Key
    jne wait_for_enter_start
    pop si
    pop di
    pop dx
    pop cx
    pop bx
    pop ax
    ret
; --- Helper: Draw string and advance DI (Cursor) ---
draw_text_linear:
    ; SI=String, CX=Len, AH=Attr, DI=Pos
draw_lin_loop:
    lodsb
    stosw
    loop draw_lin_loop
    ret
; --- Helper: Input String Routine ---
input_string_gui:
    ; SI=Buffer, CX=MaxLen, DI=ScreenPos
    push ax
    push bx
    push dx
    push di
    mov bx, 0 ; Char counter
input_loop_g:
    mov ah, 0
    int 16h ; Get Key
    cmp al, 0x0D ; Enter
    je input_done_g
    cmp al, 0x08 ; Backspace
    je handle_bksp_g
    cmp bx, cx ; Check Limit
    jae input_loop_g
    ; Printable Char
    mov [si+bx], al ; Store in RAM
    inc bx
    mov ah, 0x0F ; White Text
    stosw ; Draw on Screen
    jmp input_loop_g
handle_bksp_g:
    cmp bx, 0
    je input_loop_g
    dec bx
    sub di, 2
    mov word [es:di], 0x0020 ; Erase from screen
    mov byte [si+bx], 0 ; Erase from RAM
    jmp input_loop_g
input_done_g:
    pop di
    pop dx
    pop bx
    pop ax
    ret
pause_handler:
    pusha ; Save all registers
    push es
    push ds
    ; --- 1. Save the Current Game Screen ---
    mov ax, 0xb800
    mov ds, ax ; DS = Video Memory
    mov si, 0 ; Source = Top left of screen
    mov ax, cs ; ES = Our Data Segment
    mov es, ax
    mov di, screen_buffer ; Destination = Our buffer
    mov cx, 2000 ; 2000 words = 4000 bytes (full screen)
    rep movsw ; Copy video -> buffer
    ; --- 2. Draw the Pause Menu ---
    ; We set DS back to CS so we can access our variables
    mov ax, cs
    mov ds, ax
    call draw_background ; Clears screen and draws the box theme
    ; Set ES to Video Memory for text drawing
    mov ax, 0xb800
    mov es, ax
    ; Draw Title
    mov di, (box_top + 5) * 160 + box_left * 2
    mov si, pause_title
    mov cx, 11
    mov ah, 0xCE ; Red on Red/Yellow
    call draw_centered_in_box
    ; Draw Question
    mov di, (box_top + 8) * 160 + box_left * 2
    mov si, pause_msg
    mov cx, 18
    mov ah, 0x0F ; White text
    call draw_centered_in_box
    ; Draw Options
    mov di, (box_top + 10) * 160 + box_left * 2
    mov si, pause_opt
    mov cx, 22
    mov ah, 0x0E ; Yellow text
    call draw_centered_in_box
    ; --- 3. Wait for Input ---
pause_wait_key:
    mov ah, 0
    int 16h
    cmp al, 'y'
    je quit_yes
    cmp al, 'Y'
    je quit_yes
    cmp al, 'r'
    je resume_now
    cmp al, 'R'
    je resume_now
    cmp al, 27 ; Check ESC again to Resume
    je resume_now
    jmp pause_wait_key
quit_yes:
    mov word [current_music], music_menu
    mov word [note_index], 0
    mov word [music_tick_count], 1
    call unhook_timer ; <--- STOP MUSIC IF QUITTING FROM PAUSE
    mov sp, 0xFFFE ; Reset stack pointer to prevent overflow
    jmp start ; Go to Main Menu
resume_now:
    ; --- 4. Restore the Game Screen ---
    mov ax, cs ; DS = Our Data Segment
    mov ds, ax
    mov si, screen_buffer ; Source = Our buffer
    mov ax, 0xb800 ; ES = Video Memory
    mov es, ax
    mov di, 0 ; Destination = Top left
    mov cx, 2000 ; Restore 4000 bytes
    rep movsw
    pop ds
    pop es
    popa ; Restore registers
    jmp no_input ; Jump back to game loop (skip input processing this frame)
start:
    call hook_timer ; <--- START BACKGROUND MUSIC HERE
    mov word [note_index], 0
    mov word [music_tick_count], 1
    ; disable blink to enable 16 background colors
    push ax
    push dx
    mov dx,0x3DA
    in al,dx
    mov dx,0x3C0
    mov al,0x10
    out dx,al
    mov dx,0x3C1
    in al,dx
    mov ah,al
    and ah,0xF7
    mov dx,0x3DA
    in al,dx
    mov dx,0x3C0
    mov al,0x10
    out dx,al
    mov al,ah
    out dx,al
    pop dx
    pop ax
    call draw_menu
    call menu_input ; (This line is already there)
    ; =================================================
    ; === RESET ALL GAME VARIABLES FOR NEW GAME ===
    ; =================================================
    mov word [score], 0
    mov word [fuel], 100
    mov word [car_row], 24
    mov word [car_col], 31
    mov word [old_car_row], 24
    mov word [old_car_col], 31
    mov byte [collision_detected], 0
    mov byte [game_over_reason], 0
    ; Reset Environment
    mov byte [obs_phase], 0xFF ; Turn off obstacles
    mov word [obs_spawn_col], 0
    mov word [coin_spawn_col], 0
    ; Reset Timers
    mov word [spawn_delay], 50
    mov word [spawn_delay_coin], 25
    mov word [spawn_delay_fuel], 60
    mov word [tick_count], 0
    ; Reset Animation Phases
    mov byte [border_phase], 0
    mov byte [dash_phase], 0
    mov byte [tree_phase_left], 0
    mov byte [tree_phase_right], 2
    ; =================================================
    mov ax,0 ; starting row (Continue with your existing code below...)
    push ax
    mov ax,14 ; starting col
    push ax
    mov ax,25 ; total counter
    push ax
    call set_scr
mov byte[row],6 ;setting parameter for tree printing
mov ax,[row]
push ax
mov byte[col],3 ;setting parameter for tree printing
mov ax,[col]
push ax
call make_tree
mov byte[row],12 ;setting parameter for tree printing
mov ax,[row]
push ax
mov byte[col],6 ;setting parameter for tree printing
mov ax,[col]
push ax
call make_tree
mov byte[row],18 ;setting parameter for tree printing
mov ax,[row]
push ax
mov byte[col],2 ;setting parameter for tree printing
mov ax,[col]
push ax
call make_tree
mov byte[row],24 ;setting parameter for tree printing
mov ax,[row]
push ax
mov byte[col],9 ;setting parameter for tree printing
mov ax,[col]
push ax
call make_tree
mov byte[row],4 ;setting parameter for tree printing
mov ax,[row]
push ax
mov byte[col],52 ;setting parameter for tree printing
mov ax,[col]
push ax
call make_tree
mov ax,10
push ax
mov ax,57
push ax
call make_tree
mov ax,16
push ax
mov ax,51
push ax
call make_tree
mov ax,22
push ax
mov ax,55
push ax
call make_tree
mov byte[row],0
mov byte[col],0
mov word [car_row],24 ;setting parameter for car printing
push word [car_row]
mov word [car_col],31 ; adjusted center col
push word [car_col]
call make_Action_Cruiser
mov word [old_car_row],24
mov word [old_car_col],31
mov ax,0xb800
mov es,ax
mov di,280
mov word [es:di],0x0746
add di,2
mov word [es:di],0x0755
add di,2
mov word [es:di],0x0745
add di,2
mov word [es:di],0x074C
add di,2
mov word [es:di],0x073A
add di,2
call draw_fuel_bar
call draw_score
mov byte[row],0
mov byte[col],0
mov byte [border_phase],0
mov byte [dash_phase],0
mov byte [tree_phase_left],0
mov byte [tree_phase_right],2
mov ah,0
int 1ah
mov ax,dx
mov bx,8
xor dx,dx
div bx
add dl,2
mov [tree_col_left],dl
mov ah,0
int 1ah
mov ax,dx
mov bx,7
xor dx,dx
div bx
add dl,51
mov [tree_col_right],dl
mov ah,0
int 1ah
mov [last_spawn],dx
mov [last_spawn_coin],dx
mov [last_spawn_fuel],dx
mov word [spawn_delay],50
mov word [spawn_delay_coin],25
mov word [spawn_delay_fuel],60
game_loop:
    mov ah,1
    int 16h
    jnz have_input
    jmp no_input
have_input:
input_loop:
    mov ah,0
    int 16h
    cmp ah, 0x01 ; Check for ESC key
    je go_to_pause ; Jump to pause routine
    cmp ah,4Bh ; left arrow
    je move_left
    cmp ah,4Dh ; right arrow
    je move_right
    cmp ah,48h ; up arrow
    je move_up
    cmp ah,50h ; down arrow
    je move_down
    jmp input_loop_end
go_to_pause: ; Tiny bridge to reach the faraway function
    jmp pause_handler
move_left:
    cmp word [car_col],20
    jbe input_loop_end
    mov ax,[car_col]
    sub ax,11
    mov bx,ax
    push word [car_row]
    push bx
    call would_collide
    cmp ax,0
    jne coll_left
    mov word [car_col],bx
    jmp input_loop_end
coll_left:
    jmp input_loop_end
move_right:
    cmp word [car_col],42
    jae input_loop_end
    mov ax,[car_col]
    add ax,11
    mov bx,ax
    push word [car_row]
    push bx
    call would_collide
    cmp ax,0
    jne coll_right
    mov word [car_col],bx
    jmp input_loop_end
coll_right:
    jmp input_loop_end
move_up:
    cmp word [car_row],4
    jbe input_loop_end
    dec word [car_row]
    jmp input_loop_end
move_down:
    cmp word [car_row],24
    jae input_loop_end
    inc word [car_row]
    jmp input_loop_end
input_loop_end:
    mov ah,1
    int 16h
    jz no_more_input
    jmp input_loop
no_more_input:
no_input:
    cmp byte [collision_detected],1
    je input_coll
    jmp continue_clear
input_coll:
    push word [car_row]
    push word [car_col]
    call show_spark
    mov cx, 18
delay_input:
    call wait_tick
    loop delay_input
    mov byte [game_over_reason], 0 ; 0 indicates CRASH
    jmp call_game_over_screen
continue_clear:
    push word [old_car_row]
    push word [old_car_col]
    call clear_Action_Cruiser
    mov word [coin_spawn_col],0
    call scroll_down
    mov al,[border_phase]
    xor al,1
    mov [border_phase],al
    mov al,[dash_phase]
    or al,al
    jnz notz
    mov al,6
notz:
    dec al
    mov [dash_phase],al
    inc byte [tree_phase_left]
    cmp byte [tree_phase_left],6
    jb no_reset_tl
    mov byte [tree_phase_left],0
no_reset_tl:
    inc byte [tree_phase_right]
    cmp byte [tree_phase_right],6
    jb no_reset_tr
    mov byte [tree_phase_right],0
no_reset_tr:
    call draw_bg_row
    mov word [obs_spawn_col],0
    cmp byte [obs_phase],0xff
    je skip_set_obs
    mov ax,[obs_col]
    mov [obs_spawn_col],ax
skip_set_obs:
    mov ah,0
    int 1ah
    mov bx,dx
    sub bx,[last_spawn]
    cmp bx,[spawn_delay]
    jb nosp
    cmp byte [obs_phase],0xff
    jne nosp
    call spawn_obstacle
    mov ah,0
    int 1ah
    mov [last_spawn],dx
    push ax
    push bx
    push cx
    push dx
    mov ax, [score]
    mov bx, 50
    xor dx,dx
    div bx ; ax = score / 50
    mov cx, ax ; save diff
    mov bx, 40
    sub bx, ax ; base = 40 - diff
    push bx ; save base
    mov ah,0
    int 1ah
    mov ax, dx
    mov bx, 10
    xor dx,dx
    div bx ; dx = rand % 10
    pop bx
    add bx, dx ; base + rand%10
    cmp bx, 10
    ja no_clamp
    mov bx,10
no_clamp:
    mov [spawn_delay], bx
    pop dx
    pop cx
    pop bx
    pop ax
nosp:
    mov ah,0
    int 1ah
    mov bx,dx
    sub bx,[last_spawn_coin]
    cmp bx,[spawn_delay_coin]
    jb no_coin_sp
    call spawn_coin
    mov ah,0
    int 1ah
    mov [last_spawn_coin],dx
    mov ax,dx
    xor ax,cx
    and ax,001fh
    add ax,20
    mov [spawn_delay_coin],ax
no_coin_sp:
    ; --- Check Timer FIRST ---
    mov ah,0
    int 1ah
    mov bx,dx
    sub bx,[last_spawn_fuel]
    cmp bx,[spawn_delay_fuel]
    jb no_fuel_sp ; If it's not time yet, skip everything
    ; --- It IS time. Reset the timer immediately ---
    ; We reset the timer NOW, regardless of whether we actually spawn the fuel.
    ; This prevents the "spam" backlog.
    mov ah,0
    int 1ah
    mov [last_spawn_fuel],dx
    ; Calculate next delay (randomize slightly)
    mov ax,dx
    and ax,003fh ; Increased mask to 0x3F (0-63 ticks) for longer gaps
    add ax,50 ; Minimum delay 50 ticks (slower spawning)
    mov [spawn_delay_fuel],ax
    ; --- NOW Check Fuel Condition ---
    cmp word [fuel], 30 ; Is fuel low?
    ja no_fuel_sp ; If fuel > 30, we wasted this cycle (Ghost Spawn).
                          ; We won't check again until the timer runs out again.
    ; --- Only spawn if we passed both checks ---
    call spawn_fuel
no_fuel_sp:
    mov ax,0xb800
    mov es,ax
    mov bl,byte [car_row]
    mov dx,[car_col]
    mov cx,5
check_row_loop:
    push bx
    push dx
    push cx
    mov si,dx
    sub si,2
    mov cx,5
check_col_loop:
    mov al,80
    mul bl
    add ax,si
    shl ax,1
    mov di,ax
    cmp word [es:di],0x8E4F
    jne no_coin_here
    add word [score],10
    mov word [es:di],0x08DB
no_coin_here:
    cmp word [es:di],0x8246
    jne no_fuel_here
    add word [fuel],20
    cmp word [fuel],100
    jbe no_cap
    mov word [fuel],100
no_cap:
    call draw_fuel_bar
    mov word [es:di],0x08DB
no_fuel_here:
    inc si
    loop check_col_loop
    pop cx
    pop dx
    pop bx
    dec bl
    loop check_row_loop
    mov byte [collision_detected],0
    mov cx,5
    mov bl,[car_row]
    mov dx,[car_col]
coll_check2_loop:
    push bx
    push dx
    push cx
    mov si,dx
    sub si,2
    mov cx,5
coll_col2_loop:
    mov al,80
    mul bl
    add ax,si
    shl ax,1
    mov di,ax
    mov ax,[es:di]
    cmp ax,0x08DB
    je next2
    mov byte [collision_detected],1
    pop cx
    pop dx
    pop bx
    jmp after_coll_check
next2:
    inc si
    loop coll_col2_loop
    pop cx
    pop dx
    pop bx
    dec bl
    loop coll_check2_loop
after_coll_check:
    push word [car_row]
    push word [car_col]
    call make_Action_Cruiser
    cmp byte [collision_detected], 1
    jne no_scroll_coll
    ; --- COLLISION DETECTED ---
    push word [car_row]
    push word [car_col]
    call show_spark
    mov cx, 18
delay_scroll:
    call wait_tick
    loop delay_scroll
    mov byte [game_over_reason], 0 ; Set reason to CRASH
    jmp call_game_over_screen
no_scroll_coll:
    mov ax,[car_row]
    mov [old_car_row],ax
    mov ax,[car_col]
    mov [old_car_col],ax
    call wait_tick
    ;add word [score],1 ; <-- COMMENTED OUT TO FIX AUTO-UPDATE ISSUE
    inc word [tick_count]
    cmp word [tick_count],18
    jb no_dec_fuel
    mov word [tick_count],0
    dec word [fuel]
    call draw_fuel_bar
    cmp word [fuel], 0
    jne no_dec_fuel
    mov byte [game_over_reason], 1 ; 1 indicates NO FUEL
    jmp call_game_over_screen
no_dec_fuel:
    call draw_score
    jmp game_loop
call_game_over_screen:
    call show_game_over
row: db 0
col: db 0
obs_row: db 0
obs_col: dw 0
obs_phase: db 0xff
border_phase: db 0
dash_phase: db 0
last_spawn: dw 0
spawn_delay: dw 10
tree_phase_left: db 0
tree_phase_right: db 0
tree_col_left: db 0
tree_col_right: db 0
obs_spawn_col: dw 0
last_spawn_coin: dw 0
spawn_delay_coin: dw 10
last_spawn_fuel: dw 0
spawn_delay_fuel: dw 10
coin_spawn_col: dw 0
fuel: dw 100
tick_count: dw 0
car_col: dw 31
old_car_col: dw 31
car_row: dw 24
old_car_row: dw 24
score: dw 0
collision_detected: db 0
; ============ MENU TEXT DATA ============
title_text: db 'CAR SHOW SPEED'
play_text: db 'Press P to Play Game'
instructions_text: db 'Press I for Instructions'
credits_text: db 'Press C for Credits'
quit_text: db 'Press Q to Quit'
instructions_title: db 'GAME INSTRUCTIONS'
credits_title: db 'CREDITS'
name1: db 'Ali Zulfiqar 24L--0658'
name2: db 'Aoun Abbas 24L-0724'
instr1: db 'Use LEFT and RIGHT arrows to move car'
instr2: db 'Avoid collision with other cars'
instr3: db 'Collect coins for extra points'
instr4: db 'Stay on the road at all times'
instr5: db 'Survive as long as possible'
return_text: db 'Press M or ESC for Main Menu'
game_over_text: db 'Game Over'
score_text: db 'Your Score: '
exit_text: db 'Press any key to exit'
temp_row: dw 0
temp_col: dw 0
; ============ PLAYER INFO DATA ============
info_title_text: db 'PLAYER DETAILS'
info_name_prompt: db 'Name: '
info_roll_prompt: db 'Roll No: '
info_start_msg: db 'Press ENTER to Start'
player_name_buf: times 20 db 0
player_roll_buf: times 20 db 0
; ============ GAME OVER DATA ============
game_over_title: db 'GAME OVER'
reason_crash_txt: db 'Reason: CAR CRASHED'
reason_fuel_txt: db 'Reason: OUT OF FUEL'
score_label_txt: db 'Score: '
player_label_txt: db 'Player: '
menu_return_txt: db 'Press ENTER for Menu'
game_over_reason: db 0 ; 0 = Crash, 1 = Fuel
; ============ PAUSE MENU DATA ============
pause_title: db 'GAME PAUSED'
pause_msg: db 'Quit to Main Menu?'
pause_opt: db 'Y = Yes / R = Resume'
screen_buffer: times 4000 db 0 ; Reserve 4000 bytes to save the screen
