NASM ?= nasm

LD := $(CROSS_COMPILE)ld

OBJCOPY := $(CROSS_COMPILE)objcopy

kernelfiles += kernel.asm
kernelfiles += init.asm
kernelfiles += init/64.asm
kernelfiles += init/hdd.asm
kernelfiles += init/net.asm
kernelfiles += init/pci.asm
kernelfiles += syscalls.asm
kernelfiles += syscalls/disk.asm
kernelfiles += syscalls/io.asm
kernelfiles += syscalls/memory.asm
kernelfiles += syscalls/misc.asm
kernelfiles += syscalls/net.asm
kernelfiles += syscalls/pci.asm
kernelfiles += syscalls/smp.asm
kernelfiles += drivers.asm
kernelfiles += drivers/pci.asm
kernelfiles += drivers/pic.asm
kernelfiles += drivers/storage/ahci.asm
kernelfiles += drivers/net/i8254x.asm
kernelfiles += drivers/net/virtio.asm
kernelfiles += interrupt.asm
kernelfiles += sysvar.asm

installfiles += kernel.sys kernel-debug.txt
installfiles += kernel.bin kernel.elf
installfiles := $(installfiles:%=$(DESTDIR)$(PREFIX)/system/%)

.PHONY: all
all: kernel.sys kernel-debug.txt kernel.elf kernel.bin

kernel.sys kernel-debug.txt: $(kernelfiles) nasm.ld
	@echo "NASM $@"
	$(NASM) -P nasm.ld kernel.asm -o $@ -l kernel-debug.txt

kernel.bin: kernel.elf
	@echo "OBJCOPY $@"
	$(OBJCOPY) -O binary $< $@

kernel.elf: kernel.o kernel.ld
	@echo "LINK $@"
	$(LD) -T kernel.ld $< -o $@

kernel.o: $(kernelfiles)
	@echo "NASM $@"
	$(NASM) -f elf64 -g -F dwarf kernel.asm -o $@

.PHONY: clean
clean:
	$(RM) kernel.sys kernel-debug.txt kernel.bin kernel.elf kernel.o

.PHONY: test
test:

.PHONY: install
install: $(DESTDIR)$(PREFIX)/system $(installfiles)

$(DESTDIR)$(PREFIX)/system:
	mkdir -p $@

$(DESTDIR)$(PREFIX)/system/%: %
	cp $< $@

$(V).SILENT:
