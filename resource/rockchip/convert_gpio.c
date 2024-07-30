#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <ctype.h>

char *pin_name[] = {"RK_PA0", "RK_PA1", "RK_PA2", "RK_PA3", "RK_PA4", "RK_PA5",
					"RK_PA6", "RK_PA7", "RK_PB0", "RK_PB1", "RK_PB2", "RK_PB3",
					"RK_PB4", "RK_PB5", "RK_PB6", "RK_PB7", "RK_PC0", "RK_PC1",
					"RK_PC2", "RK_PC3", "RK_PC4", "RK_PC5", "RK_PC6", "RK_PC7",
					"RK_PD0", "RK_PD1", "RK_PD2", "RK_PD3", "RK_PD4", "RK_PD5",
					"RK_PD6", "RK_PD7"};

int main(int argc, char **argv)
{
	int pin, bank, num, i;

	if (argc < 2) {
		printf("GPIO Number Inavlid.(Example: 10)\n");
		return -1;
	}
	for (i = 1; i < argc; i++) {
		pin = -1;
		if (strncmp(argv[i], "0x", 2) == 0) {
			sscanf(argv[i], "0x%x", &pin);
		} else {
			sscanf(argv[i], "%d", &pin);
		}

		if (pin < 0) {
			printf("Invalid Pin: %s\n", argv[i]);
			continue;
		}

		bank = pin / 32;
		num = pin % 32;

		printf("Pin-%-3d is GPIO_%d %s\n", pin, bank, pin_name[num]);
	}

	return 0;
}