
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
