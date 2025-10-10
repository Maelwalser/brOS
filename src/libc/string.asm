bits 16

section .text

; Compares two null terminated strings for equality
; Parameters:
; - si: Pointer to the first null-terminated string
; - di: Pointer to the second null-terminated string
;
; Output:
; - Sets zero flag (ZF) if the strings are equal
; - Clears the zero flag (ZF) if they are not equal
; - Registers ax, si, di are modified
compare_strings:
	push ax 	; Save ax register

.loop:
	mov al, [si]	; Get character from the first string
	mov ah, [di]	; Get character from the first string

	cmp al, ah	; Compare the characters
	jne .done	; Characters not equal

	cmp al, 0	; Check if the character is a null terminator
	je .done	; if the characters equal and end of string -> equal and zero flag (ZF) set

	; Not the end of the string character
	inc si		; Get next character for string pointed to by si
	inc di		; Get next character for string pointed to by di
	jmp .loop


.done:
	pop ax		; Restore register ax (al and ah)
	ret
