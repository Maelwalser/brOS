org 0x0
bits 16

%define ENDL 0x0D, 0x0A



; Code from here until .data
section .text

start:

	; Setting up segmented registers to point to our code segment
	mov ax, cs
	mov ds, ax
	mov es, ax

	; Setting up stack
	mov ss, ax
	mov sp, 0x9000	; 


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


	; Check if command is 'bro help'
	mov si, keyboard_buffer
	mov di, command_help
	call compare_strings
	je .cmd_help


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

.cmd_help:
	mov si, msg_help
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


%include "libc/stdio.asm"
%include "kernel/drivers/keyboard.asm"
%include "libc/string.asm"

section .data


msg_hello: 			db 'WELCOME TO MY WORLD BRO', ENDL, 0
msg_prompt:			db '> ', 0

; Command Strings
command_open_directory:		db 'bro go', 0
command_show_current_dir:	db 'bro where', 0
command_help:			db 'bro help', 0

; Command Responses
msg_cmd_go:			db 'I am going bro', 0
msg_cmd_where:			db 'I am searching bro', 0
msg_unknown:			db 'IDK what you are talking about bro...', 0
msg_help:			db 'Looks like a you problem', 0

