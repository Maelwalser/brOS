; ----------------------------------
; Screen output functions.
; ----------------------------------

; Making the puts lable visible to other files at link time
GLOBAL puts, print_newline

; Prints a string to the screen
; Params:
; 	- ds:si points to the string
; Clobbers:
;	- ax
puts:
	; Saving register we will modify
	push si
	push ax
.loop:
	lodsb		; Load byte from di:si into al, and increment si
	or al, al	; Check if the byte is zero (end of string)
	jz .done	; Jump to done if 0
	; Else
	mov ah, 0x0e	; BIOS teletype output function
	mov bh, 0	; Video page 0
	int 0x10	; Call BIOS interrupt
	jmp .loop	; Repeat for next character


.done:
	pop ax
	pop si
	ret



; Prints a newline character to the screen
; Clobbers:
;	- ax, bx
print_newline:
	pusha		; Saving all registers
	mov ah, 0x0e
	mov bh, 0	; Screen
	mov al, 0x0D	; Carriage return
	int 0x10
	mov al, 0x0A	; Line feed
	int 0x10
	popa
	ret
