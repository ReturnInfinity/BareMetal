# Hardware documentation


## CPU


### Intel

* [Software Developer Manuals](http://www.intel.com/content/www/us/en/processors/architectures-software-developer-manuals.html)


### AMD

* [Developer Guides, Manuals & ISA Documents](http://developer.amd.com/resources/developer-guides-manuals/)


## Bus

* [PCI Express](https://osdev.org/PCI_Express) - [PCI Express Base Specification Revision 4.0 Version 0.3](https://astralvx.com/storage/2020/11/PCI_Express_Base_4.0_Rev0.3_February19-2014.pdf)
* [PCI](https://osdev.org/PCI)


## Network


### Virtio

* [Specs](https://docs.oasis-open.org/virtio/virtio/v1.2/virtio-v1.2.pdf)
* [Legacy specs](http://ozlabs.org/~rusty/virtio-spec/virtio-0.9.5.pdf)

### Intel 8254x PCI (e1000)

* Supports the Intel 8254x Gigabit network interfaces.
* [PCI Software Developer's Manual](https://www.intel.com/content/dam/doc/manual/pci-pci-x-family-gbe-controllers-software-dev-manual.pdf)

### Intel 8257x PCIe (e1000e)

* Supports the Intel 8257x Gigabit network interfaces.
* [PCIe Software Developer's Manual](https://www.intel.com/content/dam/www/public/us/en/documents/manuals/pcie-gbe-controllers-open-source-manual.pdf?cmdf=PCI%2FPCI-E+Family+of+Gigabit+Ethernet+Controllers+Software+Developer’s+Manual)

### Intel 8259x (ixbge)

* Supports the Intel 8259x/X540/X550 10 Gigabit network interfaces.
* [Datasheet](https://www.intel.com/content/dam/www/public/us/en/documents/datasheets/82599-10-gbe-controller-datasheet.pdf)

### Realtek 8169 (r8169)

* Supports the Realtek 8168, 8169, 8110, and 8111 Gigabit network interfaces.
* [Datasheet](http://realtek.info/pdf/rtl8169s.pdf)


## Storage


### NVMe

* [Base Specification](https://nvmexpress.org/wp-content/uploads/NVM-Express-Base-Specification-2.0c-2022.10.04-Ratified.pdf) - Revision 2.0c - October 4th, 2022


### AHCI (Serial ATA)

* [ATA/ATAPI Command Set](http://www.t13.org/documents/uploadeddocuments/docs2006/d1699r3f-ata8-acs.pdf) - from 2006 but still valid
* [ATA Command Set](http://www.t13.org/documents/UploadedDocuments/docs2016/di529r14-ATAATAPI_Command_Set_-_4.pdf) - from 2016
* [Official Intel Specs](http://www.intel.com/content/www/us/en/io/serial-ata/ahci.html) - latest version 1.3.1
* [OSDev.org AHCI article](https://wiki.osdev.org/AHCI)


### ATA

* [OSDev.org ATA article](https://wiki.osdev.org/ATA_PIO_Mode)


## Video


### BGA

* [VBE BIOS for Bochs](http://cvs.savannah.nongnu.org/viewvc/*checkout*/vgabios/vgabios/vbe_display_api.txt)
