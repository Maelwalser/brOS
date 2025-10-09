bits 16

section .text

; Reads a line of text from the keyboard until Enter is pressed
; Input is stored in keyboard_buffer
;
; Output:
; - di: Points to the start of the null-terminated string in keyboard_buffer
; - cx: Contains the length of the string

read_string:
	pusha
	mov di, keyboard_buffer	; Set di to the start of our buffer

.loop:
	mov ah, 0x00	; BIOS wait for keystroke function
	int 0x16	; BIOS keyboard interrupt

	; AL contains the ASCII code of the key pressed

	cmp al, 0x08	; Check if keypress is Backspace (ASCII 0x08)
	je .backspace

	cmp al, 0x0D	; Check if keypress is Enter (ASCII 0x0D)
	je .done

	; Prevent buffer overflow
	mov cx, di	; Save pointer to current position in buffer to cx
	sub cx, keyboard_buffer	; Get the offset of the current position
	cmp cx, KEYBOARD_BUFFER_SIZE - 1	; Check if we arrived at the end of our buffer
	je .loop


	; It is a printabe character
	mov [di], al	; Store character in our buffer
	inc di		; Move to the next position in the buffer


	; Echo the character to the screen
	mov ah, 0x0E	; BIOS teletype output function
  mov bh, 0
	int 0x10	; BIOS video interrupt

	jmp .loop	; Loop and wait for nex character

.backspace:
	; Check if we are at the beginning of the buffer
	cmp di, keyboard_buffer
	je .loop		; If yes, wait for next key
	
	; Not at the beginning of the buffer -> Can backspace
	dec di			; Move back one character in the buffer

	; Update the screen to remove character
	mov ah, 0x0E	; BIOS teletype output function

	mov bh, 0	; Setting video page
	mov al, 0x08	; Backspace character
	int 0x10	; BIOS video interrupt

	mov al, ' '	; Overwrite with a space
	int 0x10	; BIOS video interrupt

	mov al, 0x08	; Move cursor back again
	int 0x10	; BIOS video interrupt

	jmp .loop

.done:
	; Null terminate the string	
	mov byte [di], 0

	; Add a newline to the screen
	mov ah, 0x0E
	mov bh, 0	; Setting video page
	mov al, 0x0D	; Carriage return
	int 0x10
	mov al, 0x0A	; Line feed
	int 0x10

	; Calculate string length
	mov dx, di
	sub dx, keyboard_buffer	; dx = length (di - start adress)

	popa		; Restore all registers

	; Set di to point to the beginning of the string for the calller
	mov di, keyboard_buffer
	mov cx, dx

	ret

section .bss
; Defines Buffer for keyboard input
KEYBOARD_BUFFER_SIZE equ 256
keyboard_buffer: resb KEYBOARD_BUFFER_SIZE
