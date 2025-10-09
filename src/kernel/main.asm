org 0x0
bits 16

%define ENDL 0x0D, 0x0A

%include "drivers/keyboard.asm"


; Code from here until .data
section .text

start:

	; print message
	mov si, msg_hello	
	call puts
	call print_newline



.shell_loop:
	mov si, msg_prompt
	call puts

	; Read line from the user
	call read_string


	; Echo the input back
	mov si, di
	call puts
	call print_newline
	call print_newline
	jmp .shell_loop


.halt:
	cli
	hlt

;Prints a string to the screen.
;Params:
;	-ds:si points to string
;
puts:
	; save registers we will modify
	push si
	push ax

.loop:
	lodsb		; loads next character in al
	or al, al	; verify if next character is null with bit or operation setting flag
	jz .done	; jumps to done if zero flag is set

	mov ah, 0x0e	; call bios interrupt
	mov bh, 0
	int 0x10

	jmp .loop	; looping

.done:
	pop ax
	pop si
	ret



print_newline:
	pusha
	mov ah, 0x0e
	mov al, 0x0D	; Carriage return
	int 0x10
	mov al, 0x0A	; Line feed
	int 0x10
	popa
	ret



section .data


msg_hello: db 'HELLO TO MY WORLD BRO', ENDL, 0

msg_prompt: db '> ', 0
