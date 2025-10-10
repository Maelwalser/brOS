org 0x0
bits 16

%define ENDL 0x0D, 0x0A



; Code from here until .data
section .text

start:

	; print welcome message
	mov si, msg_hello	
	call puts
	call print_newline


.shell_loop:
	mov si, msg_prompt
	call puts

	; Read line from the user
	call read_string	; Calls read_string in drivers/keyboard.asm, Resulting pointer in di



	; -- Command Processing Logic --

	; Check if command is 'bro go'
	mov si, keyboard_buffer
	mov di, command_open_directory
	call compare_strings
	je .cmd_open_directory
	
	; Check if command is 'bro where'
	mov si, keyboard_buffer	
	mov di, command_show_current_dir
	call compare_strings
	je .cmd_show_current_dir

	; Everything else unknown	
	jmp .unknown_command


.cmd_open_directory:
	mov si, msg_cmd_go
	call puts
	jmp .shell_loop_end

.cmd_show_current_dir:
	mov si, msg_cmd_where
	call puts
	jmp .shell_loop_end

.unknown_command:
	mov si, msg_unknown
	call puts	
	jmp .shell_loop_end

.shell_loop_end:
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
	mov bh, 0	; Screen
	mov al, 0x0D	; Carriage return
	int 0x10
	mov al, 0x0A	; Line feed
	int 0x10
	popa
	ret


%include "kernel/drivers/keyboard.asm"
%include "libc/string.asm"

section .data


msg_hello: db 'HELLO TO MY WORLD BRO', ENDL, 0
msg_prompt: db '> ', 0

; Command Strings
command_open_directory:	db 'bro go', 0
command_show_current_dir:	db 'bro where', 0

; Command Responses
msg_cmd_go:	db 'I am going bro', 0
msg_cmd_where:	db 'I am searching bro', 0
msg_unknown:	db 'IDK bro...', 0

