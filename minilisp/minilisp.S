.intel_syntax noprefix
SYS_exit = 60
SYS_getpid = 39
SYS_kill = 62
SYS_write = 1
SIGABRT = 6

.extern display
// r12 holds pointer to argv[0]

// objects are pointers to either strings or objects
// [obj]	car
// [obj+8]	cdr

.section .text
.global abort
.type abort,@function
abort:
	mov rax, SYS_getpid
	syscall
	mov rdi, rax
	mov rsi, SIGABRT
	mov rax, SYS_kill
	syscall
	mov rdi, rax
	jmp exit
.size abort,.-abort

.global nextc_lstrip
.type nextc_lstrip,@function
nextc_lstrip:
	lodsb
	test al,al   // premature EOS
	jz abort
	cmp al,' '
	jle nextc_lstrip     // lstrip
	ret
.size nextc_lstrip,.-nextc_lstrip

.global swallow
.type swallow,@function
swallow:
	lodsb
	cmp al,'('
	je .endi
	cmp al,')'
	je .endi
	cmp al,' '
	jg swallow
.endi:
	dec rsi
	ret
.size swallow,.-swallow

.global displaystring
.type displaystring,@function
displaystring:
	mov rsi,rdi
	call swallow
	sub rsi,rdi
	mov rdx,rsi
	mov rsi,rdi
	mov rdi,1
.size displaystring,.-displaystring
.global write
.type write,@function
write:
	mov eax, SYS_write
	syscall
	ret
.size write,.-write

.global main
.type main,@function
main:
	cmp rdi,2
	jne exit
	lodsq
	mov r12, rax
	lodsq
	mov rsi,rax
	call sexpr

	mov rdi, rax
	mov rsi, r12
	call display

	xor edi,edi
	jmp exit
.size main,.-main

// rsi = null-terminated expression
// can allocate returned object on stack
// returns pointer to object in rax, advances rsi
// should return either pointer to string, or allocate a pair, and return previous stack pointer
sexpr:
	push rsi
	call nextc_lstrip  // updates rsi
	cmp al,'('
	je paren
	call swallow  // updates rsi
	pop rax
	ret

paren:
// frame:
// [rbp+16]	saved rip
// [rbp+8]	saved rbx
// [rbp]	saved rbp
	mov [rsp],rbx
	push rbp
	mov rbp,rsp
	xor ebx,ebx
1:
	call nextc_lstrip  // updates rsi
	cmp al,')'
	je 2f

	mov rbx, rsp
	dec rsi
	call sexpr  // updates rsi

	cmp rbx, rsp
	jne havespace

	sub rsp, 16
havespace:
	sub rbx, 16
	mov [rbx], rax
	lea rax, [rsp-16]
	mov [rbx+8], rax
	jmp 1b

2:
	test rbx,rbx
	jz 1f
	mov qword ptr [rbx+8], 0
	lea rax, [rbp-16]
	jmp 2f
1:
	xor eax,eax
2:
	mov rbx, [rbp+8]
	mov r11, [rbp+16]
	mov rbp, [rbp]
	jmp r11

.global _start
.type _start,@function
_start:
	pop rdi
	mov rsi,rsp
	call main
.size _start,.-_start
.global exit
.type exit,@function
exit:
	mov rax, SYS_exit
	syscall
.size exit,.-exit

// vi: ft=asm
