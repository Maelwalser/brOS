# Basic OS developement learning repo
Learning to write an Operating system in Assembly x86 :)
- Using the FAT12 filesystem
- Running on a floppy_disk image 

## Bootloader

### Setting Up FAT12 File System
#### FAt12 Header
We use a data structure called BIOS Parameter Block (BPB) to describe the layout of the FAT12 filesystem on the disk.
```asm
jmp short start
nop
```
**jmp short start:**  Jumps over the **BPB** data structure to the start of the code (label **start**). A short jump is a 2-byte instruction that jumps within a small range (-127 to +127 bytes)<br/>
**nop:** No operation, ensures the following data structure starts at a clean offset.

Then we declare the standard **BPB** for a 1.44MB floppy disk:
```asm
bdb_oem:			        db 'MSWIN4.1'
bdb_bytes_per_sector:		dw 512
bdb_sectors_per_cluster:	db 1
bdb_reserved_sectors:		dw 1
bdb_fat_count:			    db 2
bdb_dir_entries_count:		dw 0E0h
bdb_total_sectors:		    dw 2880
bdb_media_descriptor_type:	db 0F0h
bdb_sectors_per_fat:		dw 9
bdb_sectors_per_track:		dw 18
bdb_heads:			        dw 2
bdb_hidden_sectors:		    dd 0
bdb_large_sector_count:		dd 0
```
**bdb_oem:**  An 8-byte string, which identifies the system that formatted the disk<br/>
**bdb_bytes_per_sector:** Defines the size of a sector in bytes<br/>
**bdb_sectors_per_cluster:** Defines how many sectors make up one cluster, which is the smallest allocatable unit of disk space<br/>
**bdb_reserved_sectors:** The number of sectors before the first File Allocation Table (FAT), the boot sector itself is one, so it is atleast 1<br/>
**bdb_fat_count:** Number of FAT copies on the disk, usually 2 for redundancy<br/>
**bdb_dir_entries_count:** The maximum number of entries in the root directory, `0xE0` is 224<br/>
**bdb_total_sectors:** The total number of sectors on the disk, `2880 sectors * 512 bytes/sector = 1,474,560 bytes`, which is 1.44 MB<br/>
**bdb_media_descriptor_type:**	 `0xF0` is the standard code for a 1.44 MB floppy<br/>
**bdb_sectors_per_fat:** The size of one FAT in sectors, which is 9 for a 1.44 MB floppy<br/>
**bdb_sectors_per_track:**  Number of sectors on a single track, which is 18 for a 1.44 MB floppy<br/>
**bdb_heads:** Number of read/write heads (equals the number of sides)m which is 2 for a standard floppy<br/>
**bdb_hidden_sectors:** Used for larger disks and partitions, 0 for a floppy<br/>
**bdb_large_sector_count:** Used for larger disks and partitions, 0 for a floppy

#### Extended Boot Record (EBR)
This is an extension to the BPB:
```asm
ebr_drive_number:		db 0
						db 0
ebr_signature:			db 29h
ebr_volume_id:			db 12h, 34h, 56h, 78h
ebr_volume_label:		db 'BrOS       '
ebr_system_id:			db 'FAT12   '
```
**ebr_drive_number:** The bios drive number, which is `0x00` for the first floppy and `0x80` for the first hard disk, this is update later by the code<br/>
**ebr_signature:** Must be `0x29` to indicate the presence of the following 3 fields:
- **ebr_volume_id:** A 4-byte serial number for the volume
- **ebr_volume_label:** The 11-byte volume name
- **ebr_system_id:** An 8-byte string identifying the filesystem type "FAT12"

### Main function
*The main label holds the core functions of our bootloader.*
#### Segment Register Initialization
In 16-bit real mode, memory is accessed using a **segment:offset** pair. **DS** (Data Segment) and **ES** (Extra Segment) are used to point to the base of data regions.
```asm
main:
	mov ax, 0
	mov ds, ax
	mov es, ax
```
**mov ax, 0**: The **AX** register is used as an intermediary because the segment register cannot be loaded with a direct value (So mov ds, 0 is invalid)<br/>
**mov ds, ax**: Sets the **DS** register to 0. So all the memory accessing we do using **SI** will be relative to segment 0. SO **DS:SI** points to `0x0000:SI`<br/>
**move es, ax**: Sets the **ES** register to 0, which is often used for string operations or as a destination for memory copies like the disk read.

#### Stack Setup
We need to setup the stack memory for storing return addresses, function parameters and local variables:
```asm
	mov ss, ax
	mov sp, 0x7C00
```
**mov ss, ax**: Sets the **SS** (Stack segment) register to 0<br/>
**mov sp, 0x7C00**: Sets the **SP** (Stack pointer) to `0x7C00`, which is the address where our code was loaded and as the stack grows downwards it will securely write to addresses below our code
#### Boot Drive number
```asm
	mov [ebr_drive_number], dl
```
**mov  \[ebr_drive_number], dl**: The BIOS passes the boot drive number in the **DL** register (0x00 for /dev/fd0)<br/>
The **DL** (Data low) register is the low 8-bit portion of the 16-it **DX** register.<br/>
By convention the BIOS uses the **DL** register to pass the drive number to the operating systems bootloader and is standardized the following way:
- `0x00` First floppy disk (A:)
- `0x01` Second floppy disk (B:)
- `0x80` First hard disk drive
- `0x81` Second hard disk drive<br/>
....

#### Calling Disk_read
First we have to set up the parameters for the disk_read function and then call it:
```
	mov ax, 1
	mov cl, 1
	mov bx, 0x7E00
	call disk_read
```
**mov ax, 1**: Sets the **LBA** (Logical Block Address) to 1, the **LBA** 0 is the boot sector itself, which makes **LBA** 1 the second sector on the disk. We use the register **AX** to pass the **LBA** address to disk_read.<br/>
**mov cl, 1**: Sets the number of sectors to read to 1. **CL** (Count Low). The BIOS disk read function specifically expects the sectors count here.<br/>
**mov bx, 0x7E00**: Sets the destination buffer address. The bootloader is 512 bytes long and loaded at `0x7C00`, so the memory location after the bootloader is `0x7C00 + 512 = 0x7E00`, which makes it a safe location to load the next stage. The sub-register **BX** is used as an offset pointer in the disk read interrupt `int 13h`, which expects the destination buffer **ES:BX**. Since **ES** is zero this makes the address `0x0000:0x7E00`.<br/>
**call disk_read**: calls our disk_read routine

#### Disk Routines
As we are using an older BIOS disk service `int 13h`, which requires **CHS** (Cylinder, Head, Sector) addressing instead of **LBA** (Logical Block Address) we have to convert between the to.<br/>

The `int 13h`:<br/>
##### Converting LBA to CHS
lba_to_chs function:
```asm
lba_to_chs:
	push ax
	push dx
```
First we have to save **AX** and **bx** to the stack, as they will be modified later in the function.<br/>
**push ax**:  Pushes the value in **AX** to the stack<br/>
**push dx**:  Pushes the value in **DX** to the stack

Then using a **XOR** operator we have to zero out the **DX** register, to ensure we only divide the 16 bit value in **AX**, as the **DIV** instruction performs a 32-bit division on **DX:AX** by a 16-bit operand.
```asm
	xor dx, dx
	div word [bdb_sectors_per_track]
```
**xor dx, dx**:  Zeros out the whole **DX** register<br/>
**div word \[bdb_sectors_per_track]**: Divides **AX** by the number of sectors per track (18).<br/>
-> The quotient `LBA / 18` is stored in **AX**<br/>
-> The remainder  `LBA % 18` is stored in **DX**


As the **CHS** **Sector** number is 1-based (Starts with 1), while the remainder is 0-based we have to add 1 to get the correct **Sector** number.
```asm
	inc dx
	mov cx, dx
```
**inc dx**: This increments the remainder stored in **DX** by 1<br/>
**mov cx, dx**: Stores the calculated sector number in **CX**

Then we have to zero out the **DX** register for the next division and continue our calculations to get the **Cylinder** and **Head** number:
```asm
	xor dx, dx
	div word [bdb_heads]
```
**xor dx, dx**: Zeros out the **DX** register for the next division<br/>
**div word \[bdb_heads]**: Divides the current value in **AX** (`LBA / 18`) by the number of **Heads** (2)<br/>
-> The quotient `(LBA / 18) / 2` is stored in **AX** and is the **Cylinder** number<br/>
-> The remainder `(LBA / 18) % 2` is stored in DX and is the **Head** number


Then we need to save the calculated **CHS** address into the registers which the `int 13h` expects<br/>
**int 13h** expects:
- **DH** to hold **Head** number
- **CH** to hold the lower 8 bits of the the **Cylinder** number
- **CL** to hold the **Sector** number in bits 0-5 and the upper 2 bits of the **Cylinder** number in bits 6 and 7
```asm
	mov dh, dl
	mov ch, al
	shl ah, 6
	or cl, ah
```
**mov dh, dl**: Moves the calculated **Head** number into **DH**<br/>
**mov ch, al**: Moves the lower 8 bits from **AL** (**AL** is the lower 8 bits of **AX**) of the **Cylinder** number into **CH**<br/>
**shl ah, 6**: The upper 2 bits of the cylinder number are in the lower 2 bits of **AH** (**AH** is the higher 8 bits of **AX**), with **SHL** we shift them 6 places to the left, which puts the 2 bits we need to bit 6 and 7<br/>
**or cl, ah**: Combines the upper 2 bits (Now in the 6th and 7th bit) in **AH** with the Sector number we already saved in **CL**

Then we have to restore our **Registers** and **Stack** and return from the function:
```asm
	pop ax
	mov dl, al
	pop ax 
	ret
```
##### Disk Read
To read from the disk we use the following **BIOS** function: INT 13h<br/>

Next we need a function to read sectors from the disk, with a built-in retry mechanism.<br/>
The function will have the parameters:
- **AX**: **LBA** address
- **CL**: Number of sectors to read
- **DL**: Drive number
- **ES:BX**: Memory address, where we store the read data<br/>
First we save all the registers to the Stack, which we will modify in the function:
```asm
disk_read:
	push ax
	push bx
	push cx
	push dx
	push di
```
We use the register **DI** as the retry counter.

Then we need to convert the **LBA** address to **CHS** using our lba_to_chs function:
```asm
	push cx
	call lba_to_chs
	pop ax
```
**push cx**: The **CX** register contains the numbers of sectors to read in the 8 lower bits **CL** register of **CX**. We push it to the stack to save it.<br/>
**call lba_to_chs**: Converts the **LBA** address stored in **AX** to **CHS**, with the results stored in **CX** and **DH**<br/>
**pop ax**: The saved value from the push **CX** is popped into **AX**, which makes the lower 8 bits of the **AX** register contain the number of sectors to read, which is required by `int 13h`

Then we need to initialize and create our retry loop:
```asm
	mov ah, 02h
	mov di, 3
.retry:
	pusha
	stc
	int 13h
	jnc .done
```
**mov ah, 02h**: Selects the "Read Sectors" function for the BIOS interrupt<br/>
**mov di, 3**: Initializes the retry counter **DI** to 3<br/>
**.retry:**: Label where the retry loop starts<br/>
**pusha**: This pushes all general purpose registers (**AX**, **CX**, **DX**, **BX**, **SP**, **BP**, **SI** and **DI**) to the stack<br/>
**stc**: As some older BIOS do not reliably set the carry flag we set it manually using the **STC** (Set Carry Flag)<br/>
**int 13h**: Calls the BIOS disk service<br/>
**jnc .done**: Jump if No Carry, on success (If the carry flag is empty) the BIOS clears the carry flag and jumps to the .done label.

Then we need to create a failure path to retry the reading when the reading fails:
```asm
	popa
	call disk_reset
	dec di
	test di, di
	jnz .retry
```
**popa**: Resores all the registers we saved with **pusha**<br/>
**call disk_reset**: Calls our reset_disk function<br/>
**dec di**: Decrements the retry counter by 1<br/>
**test di, di**: Then we check if the **DI** register is 0. It performs a bitwise AND and sets the Zero Flag if the result is 0<br/>
**jnz .retry**: Jump if Not Zero. If the retry counter is not zero yet we retry again by jumping to the retry label

Then we also need to add a label to handle the failure of all 3 retries and a success path:
```
.fail:
	jmp floppy_error
.done:
	popa
	... Restoring all the registers saved at the beginning and returns
```
**.fail:** Upon failure we take this labels path<br/>
**jmp floppy_error**: Jumps to our error handler which prints the error to the screen<br/>
**.done:** Upon success we take this labels path<br/>
**popa**: Restores all the registers we saved with the **pusha** in the retry loop

##### Disk Reset
For every retry we call the disk_reset function to reset the disk to its initial state:
```asm
disk_reset:
	pusha
	mov ah, 0
	stc
	int 13h
	jc floppy_error
	popa
	ret
```
**mov ah, 0**: Selects the "Reset Disk System" function for `int 13h`<br/>
**int 13h**: Calls the BIOS to reset the drive specified in **DL**<br/>
**jc floppy_error**: Jump if No Carry. When the reset of the controller itself fails we jump to the error handler


### FileSystem FAT12
Way of organizing data on a disk.
#### Structure
A FAT disk is typically organized in 4 sectors/regions:
- **Reserved**: Where our Bootloader is stored and holds important data like the size of a sectors and their location
- **File allocation tables:** Contains 2 copies of the file allocation table, which is a simple lookup table which holds the location of the next block of data
- **Root directory**: Table of contents of the disk, it contains entries for each file or folder located in the root of the disk. The entries consist of data like the file name, location on the disk, the size and the attributes
- **Data**: This is where the actual contents of the files and directories is stored
#### How Data Is Read
With using the following disk image as an example we will go through the process of reading a file:<br/>
First we need to figure out where the **Root Directory** region begins<br/>
When looking at the **Boot Sector** lines of Hex values we get the following information:<br/>

As we know that the **Root Directory** is the 3rd region in the file system we can figure out where it begins by calculating the size of the first 2 regions.<br/>
The **Boot Sector** contains a field called **Reserved Sectors**:<br/>

This gives us the exact size of the **Reserved** region measured in **Sectors**, which is **1** in our case<br/>
It also contains the fields **Fat count** and **Sectors per fat** which we can use to calculate the size of the **File allocation tables**:<br/>

By multiplying the **Fat count** (2) with the **Sectors per fat** (9) we get the size of the **File allocation tables** (18) in sectors

-> By adding these sizes together (1 + 18) we get the sector where the **Root directory** starts

We also need to know the size of the **Root directory**, so we know where the **Root directory** ends<br/>
We can calculate that using the **Dir entry count**:<br/>

As we know from the specifications a **Directory entry** is 32 bytes. So by multiplying the **Dir entry count** (224) by the size of a **Directory entry** (32 bytes) which equals to 7168 bytes.<br/>
Then by dividing the total bytes (7168 bytes) by the bytes per sector (512 bytes) we get a total of 14 sectors. If we get a number with a decimal point we round up the number.


Files names can only be 11 characters long<br/>
We can compare the file name with the file name field to get the file we want to read.

For example reading the file **Test TXT**:<br/>
Then we need the **First cluster(low)** number (16-bits), the **First cluster(high)** is used in FAT32 to create 32-bit cluster number with the **First cluster(low)**<br/>
In FAT12 we only need the **First cluster(low)**.<br/>
Just like disks use blocks called **Sectors**, FAT uses **Clusters**. The size of a **Cluster** in **Sectors** is defined in the **Boot sector**:<br/>

The **Cluster** number gives us the location of the data in the **Data** region and they start with 2!<br/>
So to convert it to a **Sector** number we take the size of the first 3 regions (**Reserved**, **File allocation tables** and **Root directory**) then we add the **Cluster** number and subtract 2 (As it is 2 indexed) and multiply it with the amount of **Sectors** per **Cluster**:<br/>

This will equal: `1 + 18 + 14 + (3 -2) * 2 = 35`<br/>
-> 35 is the **Sector** number where the data begins<br/>
Then we need to find out where the next **Cluster** begins<br/>
We can do that using the **File allocation tables**. In this table the index corresponds to a **Cluster** number and the entries indicate a new **Cluster**<br/>
For **FAT12** each entry is 12 bits wide.<br/>
As our **Cluster** number was 3 we can know that the next cluster is 004 (4). Then we have to calculate its **Sector** number like we did before, read the data and move on to the next cluster (005).<br/>
This will be repeated until the **Cluster** number has a value above **FF8**. This is and indication of the end of a file.

##### Reading Files From Directories
To read files from folders we have to split the path into components parts (With converting it tot FAT file naming Scheme).<br/>
Then the same steps from before apply. Directories have the same structure as the root directory and can be read just like an ordinary file.<br/>
After that we search the next component from the path in the directory and read it<br/>
-> Repeat until we reach and read the file

## Keyboard driver
To get input from the keyboard and write the characters to the screen we need a keyboard driver.
### Storing and Printing Characters
We need to create a buffer which will hold the characters typed by the user.<br/>
So we need to declare a keyboard buffer in the uninitialized data section (.bss).<br/>
We use the **equ** directive to declare a constant number 256 for our buffer size.<br/>
Then we create the **keyboard_buffer** and reserve 256 bytes with the **resb** directive and using our constant size:
```asm
section .bss

; Defines Buffer for keyboard input
KEYBOARD_BUFFER_SIZE equ 256
keyboard_buffer: resb KEYBOARD_BUFFER_SIZE
```
First we start of by pushing all general registers to not modify any unwanted data. Then we set the **di** (Destination index register) regiser to the start of our keyboard buffer:
```asm
read_string:
	pusha
	mov di, keyboard_buffer	; Set di to the start of our buffer
```
Then we can start our loop for receiving input through our keyboard. We set the **ah** (higher 8-bits of AX) to 0x00, which will select the sub-function of the keyboard service "Wait for Keystroke and Read Character" when executing the 0x16 BIOS keyboard services:
```asm
.loop:
	mov ah, 0x00	; BIOS wait for keystroke function
	int 0x16	; BIOS keyboard interrupt
```
This routine will wait indefinitely until a key is pressed.<br/>
It outputs the **Scan Code** in the **ah** register, a unique identifier for which physical key was pressed, so we can distinguish between an 'a' and 'A' for example.<br/>
And outputs the ASCII code in the **al** register, for example 0x41.

Then we check if the pressed key is enter or backspace as they have special function:
```asm
	; AL contains the ASCII code of the key pressed

	cmp al, 0x0D	; Check if keypress is Enter (ASCII 0x0D)
	je .done

	cmp al, 0x08	; Check if keypress is Backspace (ASCII 0x08)
	je .backspace
```

To prevent buffer overflow we have to check if the current position in the buffer is smaller than the buffer size:
```asm
	; Prevent buffer overflow
	mov cx, di	; Save pointer to current position in buffer to cx
	sub cx, keyboard_buffer	; Get the offset of the current position
	cmp cx, KEYBOARD_BUFFER_SIZE - 1	; Check if we arrived at the end of our buffer
	je .loop
```
We save the pointer to the current position in the buffer, which is stored in **di** to **cx**. Then we subtract the begining of the keyboard buffer from the current position in the buffer. This results in the offset in the buffer, so the position in the buffer. For example if the **keyboard_buffer** is at adress 0x1000 and **di** is at 0x100A will result in 10, which tells us we are 10 bytes into the buffer.<br/>
Then we compare the current position in the buffer to the keyboard buffer last usable index. It will subtract the operands and sets the CPU status flags accordingly (zero, negative....).<br/>
Then we jump to the start of the loop if the CPU's Zero flag is set to 1, which means the operands were equal, so if we are at the end of our buffer we jump back to the .loop label ignoreing further keypresses.

Next we have to print the characters we get from the keyboard input to the screen:
```asm
	; Echo the character to the screen
	mov ah, 0x0E	; BIOS teletype output function
 	mov bh, 0
	int 0x10	; BIOS video interrupt
```
With the use of the BIOS teletype output function which we get by saving the value 0x0E in the **ah** register we will print the character. We also set the video page with the register **bh** to 0 (This can be used to draw on a hidden page).<br/>
Then we execute the software interrupt for BIOS video services with `int 0x10`. The Teletype Output function expects the parameter for the character to print in the **al** register.

Next we store the character we got as input in the **al** register to the memory address of the current position of the buffer which we store in **di**(pointer). Then we increase the value of di to point to the next address in the buffer and jump back to the beginning of the loop for the next character:
```asm
	; It is a printabe character
	mov [di], al	; Store character in our buffer
	inc di		; Move to the next position in the buffer

	jmp .loop	; Loop and wait for nex character
```

### Enter Keypress
Next lets implement the special function we want Enter to have. As we previously compared the input character to check if it is Enter we now need to implement the function of that label:<br/>
As we want the enter command to be signaling the end of the input and execute a command depending on that input we need to first null terminate the string.<br/>
We do that by moving a single byte of data to the memory location pointed by the **di** register with value 0.<br/>
Then we ne need to add a Carriage Return (**CR**) to move the cursor to the beginning of the current line and then add a Line Feed (LF) which moves the cursor down one line. We do that using the BIOS teletype function we used before with setting the **ah** register to their ASCII values.<br/>
Next we calculate the length of the string we will return. We do that the same way we did before for checking for buffer overflow.<br/>
Next we restore the values of all general purpose register we pushed at the start of the driver with `popa`.<br/>
Then we setup the return value by setting the register **di** to the beginning of our buffer.<br/>
Next we end the subroutine by calling a return instruction, which will leave the caller with **cx**, the length of the string and **di**, a pointer to the beginning of the null-terminated string.
```asm
.done:
	; Null terminate the string	
	mov byte [di], 0

	; Add a newline to the screen
	mov ah, 0x0E
	mov al, 0x0D	; Carriage return
	int 0x10
	mov al, 0x0A	; Line feed
	int 0x10

	; Calculate string length
	mov cx, di
	sub cx, keyboard_buffer	; cx = length (di - start adress)

	popa		; Restore all registers

	; Set di to point to the beginning of the string for the calller
	mov di, keyboard_buffer
	ret
```

### Backspace Keypress
Next lets implement the deleting of characters with the backspace key input. As we previously compared the input character to check if it is the Backspace key pressed we now implement the functionality of that.<br/>
As we should not be able to use backspace at the beginning of the line we first check if the current position in the buffer is equal to the beginning of the buffer. If so we jump back to our loop for getting the next characters.<br/>
If that is not the case we decrease the pointer to the current position in the buffer by one.<br/>
We also need to update the screen to remove the character with using the BIOS teletype output function. We set the register **al** to backspace and then execute the interrupt, which will move the cursor one position to the left without deleting the character.<br/>
Next we set the register **al** to a space character ' ' and print that with calling the interrupt again, this will overwrite the character we want to delete, but also move us one character to the right again.<br/>
So we have to call the video interrupt again with the backspace character to move to the left again.<br/>
After that we can jump to the main loop again listening for the next character input.
```asm
.backspace:
	; Check if we are at the beginning of the buffer
	cmp di, keyboard_buffer
	je .loop		; If yes, wait for next key
	
	; Not at the beginning of the buffer -> Can backspace
	dec di			; Move back one character in the buffer

	; Update the screen to remove character
	mov ah, 0x0E	; BIOS teletype output function
	mov al, 0x08	; Backspace character
	int 0x10	; BIOS video interrupt
	mov al, ' '	; Overwrite with a space
	int 0x10	; BIOS video interrupt
	mov al, 0x08	; Move cursor back again
	int 0x10	; BIOS video interrupt

	jmp .loop
```
