org 0x7C00
bits 16

%define ENDL 0x0D, 0x0A

;
; FAT12 header
;
jmp short start
nop

bdb_oem:			db 'MSWIN4.1'	; 8 bytes
bdb_bytes_per_sector:		dw 512
bdb_sectors_per_cluster:	db 1
bdb_reserved_sectors:		dw 1
bdb_fat_count:			db 2
bdb_dir_entries_count:		dw 0E0h
bdb_total_sectors:		dw 2880		; 2880 * 512 = 1.44MB
bdb_media_descriptor_type:	db 0F0h		; F0 = 3.5" floppy disk
bdb_sectors_per_fat:		dw 9		; 9 sectors/fat
bdb_sectors_per_track:		dw 18
bdb_heads:			dw 2
bdb_hidden_sectors:		dd 0
bdb_large_sector_count:		dd 0

; extended boot record
ebr_drive_number:		db 0		; 0x00 floppy, 0x80 hdd, useless
				db 0		; reserved
ebr_signature:			db 29h
ebr_volume_id:			db 12h, 34h, 56h, 78h	; serial number, does not matter
ebr_volume_label:		db 'BrOS       '	; 11 bytes, padded with spaces
ebr_system_id:			db 'FAT12   '		; 8 bytes


;
; Code goes here:
;

start:
	; setup data segments
	mov ax, 0	; can't write to ds/es directly
	mov ds, ax
	mov es, ax

	; setup stack
	mov ss, ax
	mov sp, 0x7C00	; stack grows downwards from where we are loaded in memory

	; some BIOSes start at 07C0:0000 instead of 0000:7C00, make sure we are at the expected location
	push es
	push word .after
	retf


.after:

	; read something from floppy disk
	; BIOS should set DL to drive number
	mov [ebr_drive_number], dl

	; Print loading message
	mov si, msg_loading	
	call puts

	; read drive parameters, sectors per track and head count with BIOS
	push es
	mov ah, 08h			; Getting amount of heads and sectors with int 13h ah8
	int 13h
	jc floppy_error
	pop es


	and cl, 0x3F			; remove top 2 bits
	xor ch, ch
	mov [bdb_sectors_per_track], cx	; Sector count
	
	inc dh
	mov [bdb_heads], dh		; head count

	; LBA of root directory = RESERVED + FILE ALLOCATION TABLE * Amount of Sectors per FILE ALLOCATION TABLE
	mov ax, [bdb_sectors_per_fat]	
	mov bl, [bdb_fat_count]		; 
	xor bh, bh
	mul bx				; ax = FILE ALLOCATION TABLE * Amount of Sectors per FILE ALLOCATION TABLE
	
	add ax, [bdb_reserved_sectors]	; ax = LBA of ROOT DIRECTORY
	push ax


	; Calculate the size of ROOT DIRECTORY, one entry is 32 bytes = (32 bytes * number of entries) / bytes per SECTOR
	mov ax, [bdb_dir_entries_count]	
	shl ax, 5			; ax *= 32
	xor dx, dx			; dx = 0 
	div word [bdb_bytes_per_sector]	; number of SECTORS we need to read

	test dx, dx			; If the remainder is not 0 add 1
	jz .root_dir_after
	inc ax				; Adding when when remainder is not 0, which indicates we have a SECTOR only partially filled with entries	


.root_dir_after:
	; read ROOT DIRECTORY
	mov cl, al			; al =  number of SECTORS to read, which is the size of the ROOT DIRECTORY
	pop ax				; ax = LBA of root directory
	mov dl, [ebr_drive_number]	; dl = drive number
	mov bx, buffer			; es:bx = buffer
	call disk_read

	; Search for kernel.bin
	xor bx, bx			; bx used to store count how many entries we already compared
	mov di, buffer			; points to the current directory entry




.search_kernel:
	mov si, file_kernel_bin
	mov cx, 11			; Compare up to 11 characters (length of filenames)
	push di
	repe cmpsb			; Repeat string instruction while operands are equal(zero flag = 1) or until cx is 0, cx is decremented on each iteration
					; Compare string bytes located at ds:si and es:di, si and di: incremented when direction flag = 0, decremented when direction flag = 1

	pop di				; Restore value
	je .found_kernel		; Jump if strings are equal

	add di, 32			; Moving to the next directory entry
	inc bx				; Increase checked directory entry count
	cmp bx, [bdb_dir_entries_count]	; Validate if there are more entries to check
	jl .search_kernel		; If the count of checked directories is less than the available -> repeat

	; Kernel not found
	jmp kernel_not_found_error

.found_kernel:

	; di has the address to the entry
	mov ax, [di + 26]		; First logical cluster field which has a 26 offset
	mov [kernel_cluster], ax	; Saving the first cluster

	; load FILE ALLOCATION TABLE from disk into memory and setting parameters for disk_read
	mov ax, [bdb_reserved_sectors]	
	mov bx, buffer
	mov cl, [bdb_sectors_per_fat]
	mov dl, [ebr_drive_number]
	call disk_read
	
	; Reading kernel and processing the FILE ALLOCATION TABLE chain
	mov bx, KERNEL_LOAD_SEGMENT
	mov es, bx
	mov bx, KERNEL_LOAD_OFFSET

.load_kernel_loop:

	; Reading next cluster 
	mov ax, [kernel_cluster]

	; HARDCODED FOR NOW
	add ax, 31 			; First cluster = (kernel_cluster - 2) * Amount of sectors per cluster + start_sector

	mov cl, 1
	mov dl, [ebr_drive_number]
	call disk_read

	add bx, [bdb_bytes_per_sector]

	; Calculate the location of the next cluster
	mov ax, [kernel_cluster]
	mov cx, 3
	mul cx
	mov cx, 2
	div cx				; ax = byte index of next entry in FILE ALLOCATION TABLE, dx = cluster mod 2

	mov si, buffer
	add si, ax
	mov ax, [ds:si]			; Get entry from FILE ALLOCATION TABLE at byte index ax

	or dx, dx			; Checking if even or odd
	jz .even

.odd:
	shr ax, 4			; Shifting to the right by 4 to get the 12 bits we need
	jmp .next_cluster_after

.even:
	and ax, 0x0FFF

.next_cluster_after:
	cmp ax, 0x0FF8			; Check if it is the end of the cluster chain (ax>0x0FF8)
	jae .read_finish		; Jump if above or even

	mov [kernel_cluster], ax	; If not, there are more clusters -> Jump to load_kernel_loop
	jmp .load_kernel_loop

.read_finish:

	; jump to our kernel
	mov dl, [ebr_drive_number]	; boot device in dl

	mov ax, KERNEL_LOAD_SEGMENT	; Setting segment registers
	mov ds, ax			; Setting up data registers
	mov es, ax

	jmp KERNEL_LOAD_SEGMENT:KERNEL_LOAD_OFFSET	; Far jump to the kernel
	
	jmp wait_key_and_reboot		; Shouldnt happen!
	
	cli				; disable interrupts
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



;
; Error handlers
;
floppy_error:
	mov si, msg_read_failed
	call puts
	jmp wait_key_and_reboot

kernel_not_found_error:
	mov si, msg_kernel_not_found
	call puts
	jmp wait_key_and_reboot

wait_key_and_reboot:
	mov ah, 0
	int 16h				; waits for keypress
	jmp 0FFFFh:0			; jump to beginning of bios, should reboot

.halt:
	cli				; disable interrupts, so CPU can not get out of "halt" state
	hlt


;
; Disk routines
;



;
; Converts an LBA address to a CHS address
; Parameters:
;	- ax: LBA address
; Returns:
;	- cx [bits 0-5]: sector number
;	- cx [bits 6-15]: cylinder
;	- dh: head

lba_to_chs:
	
	push ax
	push dx

	xor dx, dx				; dx = 0, clears dx
	div word [bdb_sectors_per_track]	; ax = LBA / SectorsPerTrack
						; dx = LBA % SectorsPerTrack

	inc dx					; dx = LBA % SectorsPerTrack + 1 = sector
	mov cx, dx				; cx = sector

	xor dx, dx				; dx = 0, clears dx
	div word [bdb_heads]			; ax = (LBA / SectorsPerTrack) / Heads = cylinder
						; dx = (LBA / SectorsPerTrack) % Heads = head
	mov dh, dl				; dh = head
	mov ch, al				; ch = cylinder (lower 8 bits)
	shl ah, 6
	or cl, ah				; put upper 2 bits of cylinder in CL

	pop ax
	mov dl, al				; restore DL
	pop ax
	ret


;
; Reads sector from a disk
; Parameters:
;	- ax : LBA address
;	- cl: number of sectors to read (up to 128)
;	- dl: drive number
;	- es:bx: memory address where to store read data
;
disk_read:

	push ax					; save registers we will modify
	push bx
	push cx
	push dx
	push di



	push cx					; temporarily save CL (number of sectors to read)
	call lba_to_chs				; compute CHS
	pop ax					; AL = number of sectors to read

	mov ah, 02h
	mov di, 3				; retry count

.retry:
	pusha					; save all registers, we do not know what bios modifies
	stc					; set carry flag, as some BIOs do not set it
	int 13h					; carry flag cleared = success
	jnc .done				; jump if carry not set

	; read failed
	popa
	call disk_reset
	
	dec di
	test di, di				; If di is not yet 0 we jump back to retry
	jnz .retry


.fail:
	; after all attempts failed
	jmp floppy_error




.done:
	popa

	pop di
	pop dx
	pop cx
	pop bx
	pop ax					; restore registers modified
	ret



;
; Resets disk controller
; Parameters:
;	dl: drive number
;
disk_reset:
	pusha
	mov ah, 0
	stc
	int 13h
	jc floppy_error
	popa
	ret





msg_loading: 		db 'Bro, I load...', ENDL, 0
msg_read_failed: 	db 'READ failed bro', ENDL, 0
msg_kernel_not_found:	db 'Bro where kernel lol', ENDL, 0
file_kernel_bin:	db 'KERNEL  BIN'
kernel_cluster:		dw 0

KERNEL_LOAD_SEGMENT	equ 0x2000
KERNEL_LOAD_OFFSET	equ 0

times 510-($-$$) db 0
dw 0AA55h

buffer:
