ASM=nasm

SRC_DIR=src
SRC_BOOT_DIR=$(SRC_DIR)/boot
SRC_KERNEL_DIR=$(SRC_DIR)/kernel
SRC_LIBC_DIR=$(SRC_DIR)/libc

BUILD_DIR=build


.PHONY: all floppy_image kernel bootloader clean always

all: floppy_image 





#
# Floppy image
#
floppy_image: $(BUILD_DIR)/main_floppy.img

$(BUILD_DIR)/main_floppy.img: bootloader kernel 
	dd if=/dev/zero of=$(BUILD_DIR)/main_floppy.img bs=512 count=2880
	mkfs.fat -F 12 -n "NBOS" $(BUILD_DIR)/main_floppy.img
	dd if=$(BUILD_DIR)/bootloader.bin of=$(BUILD_DIR)/main_floppy.img conv=notrunc
	mcopy -i $(BUILD_DIR)/main_floppy.img $(BUILD_DIR)/kernel.bin "::kernel.bin"


#
# Bootloader
#
bootloader: $(BUILD_DIR)/bootloader.bin

$(BUILD_DIR)/bootloader.bin: always	$(SRC_BOOT_DIR)/boot.asm
	$(ASM) $(SRC_BOOT_DIR)/boot.asm -f bin -o $(BUILD_DIR)/bootloader.bin


#
# Kernel
#
kernel: $(BUILD_DIR)/kernel.bin

$(BUILD_DIR)/kernel.bin: always $(SRC_KERNEL_DIR)/main.asm $(SRC_KERNEL_DIR)/drivers/keyboard.asm $(SRC_LIBC_DIR)/string.asm
	$(ASM) -I$(SRC_DIR)/ $(SRC_KERNEL_DIR)/main.asm -f bin -o $(BUILD_DIR)/kernel.bin



#
# Always
#
always:
	mkdir -p $(BUILD_DIR)

#
# Clean
#
clean:
	rm -rf $(BUILD_DIR)/*
