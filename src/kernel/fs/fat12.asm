bits 16

section .text


; Loads the FAT12 filesystem into memory
; 
list_root:
	; Getting the size of the FILE ALLOCATION TABLE IN SECTORS
	mov ax, [bdb_sectors_per_fat]
	mov bl, [bdb_fat_count]
	xor bh, bh			; Zeroing out upper 8 bits of bx to make sure we multiply bl only
	mul bx				; ax * bx (sectors per fat * fat count)
	
	; Adding the size of the RESERVED region to get the start of the ROOT DIRECTORY
	add ax, [bdb_reserved_sectors]	; Adding the RESERVED region
	push ax


	; Getting the size of the ROOT DIRECTOY, one entry is 32 bytes -> 32 * entries count = size in bytes
	mov ax, [bdb_dir_entries_count]	; Amount of entries in the ROOT DIRECTORY
	shl ax, 5			; Shifting ax 5 bits to the left, which is equal to multiplying it by 32 (2^5 = 32)
	xor dx, dx			; zeroing out the dx register for storing remainder
	div word [bdb_bytes_per_sector]	; AX(bdb_dir_entries) / bytes_per_sector = amount of sectors in ROOT DIRECTORY, Result is stored in AL
	test dx, dx			; Checking if the remainder is not 0
	jz .root_dir_after
	inc ax				; Rounding up amount of sectors if there are partially filled sectors



.root_dir_after:
	mov cl, al	; AL contains amount of sectors to read (size of ROOT DIRECTORY)
	pop ax		; Getting the size of the first 2 regions we pushed to the stack
	mov dl, [ebr_drive_number]
	mov bx, dir_buffer
	call disk_read
	
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
	




;
; 
.change_directory:




;
;
.fat12_list_directory:
	pusha

	cmp byte [current_dir_is_root], 1
	je .list_root
	
	jmp



section .data
str_dir_marker:	db ' [DIR]',0

section .bss

; Current directory tracking
current_dir_cluster: resw 1
current_dir_cluster: resb 1

; Buffers
fat_buffer: resb 4608	; 9 sectors * 512 bytes
dir_buffer: resb 512	; One sector for directory entries 


