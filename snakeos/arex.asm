[bits 16]
; [org 0x7c00]
diff: equ 4 ; przyrost wonsza
len: equ 8 ; poczatkowa dlugosc
head: equ 1 ; obrazek glowy
tail: equ '#' ; obrazek ogona
food: equ 5 ; obrazek jedzenia
intval: equ 100000 ; czas czekania [us]
haltw8: equ 3000000 ; czas czekania [us]

%macro sleep 1
	mov ah,86h
	mov cx,%1 >> 16
	mov dx,0xffff&%1
	int iCtrl
%endmacro

; interrupt nums
iScreen: equ 10h
iCtrl: equ 15h
iKbd: equ 16h

entry:
  mov ax,cs
  xor ax,ax
  jnz .xdd
  mov ax,0x7c0
  .xdd:
  mov ds,ax
  mov es,ax
  mov bh,0
  push accept
  call puts
  pop cx
  mov ah,1
  mov cx,0706h ; hide cursor
  int iScreen

  mov ch, 1
  mov cl, 0
  mov dh, 23
  mov dl, 79
  call ramka

  mov ah, 2
  mov dh, 9 ;2
  mov dl, 9 ;1
  int iScreen

  mov al,food
  call putchar

  ; mov dh, 0 ; ypoz
  ; mov dl, 0 ; xpoz
  xor dx,dx
  xor bp,bp

  mov cx,0x2064 ; 'd'
  push cx
  mov si,buffer
  mov di,initl

  .lp:
	call spos

	mov ax,dx
	stosw
	cmp di,ende
	jl .s1
	sub di,ende-buffer
	.s1:

	mov ah,8
	int iScreen
	cmp al,tail
	je exit
	cmp al,food
	jne .sss
	; snake ate food!
	inc bp
	push cx
	std
	mov cx,diff
	.ll:
	  lodsw
	  cmp si,buffer
	  jg .s00
	  add si,ende-buffer
	  .s00:
	  mov [si],ax
	loop .ll
	cld
	pop cx

	push dx
	.foodpl:
	  ; here the randomization takes place
	  add dl,dh
	  add dh,dh
	  sub dh,5
	  ; end of random
	  call spos
	  mov ah,8
	  int iScreen
	cmp al,20h
	jne .foodpl
	mov al,5
	call putchar

	pop dx
	call spos

	.sss: ; snake is sliding on
	mov al,head
	call putchar

	push cx
	lodsw
	cmp si,ende
	jl .s0
	sub si,ende-buffer
	.s0:
	push dx
	mov dx,ax
	call spos
	mov al,20h
	call putchar

	sleep(intval)
	hlt
	pop dx
	pop cx
	call spos

	mov ah,1
	int iKbd
	pop ax
	jz .sk

	mov cx,ax
	mov ah,0
	int iKbd

	.sk:
	push ax
	mov al,tail
	call putchar

	pop ax
	push ax

	.redo:
	  cmp ah,10h ; 'q'
	  je  exit
	  cmp ah,11h ; 'w'
	  je  .w
	  cmp ah,1Fh ; 's'
	  je  .s
	  cmp ah,1Eh ; 'a'
	  je  .a
	  cmp ah,20h ; 'd'
	  je  .d
	  mov ax,cx
	jmp .redo
	.w:
	dec dh
	jmp .lp
	.s:
	inc dh
	jmp .lp
	.a:
	dec dl
	jmp .lp
	.d:
	inc dl
	jmp .lp

exit:
  mov ch, -1
  mov cl, -1
  mov dh, 24
  mov dl, 80
  call ramka ; clear the screen

  mov ah, 2
  mov dh, 12
  mov dl, 30
  int iScreen
  push halted
  call puts
  mov ax, bp
  aam
  add ax, 0x3030
  xchg ah,al
  mov di, buffer
  mov [di], ax
  mov [di+2], byte 0
  push di
  call puts

  sleep(haltw8)

  ; int 18h
  ; call puts

  ; mov ax,5304h ; APM disconnect
  xor bx,bx ; BIOS dev id = 0
  inc bx
  ; int iCtrl

  ; mov ax,5301h ; APM connect
  ; int iCtrl

  ; mov ax,530Eh ; APM driver version set [required for poweroff]
  ; mov cx,0102h ; 1.2
  ; int iCtrl

  mov ax,5307h ; APM set power state
  ; inc bx ; all dev id = 1
  mov cx,3 ; poweroff
  int iCtrl

  ; TODO: ACPI poweroff
  ; mov dx,0xB004 ; ACPI I/O port (?)
  ; mov ax,0x2000 ; ACPI poweroff (?)
  ; out dx,ax

hang: hlt
  jmp hang

spos:
  sub dh,21
  jge .x
  add dh,21
  jge .x
  add dh,21
.x:
  sub dl,78
  jge .y
  add dl,78
  jge .y
  add dl,78
.y:
  mov ah,2
  add dh,2
  inc dl
  int iScreen
  sub dh,2
  dec dl
  ret

; putchar(register char& al char)
putchar:
  mov bl,0Fh

; cputchar(register char& al char, register char& bl color)
cputchar:
  mov ah,0Eh
  int iScreen
  ret

; puts(stack char*)
puts:
  push bp
  mov bp,sp
  mov si,[bp+4]
  .lp:
  lodsb
  cmp al,0
  jne .l2
  leave
  ret
  .l2:
  push si
  call putchar
  pop si
  jmp .lp

; ramka(reg& ch top, reg& cl left, reg& dh bot, reg& dl rig)
ramka:
  push bp
  mov bp,sp

  push cx
  push dx
  push byte (219-256)
  call chramka

  pop ax
  mov cx,[bp-2]
  mov dx,[bp-4]
  inc ch
  inc cl
  dec dh
  dec dl
  push byte ' '
  call chramka

  leave
  ret

; chramka(stack char, reg& ch top, reg& cl left, reg& dh bot, reg& dl rig)
chramka:
  push bp
  mov bp, sp
  xchg dx,cx
  push dx
  .lp:
  mov dl,[bp-2]
  mov ah, 2
  int iScreen
  mov al,[bp+4]

  .lp2:
  call putchar
  inc dl
  cmp cl,dl
  jge .lp2

  inc dh
  cmp ch,dh
  jge .lp
  leave
  ret

; const stuff
accept: db "ArOS 3",0
halted: db "Game Over. Score: ",0
buffer:
TIMES len dw 0x144d
initl:
; auto padding
TIMES 510 - ($ - $$) db 0
dw 0xAA55
ende: equ $+50
