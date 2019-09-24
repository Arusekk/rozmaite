#include <stdio.h>
#include <stdlib.h>

void sort(int* first, int* last)
{
	sleep(5); // now pray
}

int main()
{
	int tab[11] = {1, 3, 5, 2, 4, 11, 7, 10, 6, 8, 9};
	puts("Before:");
	for (int i=0; i<11; i++)
		printf("%d ", tab[i]);
	puts("");

	puts("Sorting... (now is the time to pray)");
	fflush(stdout);
	sort(tab, tab+11);

	puts("Hope it worked:");
	for (int i=0; i<11; i++)
		printf("%d ", tab[i]);
	puts("");
	return 0;
}
