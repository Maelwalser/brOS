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
	push dx
	push ax

	xor dx, dx				; Clearing dx
	div word [bdb_sectors_per_track]	; ax:dx(LBA) / bdb_sectors_per_track = ax, dx remainder
	
	inc dx					; Remainder + 1 = sector
	mov cx, dx				; Saving sector number to cx


	xor dx, dx				; Clearing dx
	div word [bdb_heads]			; ax:dx(LBA) / bdb_sectors_per_track / heads = cylinder number stored in ax, remainder stored in dx which equals to number of heads

	mov dh, dl				; Moving thee 8 lower bits of DX (dl) to the 8 higher bits (dh) -> head number
	mov ch, al				; Moving th 8 lower bits of AX(al) to the 8 higher bits of CX(ch)-> cylinder lower 8 bits


	shl ah, 6				; shifting the 8 higher bits of ah to the left by 6 bits to get the 2 lowest bits to bit 6 and 7 (0 indexed)
	or cl, ah				; Putting the 2 bits into ah

	pop ax
	pop dx
	ret


; Reads a Sector from a disk
; Parameters:
;	- ax: LBA address
;	- cl: number of sectors to read (up to 128)
;	- dl: drive number
;	- es:bx: memory address where to store read data
disk_read:
	; saving register we will modify 
	push ax
	push bx
	push cx
	push dx
	push di


	push cx
	call lba_to_chs		; Getting CHS address
	pop ax	



	mov ah, 02h
	mov di, 3		; Retry counter

.retry:

	pusha			; saving registers
	stc			; Setting carry flag
	int 13h			; BIOS disk access interrupt
	jnc .done		; If no carry = success

	; read failed		
	popa	
	call disk_reset

	dec di			; Decrease the retry counter by 1
	test di, di		; Check if retries left
	jnz .retry		; Retry if counter not 0

.fail:
	jmp floppy_error

.done:

	popa

	pop di
	pop dx
	pop cx
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
	call puts
	jmp .halt

.halt:
	cli
	hlt


section .data
msg_read_failed: db 'Mission READ failed bro', 0

; Disk parameters for 1.44MB floppy

bdb_sectors_per_track: dw 18

bdb_heads: dw 2

