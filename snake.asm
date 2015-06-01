.386
cseg segment use16
assume cs:cseg, ds:cseg
org 100h

@entry: 
    jmp @main
    
buffer db 10h dup(?)
head dw 0
tail dw 0
oldint9 dd ?

curtime dw 0    

snake_ticks dw 3
snake_timer dw 0

dead_food 	dw 	0
max_dead_food 	dw 	10

food_ticks equ 40
food_timer dw 0
    
constant dw 8405h ;multiplier value
seed1 dw ?
seed2 dw ? ;random number seeds
len_pixel equ 8
way db 0
way_tmp db 0
; 0 - left, 1 - up, 2 - right, 3 - down

snake dw 2613h, 255 dup (?)
head_snake db 0
tail_snake db 0
len_snake 	dw	1
rev 	db 	0

score dw 0
num_step dw 0
life dw 1
pause_ db 0
die db 0
steps_text db 'steps:'
len_text db 'len:'
len_len_text equ $ - offset len_text
msg_die db 'NOO!'
len_msg_die equ $ - offset msg_die
gameOverMelody 		dw 270, 260, 250, 240, 200, 190
isGameOverMelodyPlayed 	db 0


; j, i, öâåò
pixel proc
    push bp
    mov bp, sp
    pusha
    xor bh, bh
    mov ah, 0ch
    mov al, [bp+8]

    xor cx, cx
    @draw_x:
        xor dx, dx
        @draw_y:
            push cx dx
            
            mov di, [bp+4]
            shl di, 3
            add cx, di
            add cx, len_pixel            
            
            mov di, [bp+6]
            shl di, 3
            add dx, di
            add dx, 30        
            int 10h
            
            pop dx cx
            inc dx
            cmp dx, len_pixel
            jnz @draw_y        
        inc cx
        cmp cx, len_pixel
        jnz @draw_x
    
    popa
    pop bp
    ret 6
pixel endp

next_head_snake proc
	pusha
	cmp 	rev, 	1
	je 	next_head_snake_loop1
	dec 	head_snake
	jmp 	next_head_snake_end
	next_head_snake_loop1:
		inc 	head_snake
	next_head_snake_end:

	popa
	ret
next_head_snake endp

next_tail_snake proc
	pusha
	cmp 	rev, 	1
	je 	next_tail_snake_loop1
	dec 	tail_snake
	jmp 	next_tail_snake_end
	next_tail_snake_loop1:
		inc 	tail_snake
	next_tail_snake_end:

	popa
	ret
next_tail_snake endp

inc_rev proc
    	; cmp 	rev, 	1
	; je 	inc_rev_loop1
	add 	ax, 	bx
	; jmp 	inc_rev_end
	; inc_rev_loop1:
	; 	sub 	ax, 	bx
	; inc_rev_end:
    	ret
inc_rev endp

dec_rev proc
	; cmp 	rev, 	0
	; je 	inc_rev_loop1
	; add 	ax, 	bx
	; jmp 	dec_rev_end
	; dec_rev_loop1:
	sub 	ax, 	bx
	; dec_rev_end:
   	ret
dec_rev endp

draw_border proc
	pusha

	mov	dx,	0
	mov	cx,	0
	@draw_border_left:
	push	8
	push	dx	cx
	call	pixel
	inc	dx
	cmp	dx,	38
	jnz	@draw_border_left

	mov	dx,	0
	mov	cx,	77
	@draw_border_right:
	push	13
	push	dx	cx
	call	pixel
	inc	dx
	cmp	dx,	38
	jl	@draw_border_right

	mov	cx,	0
	mov	dx,	0
	@draw_border_up:
	push	14
	push	dx	cx
	call	pixel
	inc	cx
	cmp	cx,	78
	jnz	@draw_border_up

	mov	cx,	0
	mov	dx,	38	
	@draw_border_down:
	push	14
	push	dx	cx
	call	pixel
	inc	cx
	cmp	cx,	78
	jnz	@draw_border_down

	popa
	ret
draw_border endp

playMelody proc
	pusha	
	mov 	cx, offset isGameOverMelodyPlayed - offset gameOverMelody
	shr 	cx, 1
	mov 	bl, 11110000b
	xor 	bh, bh
	mov 	si, offset gameOverMelody
 @play:
	mov 	di, [si]
	call 	playSound
	
	add 	si, 2
	loop 	@play	
 
 @endMelody:
 	popa
	ret
playMelody endp

playSound proc
	pusha

 	mov 	al, 10110110b 			; установка режима таймера
	out 	43h, al
	
	mov 	dx, 14h 			; делитель времени = 
	mov 	ax, 4f38h 			; 1331000/частота
	div 	di
	out 	42h, al 			; записать младший байт счетчика таймера 2
	
	mov 	al, ah
	out 	42h, al 			; 3аписать старший байт счетчика таймера 2
	
	in 	al, 61h 			; считать текущую установку порта 
	mov 	ah, al 				; и сохранить ее в регистре аh
	or 	al, 00000011b			; включить динамик
	out 	61h, al
		
 @wait1:
	mov 	cx, 2201 			; выждать 10 мс
		
 @play_one_note: 
	loop 	@play_one_note
	
	dec 	bx				; счетчик длительности исчерпан?
	jnz 	@wait1 				; нет  продолжить звучание
	mov 	al, ah 				; да  восстановить исходную установку порта
	out 	61h, al
			
	popa	
	ret 				
playSound endp

tail_delete proc
    pusha
    movzx bx, tail_snake
    shl bx, 1
    movzx cx, byte ptr [offset snake + bx]
    movzx dx, byte ptr [offset snake + bx + 1]
    push 0
    push cx dx
    call pixel
    popa
    ret
tail_delete endp


die_proc proc
    nop
    nop
    pusha
    mov dx, 0126h
    call set_cursor
    mov bl, 15
    mov cx, len_msg_die
    lea si, msg_die
    call print_text
    call playMelody
    ;call draw_life
    popa
    ret
die_proc endp

; bl: color
; cx: len
; si: offset of string
print_text proc
    pusha
    xor bh, bh
	@draw_text:
        mov 	ah, 	0Eh
        lodsb 	; si++ -> al
        int 	10h
	loop 	@draw_text
	popa
	ret
print_text endp

snake_draw proc
    pusha
    movzx bx, head_snake
    shl bx, 1
    movzx cx, byte ptr [offset snake + bx]
    movzx dx, byte ptr [offset snake + bx + 1]
    push 2
    push cx dx
    call pixel
    popa
    ret
snake_draw endp

snake_move proc
	pusha	
	movzx	di,	head_snake
	shl	di,	1
	mov	ax,	snake[di]
	; ax = snake[head_snake]
	
	
	mov	dl,	way_tmp
	mov	way,	dl

	push 	bx

	cmp	way,	0
	jnz	check_way_1
	mov 	bx,	0100h
	call 	dec_rev
	jmp	check_way_end

	check_way_1:
	cmp	way,	1
	jnz	check_way_2
	sub 	ax,	0001h
	jmp	check_way_end

	check_way_2:
	cmp	way,	2
	jnz	check_way_3
	mov 	bx,	0100h
	call 	inc_rev
	jmp	check_way_end

	check_way_3:
	add 	ax,	0001h

	check_way_end:
	;inc	step_way
	pop 	bx

	movzx	cx,	ah
	shl	cx,	3
	add	cx,	len_pixel
	
	movzx	dx,	al
	shl	dx,	3
	add	dx,	30
	
	push	ax
	xor	bh,	bh
	mov	ah,	0Dh
	int	10h
	
	cmp	al,	3
	je	@loop1
	cmp	al,	8
	je	@loop2
	cmp	al,	13
	je	@loop3
	cmp	al,	2
	je	cross
	cmp	al,	14
	jne	next_move

	cross:
		pop	ax
		dec	life
		cmp	life,	0
		jg	call_life
		mov	die,	1
		jmp	end_move
		
	call_life:
		call	new_life
		jmp	end_move
		
	next_move:
		cmp	al,	12
		jnz	@cut	

	@no_cut:	
		add	score,	10	
		call	draw_score
		mov	di,	600
		call	playSound
		inc 	len_snake
		jmp	@after
		
	@loop1:
		cmp 	len_snake, 	1
		je 	cross

		dec 	len_snake 
		call 	next_tail_snake
		call 	tail_delete
		jmp 	@cut

	@loop3:
		pop 	ax
		mov 	ah, 	1
		push 	ax
		jmp 	@cut

	@loop2:
		push 	cx
		mov 	ch,	tail_snake
		mov 	cl, 	head_snake
		mov 	tail_snake, 	cl 	
		mov 	head_snake, 	ch
		pop 	cx

		call 	snake_draw
		call 	tail_delete

		xor 	rev, 	1
		mov 	way, 	2
		mov 	way_tmp, 	2

		pop 	ax
		movzx	di,	head_snake
		shl	di,	1
		mov	ax,	snake[di]
		push 	bx
		mov 	bx,	0100h
		call 	inc_rev
		pop 	bx
		push 	ax

	@cut:
		call 	next_tail_snake
		jmp	@after
		
	
	@after:
		pop	ax
		call 	next_head_snake	
		movzx	di,	head_snake
		shl	di,	1
		add	di,	offset	snake
		;snake[head_snake-1]
		mov	[di],	ax
		
	end_move:

	popa
	ret
snake_move endp

mod_div proc
    push bp
    mov bp, sp
    push bx dx
    xor dx, dx
    mov ax, [bp+4]
    mov bx, [bp+6]
    div bx
    mov ax, dx
    
    pop dx bx
    pop bp
    ret 4
mod_div endp

gen_food proc
	pusha
	call 	randgen
	push 	75
	push 	ax
	call 	mod_div
	add 	ax, 	2
	mov 	cx, 	ax
  
	call 	randgen
	push 	37
	push 	ax
	call 	mod_div
	inc 	ax
	mov 	dx, 	ax
    
	call 	randgen
	push 	3 	ax
	call 	mod_div

	cmp 	ax, 	1
	je  	gen_food_loop1
	cmp 	ax, 	0
	je 	gen_food_loop0
	cmp 	ax, 	2
	je 	gen_food_loop2

	gen_food_loop1:
		push 	12
		jmp 	gen_food_cont

	gen_food_loop0:
		push 	ax 	bx
		mov 	ax, 	dead_food
		mov 	bx, 	max_dead_food
		cmp 	ax, 	bx
		jg 	gen_food_loop01
		pop 	bx 	ax
		inc 	dead_food
		
		push 	14
		jmp 	gen_food_cont

		gen_food_loop01:
			pop 	bx 	ax
			jmp 	gen_food_loop1

	gen_food_loop2:
		push 3
		jmp gen_food_cont

	gen_food_cont:
		push 	dx 	cx
		call 	pixel
	popa
	ret
gen_food endp

score_tab proc
    pusha
    mov dx, 0101h
    call set_cursor
    mov ah, 09h
    mov al, ' '
    mov cx, 5
    xor bx, bx
    int 10h
    popa
    ret
score_tab endp

set_cursor proc
    pusha
    xor bh, bh
    mov ah, 02h
    ;mov dx, 0101h
    int 10h
    popa
    ret
set_cursor endp

draw_steps proc
    pusha
    mov dx, 0131h
    call set_cursor
    mov bl, 13
    mov cx, 6
    lea si, steps_text
    call print_text

    mov dx, 0138h
    call set_cursor
    push 13
    push num_step
    call OutInt
    popa
    ret
draw_steps endp

draw_len proc
    pusha
    mov dx, 0142h
    call set_cursor
    mov bl, 10
    mov cx, 4
    lea si, len_text
    call print_text

    mov dx, 0147h
    call set_cursor
    push 10
    push len_snake
    call OutInt
    popa
    ret
draw_len endp

draw_score proc
    call score_tab
    push 9
    push score
    call OutInt 
    ret
draw_score endp

new_life proc
    pusha
    mov ah, 0h
    mov al, 10h
    int 10h
    mov way, 0
    mov way_tmp, 0
    ; 0 - left, 1 - up, 2 - right, 3 - down

    mov head_snake, 0
    mov tail_snake, 0
    
    call draw_border
    call snake_draw
    
    call draw_score
   ; call draw_life
    
    mov ax, curtime
    add ax, snake_ticks
    mov snake_timer, ax
    
    mov ax, curtime
    add ax, food_ticks
    mov food_timer, ax
    

    
    popa
    ret
new_life endp

start_snake proc
    pusha
    mov score, 0
    mov life, 1
    mov die, 0
    call new_life
    
    popa
    ret
start_snake endp

randgen proc
    or ax, ax ;range value <> 0?
    jz abort
    push bx
    push cx
    push dx
    push ds
    push ax
    push cs
    pop ds
    mov ax, seed1
    mov bx, seed2 ;load seeds
    mov cx, ax ;save seed
    mul constant
    shl cx, 1
    shl cx, 1
    shl cx, 1
    add ch, cl
    add dx, cx
    add dx, bx
    shl bx, 1 ;begin scramble algorithm
    shl bx, 1
    add dx, bx
    add dh, bl
    mov cl, 5
    shl bx, cl
    add ax, 1
    adc dx, 0
    mov seed1, ax
    mov seed2, dx ;save results as the new seeds
    pop bx ;get back range value
    xor ax, ax
    xchg ax, dx ;adjust ordering
    div bx ;ax = trunc((dx,ax) / bx), dx = (r)
    xchg ax, dx ;return remainder as the random number
    pop ds
    pop dx
    pop cx
    pop bx
    abort: ret ;return to caller
randgen endp

OutInt proc
    push bp
    mov bp, sp  
    pusha
    
    mov ax, [bp+4]  
    xor cx, cx
    mov bx, 10
	oi_loop_2:
		xor dx,dx
		div bx

		push dx
		inc cx

		test ax, ax
		jnz oi_loop_2
	oi_loop_3:
    		pop ax
	    	add al, '0'
	    	mov bx, [bp+6]
	    	call print_symbol
	    	loop oi_loop_3

	    	popa
	    	pop bp
	    	ret 4
OutInt endp
; bx: color
; al: symbol
print_symbol proc
    pusha
    
    mov ah, 0Eh
    xor bh, bh
    int 10h
    
    popa
    ret
print_symbol endp

int9:
    pusha
    in al, 60h
    mov di, tail
    mov buffer[di], al
    
    inc tail
    and tail, 0fh
    
    mov ax, head
    cmp tail, ax
    jne @1 ; íå ðàâíû
    inc head
    and head, 0fh
    
@1:
    in al, 61h ; ñ êîíòðîëëåðà êëàâû ÷èñåëêà
    or al, 80h ; óñòàíàâëèâàåì ñòàðøèé áèò
    out 61h, al ; îòïðàâëåì êîíòðîëëåðó
    and al, 07fh ; ñáðàñûâàåì áèò
    out 61h, al ; îòïðàâëåì êîíòðîëëåðó
    ; êîíòðîëëåðó ïðåðûâàíèé ãîâîðèì, ÷òî îáðàáîòàëè ïðåðûâàíèå
    mov al, 20h
    out 20h, al
    popa
    iret
    
int1c:
    inc cs:curtime
    db 0EAh
    oldint1c dd 0
 
@main:
    ; set seeds
    mov ah, 2ch ; time
    int 21h
    xor cx, dx
    mov seed1, cx
    mov seed2, dx
    
    mov ax, 3509h   ; load
    int 21h
    mov word ptr [oldint9], bx   ; offset
    mov word ptr [oldint9+2], es ; segment
    
    cli
        mov ax, 2509h   ; save
        lea dx, int9
        int 21h
    sti
    
    mov ax, 351ch   ; load
    int 21h
    mov word ptr [oldint1c], bx   ; offset
    mov word ptr [oldint1c+2], es ; segment
    
    cli
        mov ax, 251ch   ; save
        lea dx, int1c
        int 21h
    sti
    
    
    ;call menu
    call start_snake
    
@main_loop:
    
	mov ax, tail
	cmp head, ax
	jz @no_keypress ; если ничего не нажали (голова = хвост)
	mov dl, way_tmp 
	cmp dl, way
	jnz @no_keypress ; если текущий путь не совпадает с поставленным

	mov di, head 
	mov al, buffer[di]
	inc head
	and head, 0fh ; складываем в кольце по модулю 16
	cmp al, 01h ; esc нажали - выходим
	jz @end_loop
	cmp al, 0dh ; нажали плюсик
	je inc_speed
	cmp al, 0ch ; нажали минус
	je dec_speed
	cmp al, 9ch ; нажали пробел когда умерли - новая игра
	jnz check_space
	cmp die, 1 ; умерли?
	jnz check_space
	call start_snake ; да - заново начали
	jmp @main_loop

	check_space:
	cmp al, 0b9h ; пробел нажали - приостановить игру
	jnz @next

	xor pause_, 1 ; нажали пробел - приостановили
	jmp @next
	inc_speed: 
	mov cx, snake_ticks
	cmp cx, 1
	jg @incc
	jmp @next
	@incc:
	mov cx, snake_ticks
	dec cx
	mov snake_ticks, cx 
	jmp @next
	dec_speed:
	mov cx, snake_ticks
	cmp cx, 10
	jl @decc
	jmp @next
	@decc:
	mov cx, snake_ticks
	inc cx
	mov snake_ticks, cx 
	@next:
	cmp al, 4bh ; стрелка влево
	jnz arrow_1
	cmp way, 2 ; нажали вправо? ничего не изменилось
	jz @no_keypress
	mov way_tmp, 0

	arrow_1:
	cmp al, 48h ; стрелка вверх
	jnz arrow_2
	cmp way, 3 ; нажали вниз? ничего не изменилось
	jz @no_keypress
	mov way_tmp, 1

	arrow_2:
	cmp al, 4dh ; стрелка вправо
	jnz arrow_3
	cmp way, 0
	jz @no_keypress
	mov way_tmp, 2

	arrow_3:
	cmp al, 50h ; стрелка вниз
	jnz @no_keypress
	cmp way, 1
	jz @no_keypress
	mov way_tmp, 3

	@no_keypress:
	cmp pause_, 1 ; была нажата пауза - идем сначала
	jz @main_loop
	cmp die, 1 ; умерли - идем сначала
	jz @main_loop

	mov ax, curtime 
	cmp food_timer, ax ; пришло время генерить еду
	ja @no_food_draw ; нет - не рисуем
	mov ax, curtime 
	add ax, food_ticks ; прибавили к текущему времени интервал, с которым нужно генерить еду
	mov food_timer, ax
	call gen_food ; и генерим ее 
	@no_food_draw: 
	mov ax, curtime ; нужно перерисовывать змею?
	cmp snake_timer, ax
	ja @no_snake_draw
	mov ax, curtime
	add ax, snake_ticks
	mov snake_timer, ax

	inc num_step
	call tail_delete 
	call snake_move 
	call snake_draw
	call draw_steps 
	call draw_len

	cmp die, 1 ; змея сдохла?
	jnz @no_snake_draw 
	call die_proc ; да!
	@no_snake_draw: 
	jmp @main_loop
	@end_loop:
	; организовать выход в менюшку

	mov ax, 10h ; графика 640x350
	int 10h
	mov ax, 3 ; текст 80x25
	int 10h

	cli
	mov ax, 2509h ; подменяем старые прерывания
	lds dx, cs:oldint9
	int 21h
	sti
	cli
	mov ax, 251ch 
	lds dx, cs:oldint1c
	int 21h
	sti
	@endd:
	ret
cseg ends
end @entry