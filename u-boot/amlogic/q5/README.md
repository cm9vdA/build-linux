1. 从厂商SDK中编译u-boot
2. 将厂商u-boot写入TF卡，目的是利用原厂u-boot将新的u-boot写入到EMMC
	```
	dd if=fip/u-boot.bin.sd.bin of=/dev/sdb bs=1 count=442
	dd if=fip/u-boot.bin.sd.bin of=/dev/sdb bs=512 seek=1 skip=1
	```
3. 编译主线u-boot，利用原厂fip生成新的u-boot
4. 在TF卡的第一个分区中，保存生成的主线u-boot
5. 从TF卡启动，必要时可短接EMMC，强制从TF卡启动
6. 在原厂u-boot中，将新u-boot写入
	```
	fatload mmc 0 ${loadaddr} u-boot.bin
	store rom_write ${loadaddr} 0 120000
	fatload mmc 0 ${loadaddr} gxbb_p201_Q5.dtb 
	store dtb write ${loadaddr}
	```
