bits 16

section .text





;
; Converts an LBA addres to a CHS adress
; Parameters:
; - ax: LBA address
; Returns:
; - cx [bits 0-5]: sector number
; - cx [bits 6-15]: cylinder number
; - dh: head
lba_to_chs:
	; Pushing modified registers to the stack
	push ax
	push dx


	
	xor dx, dx				; Clearing dx
	div word [bdb_sectors_per_track]	; ax:dx(LBA) / bdb_sectors_per_track = ax, dx remainder
	
	inc dx					; Remainder + 1 = sector
	mov cx, dx				; Saving sector number to cx



	xor dx, dx				; Clearing dx
	div word [bdb_heads]			; ax:dx(LBA) / bdb_sectors_per_track / heads = cylinder number stored in ax, remainder stored in dx which equals to number of heads

	mov dh, dl				
	mov ch, al				; Moving th 8 lower bits of AX to the 8 higher bits of CX


	shl ah, 6
	or cl, ah
	pop ax

	mov dl, al

	pop ax

	ret




disk_read:

	push ax
	push bx
	push cs
	push dx
	push di



	push cx					;

	call lba_to_chs

	pop ax	

	mov ah, 02h








.retry:
	pusha
	stc
	int 13h
	jnc .done


	popa
	call disk_reset



.fail:
	jmp floppy_error






.done:

	popa

	pop di
	pop dx
	pop cs
	pop bx
	pop ax
	ret




disk_reset:
	pusha
	mov ah, 0
	stc
	int 13h
	jc floppy_error
	popa
	ret



;
; Error handlers
;
floppy_error:
	mov si, msg_read_failed




section .data
	msg_read_failed:	db 'Mission Read failed bro'



