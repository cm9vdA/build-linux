#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <err.h>
#include <errno.h>
#include <fcntl.h>
#include <unistd.h>

#include <linux/types.h>
#include <linux/i2c.h>
#include <linux/i2c-dev.h>

#include <sys/ioctl.h>
#include <sys/types.h>
#include <sys/stat.h>

#define I2C_DEV "/dev/i2c-6"
#define MCU_I2C_ADDR 0x62

/*
SMDT 看门狗程序
*/

int fd = -1;

static int i2c_write(uint8_t reg, uint8_t val, int ms)
{
	int retries;
	uint8_t data[2];

	data[0] = reg;
	data[1] = val;

	for (retries = 5; retries; retries--) {
		if (write(fd, data, sizeof(data)) == sizeof(data)) {
			return 0;
		}
		usleep(1000 * 10);
	}
	if (ms) {
		usleep(ms * 1000);
	}

	return -1;
}

static int i2c_read(uint8_t reg, uint8_t *val, int ms)
{
	int retries;

	for (retries = 5; retries; retries--) {
		if (write(fd, &reg, 1) != 1) {
			return -1;
		}
		if (read(fd, val, 1) != 1) {
			return -1;
		}
	}
	if (ms) {
		usleep(ms * 1000);
	}

	return 0;
}

// 检查指定寄存器数值是否是预期值
static int i2c_check_val(uint8_t reg, uint8_t val, int ms)
{
	uint8_t t = 0;
	if (i2c_read(reg, &t, ms) < 0) {
		printf("Error: read Reg[0x%x] failed\n", reg);
		return -1;
	}
	if (t != val) {
		printf("Error: expect Reg[0x%x] is 0x%x, in fact 0x%x\n", reg, val, t);
		return -1;
	}
	return 0;
}

// 原版固件开机后对MCU的操作流程
static int wdt_simulator()
{
	int retries;
	i2c_check_val(0x3a, 0x89, 0);

	for (retries == 2; retries; retries--) {
		i2c_check_val(0xed, 0x00, 5);
		i2c_check_val(0xeb, 0x8c, 5);
		i2c_check_val(0xea, 0xf5, 5);
		i2c_check_val(0xe9, 0x68, 5);
		i2c_check_val(0xe8, 0x5e, 5);
	}

	i2c_check_val(0x3b, 0xb1, 16);
	i2c_check_val(0x3b, 0xb1, 0);
	i2c_write(0x32, 0x01, 9);
	i2c_check_val(0xb2, 0x01, 12000);
	i2c_write(0x51, 0x33, 8);
	i2c_check_val(0xd1, 0x33, 1900);
	i2c_check_val(0xb1, 0x00, 5000);
}

static int wdt_simulator_lite()
{
	i2c_write(0x32, 0x01, 9);
	i2c_write(0x51, 0x33, 8);
}

// 打开设备
static int wdt_init(void)
{
	fd = open(I2C_DEV, O_RDWR);

	if (fd < 0) {
		perror("Can't open " I2C_DEV " \n");
		return -1;
	}
	printf("Open " I2C_DEV " success !\n");
	if (ioctl(fd, I2C_SLAVE, MCU_I2C_ADDR) < 0) {
		perror("Failed to set i2c device slave address!\n");
		close(fd);
		return -1;
	}

	return 0;
}

// 原版固件中手动开启看门狗会执行的动作，仅读取寄存器，无实际效果
static int wdt_enable()
{
	return i2c_check_val(0xb2, 0x00, 0);
}

// 原版固件中手动关闭看门狗会执行的动作
static int wdt_disable()
{
	return i2c_write(0x32, 0x00, 0);
}

// 准备喂狗
static int wdt_prepare()
{
	wdt_disable();
	if (i2c_write(0x32, 0x01, 9) < 0) {
		return -1;
	}
	return i2c_write(0x51, 0x33, 8);
}

// 喂狗
static int wdt_feed()
{
	return i2c_write(0x33, 0xab, 0);
}

int main()
{
	if (wdt_init() < 0) {
		return -1;
	}
	wdt_prepare();

	while (1) {	 // 无限循环
		if (wdt_feed() < 0) {
			break;
		}
		// 延时 20 秒
		sleep(20);
	}

	return 0;
}
