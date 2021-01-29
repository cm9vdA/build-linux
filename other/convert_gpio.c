#include<stdio.h>
#include<stdlib.h>
#include<string.h>
int main(int argc, char **argv)
{
	if ((argc < 2) || (strlen(argv[1]) < 3)){
		printf("GPIO Number Inavlid.(Example: PH15)\n");
		return -1;
	}
	int a = argv[1][1] - 'A';
	int b = atoi(argv[1] + 2);
	// printf("a=%d, b=%d\n", a, b);
	printf("%s: %d\n", argv[1], (a * 32 + b));
	return 0;
}
