bits 16

section .text


; Loads the FAT12 filesystem into memory
; 
fat12_init:
	pusha

	mov ax, [bdb_reserved_sectors]
	mov bx, fat_buffer
	mov cl, [bdb_sectors_per_fat]
	mov dl, [ebr_drive_number]
	call disk_read

	mov word [current_dir_cluster], 0	; 0  = ROOT DIRECTORY
	mov byte [current_dir_is_root], 1

	popa
	ret

fat12_list_directory:
	pusha


	; Check if we are in root directory
	cmp byte [current_dir_is_root], 1
	je .list_root


	; Else list subdirectory
	jmp .list_subdir



.list_root:
	; Getting the size of the FILE ALLOCATION TABLE IN SECTORS
	mov ax, [bdb_sectors_per_fat]
	mov bl, [bdb_fat_count]
	xor bh, bh			; Zeroing out upper 8 bits of bx to make sure we multiply bl only
	mul bx				; ax * bx (sectors per fat * fat count)
	
	; Adding the size of the RESERVED region to get the start of the ROOT DIRECTORY
	add ax, [bdb_reserved_sectors]	; Adding the RESERVED region


	; Getting the size of the ROOT DIRECTOY, one entry is 32 bytes -> 32 * entries count = size in bytes
	mov ax, [bdb_dir_entries_count]	; Amount of entries in the ROOT DIRECTORY
	shl ax, 5			; Shifting ax 5 bits to the left, which is equal to multiplying it by 32 (2^5 = 32)
	xor dx, dx			; zeroing out the dx register for storing remainder
	div word [bdb_bytes_per_sector]	; AX(bdb_dir_entries) / bytes_per_sector = amount of sectors in ROOT DIRECTORY, Result is stored in AL
	test dx, dx			; Checking if the remainder is not 0
	jz .root_dir_after
	inc ax				; Rounding up amount of sectors if there are partially filled sectors


.root_dir_after:
	; read ROOT DIRECTORY

	push ax				; Save sector count
	mov ax, [bdb_sectors_per_fat]
	mov bl, [bdb_fat_count]
	xor bh, bh
	mul bx
	add ax, [bdb_reserved_sectors]

	pop cx				; Sector count in cl
	mov bx, dir_buffer
	mov dl, [ebr_drive_number]
	call disk_read

	; Print entries
	mov si, dir_buffer
	mov cx, [bdb_dir_entries_count]
	jmp .print_entries



.list_subdir:
	; Loading subdirectory from cluster chain
	mov ax, [current_dir_cluster]
	call fat12_read_cluster

	; Calculate number of entries
	mov cx, [bdb_bytes_per_sector]
	shr cx, 5			; Divide by 32 bytes (size of one entry)
	mov si, dir_buffer


.print_entries:
	
.entry_loop:
	; Check if entry is empty (0x00 or 0xE5)
	mov al, [si]
	cmp al, 0x00
	je .next_entry
	cmp al, 0xE5			; Deleted entry
	je .next_entry

	; Check if it is a volume
	mov al, [si + 11]
	and al, 0x08			; Volume label bit

	call .print_entry



.next_entry:
	add si, 32
	dec cx
	jnz .entry_loop



	popa
	ret

.print_entry:
	pusha
	mov di, si
	mov cx, 8
.print_name:
	mov al, [di]
	cmp al, ' '
	je .print_ext
	mov ah, 0x0E
	mov bh, 0
	int 0x10
	inc di
	dec cx
	jnz .print_name

.print_ext:
	mov di, si
	add di, 8
	mov cx, 3
	mov al, [di]
	cmp al, ' '
	je .check_dir

	mov ah 0x0E
	mov al, '.'
	int 0x10

.print_ext_loop:
	mov al, [di]
	cmp al, ' '
	je .check_dir
	mov ah, 0x0E
	int 0x10
	inc di
	dec cx
	jnz .print_ext_loop

.check_dir:
	mov al, [si + 11]
	and al, 0x10
	jz .print_newline
	push si
	mov si, str_dir_marker
	call puts
	pop si

.print_newline:
	call print_newline
	popa
	ret





; Change directory
;
;
;
.search_entries:
	
	mov si, dir_buffer
	mov cx, 
; Prints the the entries
; cx number of  entries to check
; si pointer to current entry
.print_entries:
	

.next_entry:

.print_entry:
	pusha
	




;
; Read a cluster from the disk
; Parameters:
; - ax: cluster number
; Returns
; - Data in dir_buffer
fat12_read_cluster:
	pusha
	
	sub ax, 2
	xor bx, bx
	mov bl, [bdb_sectors_per_cluster]	
	mul bx

	push ax

	mov ax, [bdb_sectors_per_fat]
	mov bl, [bdb_fat_count]
	xor bh, bh
	mul bx
	add ax, [bdb_reserved_sectors]




	mov bx, [bdb_dir_entries_count]
	shl bx, 5
	xor dx, dx
	div word [bdb_bytes_per_sector]
	test dx, dx

	jz .no_round
	inc ax

.no_round:
	moc bx, ax
	pop ax
	add ax, bx




	mov bx, dir_buffer
	mov cl, [bdb_sectors_per_cluster]
	mov dl, [ebr_drive_number]
	call disk_read
	

	popa
	ret



%include "kernel/drivers/disk.asm"

section .data
str_dir_marker:	db ' [DIR]',0

section .bss

; Current directory tracking
current_dir_cluster: resw 1
current_dir_cluster: resb 1

; Buffers
fat_buffer: resb 4608	; 9 sectors * 512 bytes
dir_buffer: resb 512	; One sector for directory entries 


