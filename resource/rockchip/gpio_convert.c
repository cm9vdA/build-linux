#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

int main(int argc, char **argv)
{
	int bank, pin;
	char *p, ch;

	if (argc != 3 || strncmp(argv[2], "RK_P", 4) != 0) {
		printf("Invalid argument\n");
		return -1;
	}

	ch = '\0';
	pin = -1;
	sscanf(argv[2], "RK_P%c%d", &ch, &pin);

	if (ch == '\0' || pin == -1) {
		printf("Invalid argument\n");
		return -1;
	}

	bank = atoi(argv[1]);
	pin = (ch - 'A') * 8 + pin;
	printf("GPIO_%d RK_P%c%d is %d\n", bank, ch, pin, bank * 32 + pin);
	return 0;
}