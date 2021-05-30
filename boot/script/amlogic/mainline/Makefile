.PHONY: emmc_scr tf_scr all clean

SOURCE_EMMC=boot_emmc_*.cmd
SOURCE_TF=boot_tf.cmd

all: emmc_scr tf_scr

emmc_scr: $(SOURCE_EMMC)
	for item in ${SOURCE_EMMC}; do \
		mkimage -A arm -O linux -T script -C none -a 0 -e 0 -n 'Boot from EMMC' -d $$item $(basename $$item).scr; \
	done


tf_scr: ${SOURCE_TF}
	for item in ${SOURCE_TF}; do \
		mkimage -A arm -O linux -T script -C none -a 0 -e 0 -n 'Boot from TF' -d $$item $(basename $$item).scr; \
	done

clean:
	rm *.scr -rf