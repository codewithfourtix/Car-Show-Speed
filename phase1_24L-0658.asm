
[org 0x0100]
    jmp start
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
    color_the_screen:
    mov word[es:di],0x20B1 ; green grass
    add di,2
    cmp di,4000
    jne color_the_screen
mov di,0
; random yellow grains + stones + rocks
add_grains:
mov ax, di
xor ax, 137
and ax, 00FFh
; yellow grain after every ~4th cell
cmp al, 4
jne skip_grain
mov word[es:di],0x2EB1 ; yellow grain
skip_grain:
; stone after every ~77th position
cmp al, 77
jne skip_stone
mov word[es:di],0x4E0F   ; flowers
skip_stone:
cmp al, 155
jne skip_rock
mov word[es:di],0x2F0F; flowers
skip_rock:
add di,2
cmp di,4000
jne add_grains
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
    mov cx,42 ;num of blocks
    set_road_bg:
    mov word[es:di],0x00B1 ; black space
    add di,2
    loop set_road_bg
    pop cx
    inc dx
    loop make_road
    mov dx,[bp+8] ;reset the value of dx to point to the first row
mov cx,[bp+4]
    set_left_lane:
    ;making the formula
    mov al,80
    mul dl
    add ax,[bp + 6]
    add ax,14
shl ax,1
;now making the lanes
mov di,ax
mov word[es:di],0x0EDC
add dl,1
loop set_left_lane
set_right_lane:
     ;making the formula
    mov al,80
    mul dl
    add ax,[bp + 6]
    add ax,29
shl ax,1
 ;now making the lanes
mov di,ax
mov word[es:di],0x0EDC
add dl,1
loop set_right_lane
; setting the left side border
set_left_border_lane:
    ;making the formula
    mov al,80
    mul dl
    add ax,[bp + 6]
shl ax,1
;now making the lanes
mov di,ax
mov word[es:di],0x0FB1
add dl,1
loop set_left_border_lane
set_right_border_lane:
    ;making the formula
    mov al,80
    mul dl
    add ax,[bp + 6]
add ax,42
shl ax,1
;now making the lanes
mov di,ax
mov word[es:di],0x0FB1
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
make_cactus:
    push bp
    mov bp,sp
    push ax
    push bx
    push dx
    push si
    push di
    mov bl,[bp+6] ; cactus row (base)
    mov dx,[bp+4] ; cactus col (center)
    mov cx,4 ; stem height
stem_loop:
    mov al,80
    mul bl
    add ax,dx
    shl ax,1
    mov di,ax
    mov ax,0x2E2A ; '*' yellow on green
push ax
mov ax,0xb800
    mov es,ax
pop ax
    mov [es:di],ax
    dec bl
    loop stem_loop
    mov cx,2
    mov bx,[bp+6] ; reset row
    sub bx,2 ; arm attaches midstem
    mov dx,[bp+4]
    sub dx,2 ; start left
left_arm:
    mov al,80
    mul bl
    add ax,dx
    shl ax,1
    mov di,ax
    mov ax,0x6E3D
    mov [es:di],ax
    inc dx
    loop left_arm
    mov cx,2
    mov bx,[bp+6]
    sub bx,2
    mov dx,[bp+4]
    add dx,1 ; start right
right_arm:
    mov al,80
    mul bl
    add ax,dx
    shl ax,1
    mov di,ax
    mov ax,0x6E3D
    mov [es:di],ax
    inc dx
    loop right_arm
    pop di
    pop si
    pop dx
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
    mov bl,[bp+6]       ; rear row (base)
    mov dx,[bp+4]       ; center col

    ; Rear row (bl): body + wheels
    mov al,80
    mul bl
    sub dx,4            ; start col
    add ax,dx
    shl ax,1
    mov di,ax
    mov ax,0x0CDF       ; red █ body
    stosw               ; pos0
    mov ax,0x08B2       ; gray ▓ wheel
    mov cx,2
    rep stosw           ; pos1-2
    mov ax,0x0CDF       ; body
    mov cx,3
    rep stosw           ; pos3-5
    mov ax,0x08B2       ; wheel
    mov cx,2
    rep stosw           ; pos6-7
    mov ax,0x0CDF       ; body
    stosw               ; pos8

    ; Rear cabin row (bl-1): sides + left/rear windows + pillar + right/rear windows
    dec bl
    mov al,80
    mul bl
    mov dx,[bp+4]
    sub dx,4
    add ax,dx
    shl ax,1
    mov di,ax
    mov ax,0x0020       ; black space
    stosw               ; pos0
    mov ax,0x0CDF       ; body side
    stosw               ; pos1
    mov ax,0x0BB1       ; cyan ▒ window
    mov cx,2
    rep stosw           ; pos2-3
    mov ax,0x0020       ; pillar
    stosw               ; pos4
    mov ax,0x0BB1       ; window
    mov cx,2
    rep stosw           ; pos5-6
    mov ax,0x0CDF       ; body side
    stosw               ; pos7
    mov ax,0x0020       ; space
    stosw               ; pos8

    ; Front cabin row (bl-2): same as rear cabin (4 windows total)
    dec bl
    mov al,80
    mul bl
    mov dx,[bp+4]
    sub dx,4
    add ax,dx
    shl ax,1
    mov di,ax
    mov ax,0x0020
    stosw               ; pos0
    mov ax,0x0CDF
    stosw               ; pos1
    mov ax,0x0BB1
    mov cx,2
    rep stosw           ; pos2-3
    mov ax,0x0020
    stosw               ; pos4
    mov ax,0x0BB1
    mov cx,2
    rep stosw           ; pos5-6
    mov ax,0x0CDF
    stosw               ; pos7
    mov ax,0x0020
    stosw               ; pos8

    ; Front hood row (bl-3): headlights + narrow body
    dec bl
    mov al,80
    mul bl
    mov dx,[bp+4]
    sub dx,4
    add ax,dx
    shl ax,1
    mov di,ax
    mov ax,0x0020
    stosw               ; pos0
    mov ax,0x0E2A       ; yellow * headlight
    stosw               ; pos1
    mov ax,0x0CDF       ; body
    mov cx,5
    rep stosw           ; pos2-6
    mov ax,0x0E2A       ; headlight
    stosw               ; pos7
    mov ax,0x0020
    stosw               ; pos8

    pop di
    pop si
    pop dx
    pop bx
    pop cx              ; note: cx not pushed? Wait, push cx if needed, but ok
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
    mov bl,[bp+6]       ; rear row
    mov dx,[bp+4]       ; center col

    ; Rear row: same as player
    mov al,80
    mul bl
    sub dx,4
    add ax,dx
    shl ax,1
    mov di,ax
    mov ax,0x09DF       ; blue █ body
    stosw               ; pos0
    mov ax,0x08B2       ; gray ▓ wheel
    mov cx,2
    rep stosw           ; pos1-2
    mov ax,0x09DF
    mov cx,3
    rep stosw           ; pos3-5
    mov ax,0x08B2
    mov cx,2
    rep stosw           ; pos6-7
    mov ax,0x09DF
    stosw               ; pos8

    ; Rear cabin (bl-1)
    dec bl
    mov al,80
    mul bl
    mov dx,[bp+4]
    sub dx,4
    add ax,dx
    shl ax,1
    mov di,ax
    mov ax,0x0020
    stosw               ; pos0
    mov ax,0x09DF
    stosw               ; pos1
    mov ax,0x0FB1       ; white ▒ window
    mov cx,2
    rep stosw           ; pos2-3
    mov ax,0x0020
    stosw               ; pos4
    mov ax,0x0FB1
    mov cx,2
    rep stosw           ; pos5-6
    mov ax,0x09DF
    stosw               ; pos7
    mov ax,0x0020
    stosw               ; pos8

    ; Front cabin (bl-2): copy of rear cabin
    dec bl
    mov al,80
    mul bl
    mov dx,[bp+4]
    sub dx,4
    add ax,dx
    shl ax,1
    mov di,ax
    mov ax,0x0020
    stosw               ; pos0
    mov ax,0x09DF
    stosw               ; pos1
    mov ax,0x0FB1
    mov cx,2
    rep stosw           ; pos2-3
    mov ax,0x0020
    stosw               ; pos4
    mov ax,0x0FB1
    mov cx,2
    rep stosw           ; pos5-6
    mov ax,0x09DF
    stosw               ; pos7
    mov ax,0x0020
    stosw               ; pos8

    ; Front hood (bl-3)
    dec bl
    mov al,80
    mul bl
    mov dx,[bp+4]
    sub dx,4
    add ax,dx
    shl ax,1
    mov di,ax
    mov ax,0x0020
    stosw               ; pos0
    mov ax,0x0E2A       ; yellow * headlight
    stosw               ; pos1
    mov ax,0x09DF
    mov cx,5
    rep stosw           ; pos2-6
    mov ax,0x0E2A
    stosw               ; pos7
    mov ax,0x0020
    stosw               ; pos8

    pop di
    pop si
    pop dx
    push cx             ; align pop
    pop bx
    pop ax
    pop bp
    ret 4
    start:
    mov ax,0 ; starting row
    push ax
    mov ax,18 ; starting col
    push ax
    mov ax,25 ; total counter
    push ax
    call set_scr
mov byte[row],4 ;setting parameter for cactus printing
mov ax,[row]
push ax
mov byte[col],3 ;setting parameter for cactus printing
mov ax,[col]
push ax
call make_cactus
mov byte[row],12 ;setting parameter for cactus printing
mov ax,[row]
push ax
mov byte[col],13 ;setting parameter for cactus printing
mov ax,[col]
push ax
call make_cactus
mov byte[row],10 ;setting parameter for cactus printing
mov ax,[row]
push ax
mov byte[col],67 ;setting parameter for cactus printing
mov ax,[col]
push ax
call make_cactus
mov byte[row],24 ;setting parameter for cactus printing
mov ax,[row]
push ax
mov byte[col],76 ;setting parameter for cactus printing
mov ax,[col]
push ax
call make_cactus
mov byte[row],20 ;setting parameter for cactus printing
mov ax,[row]
push ax
mov byte[col],7 ;setting parameter for cactus printing
mov ax,[col]
push ax
call make_cactus
mov byte[row],0
mov byte[col],0
mov byte[row],24 ;setting parameter for cactus printing
mov ax,[row]
push ax
mov byte[col],40 ;setting parameter for cactus printing
mov ax,[col]
push ax
call make_Action_Cruiser
mov byte[row],0
mov byte[col],0
; add random obstacle
mov ah,0
int 1Ah
mov ax,dx
and ax,0Fh
add ax,2
mov byte [obs_row],al
mov ax,cx
xor ax,dx
mov bx,3
xor dx,dx
div bx
cmp dx,0
je set_left
cmp dx,1
je set_mid
set_right:
mov ax,53
jmp set_col
set_left:
mov ax,25
jmp set_col
set_mid:
mov ax,40
set_col:
mov byte [obs_col],al
mov ax,0
mov al,[obs_row]
push ax
mov ax,0
mov al,[obs_col]
push ax
call make_obstacle_car
    termninate:
    mov ax,0x4c00
    int 0x21
row: db 0
col: db 0
obs_row: db 0
obs_col: db 0
