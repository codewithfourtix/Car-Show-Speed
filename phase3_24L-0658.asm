
[org 0x0100]
mov ax, 3508h
int 21h
mov word [old_isr], bx
mov word [old_isr+2], es
jmp start
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
