bits 16
section .text

;
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

.list_subdir:
	jmp .done


.list_root:
	; Getting the size of the FILE ALLOCATION TABLE IN SECTORS
	mov ax, [bdb_sectors_per_fat]
	mov bl, [bdb_fat_count]
	xor bh, bh			; Zeroing out upper 8 bits of bx to make sure we multiply bl only
	mul bx				; ax * bx (sectors per fat * fat count)
	
	; Adding the size of the RESERVED region to get the start of the ROOT DIRECTORY
	add ax, [bdb_reserved_sectors]	; Adding the RESERVED region

	push ax				; Saving the root directory's LBA



	mov bx, dir_buffer

	; Getting the size of the ROOT DIRECTOY, one entry is 32 bytes -> 32 * entries count = size in bytes
	mov ax, [bdb_dir_entries_count]	; Amount of entries in the ROOT DIRECTORY
	shl ax, 5			; Shifting ax 5 bits to the left, which is equal to multiplying it by 32 (2^5 = 32)
	xor dx, dx
	div word [bdb_bytes_per_sector]	; AX(bdb_dir_entries) / bytes_per_sector = amount of sectors in ROOT DIRECTORY, Result is stored in AL

	test dx, dx			; Checking if the remainder is not 0
	jz .no_round_up
	inc ax				; Rounding up amount of sectors if there are partially filled sectors


.no_round_up:
	; read ROOT DIRECTORY

	mov cl, al

	pop ax
	mov bx, dir_buffer
	mov dl, [ebr_drive_number]
	call disk_read

	; Print entries
	mov si, dir_buffer
	mov cx, [bdb_dir_entries_count]


.entry_loop:
	; Check if entry is empty (0x00 or 0xE5)
	mov al, [si]
	cmp al, 0x00
	je .done
	cmp al, 0xE5			; Deleted entry
	je .next_entry

	; Check if it is a volume
	mov bl, [si + 11]
	and bl, 0x08			; Volume label bit
	jnz .next_entry

	call .print_entry



.next_entry:
	add si, 32
	loop .entry_loop



.done:
	popa
	ret

.print_entry:
	pusha

	mov di, si
	mov cx, 8

.print_name_loop:
	mov al, [di]
	cmp al, ' '
	je .print_ext
	mov ah, 0x0E
	mov bh, 0
	int 0x10
	inc di
	loop .print_name_loop

.print_ext:
	mov di, si
	add di, 8
	mov al, [di]
	cmp al, ' '
	je .check_dir

	mov ah, 0x0E
	mov al, '.'
	int 0x10

	mov cx, 3

.print_ext_loop:
	mov al, [di]
	cmp al, ' '
	je .check_dir
	mov ah, 0x0E
	int 0x10
	inc di
	loop .print_ext_loop

.check_dir:
	mov al, [si + 11]
	and al, 0x10
	jz .print_newline_and_ret
	push si
	mov si, str_dir_marker
	call puts
	pop si

.print_newline_and_ret:
	call print_newline
	popa
	ret



; Read a cluster from the disk
; Parameters:
; - ax: cluster number
; Returns
; - Data in dir_buffer
fat12_read_cluster:
	pusha
	
	sub ax, 2
	mov cl, [bdb_sectors_per_cluster]	
	mul cl

	push ax

	mov ax, [bdb_sectors_per_fat]
	mov cl, [bdb_fat_count]
	mul cl
	add ax, [bdb_reserved_sectors]

	mov cx, [bdb_dir_entries_count]
	shl cx, 5
	mov dx, 0
	div word [bdb_bytes_per_sector]
	test dx, dx

	jz .no_round
	inc ax

.no_round:
	pop bx
	add ax, bx



	mov cl, [bdb_sectors_per_cluster]
	mov bx, dir_buffer
	call disk_read
	

	popa
	ret







section .data

bdb_bytes_per_sector: dw 512
bdb_sectors_per_cluster: db 1
bdb_reserved_sectors: dw 1
bdb_fat_count: db 2
bdb_dir_entries_count: dw 224
bdb_sectors_per_fat: dw 9
ebr_drive_number: db 0
str_dir_marker: db ' [DIR]',0

section .bss

; Current directory tracking
current_dir_cluster: resw 1
current_dir_is_root: resb 1

; Buffers
fat_buffer: resb 4608 ; 9 sectors * 512 bytes
dir_buffer: resb 512 ; One sector for directory entries 

