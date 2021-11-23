/*****************************************************************************/
/* SPLAY.C -> "Simple" play utility plays audio files through a sound driver */
/* Need only to link to DIGPLAY0.OBJ.  Doesn't use DOSCALLS.OBJ, uses C      */
/* standard library functions to read a file in and play it back.            */
/* Written by John W. Ratcliff, December 1991, needs to link to DIGPLAY0.OBJ */
/*****************************************************************************/
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <alloc.h>

#include "digplay.h"    // Include DIGPLAY header.

unsigned char far *PlaySoundFile(char *filename,int frequency);
void far *FileLoad(char *fname,long int *siz);

void main(int argc,char **argv)
{
	int frequency=9000; // Default playback frequency.

	if (argc == 3)	    // If user specified a specific playback frequency.
	{
		frequency = atoi( argv[2] );
		argc--;
	}
	if (argc != 2)
	{
		printf("Usage: SPLAY <filename> (frequency)\n");
		printf("where <filename> is the name of an 8 bit unsigned, digitized sound sample, and\n");
		printf("(frequency) is the optional frequency you would wish it played at (default 9khz).\n");
		printf("Copyright (c) 1991, THE Audio Solution.\n");
		printf("Written by John W. Ratcliff, 1991.\n");
		exit(1);
	}

	if (!CheckIn())  // Is a sound driver currently resident?
	{
		printf("No sound driver resident.\n");
		exit(1);
	}

	SetPCMVolume(75,75);

	if ( PlaySoundFile(argv[1],frequency) == NULL ) printf("File '%s' not found, or insuficient memory.\n",argv[1]);

}

// Reads a file into allocated memory, and will play it back.
unsigned char far *PlaySoundFile(char *fname,int freq)
{
	long int siz,start;
	SNDSTRUC sndplay;
	unsigned char far *begin,far *playseg;
	int xcon = 0;

	playseg = FileLoad(fname,&siz);  // Load audio file into memory.
	if ( playseg == NULL ) return(NULL); // If unable to load file, return.

	sndplay.frequency = freq; // Playback frequency.

	begin = playseg;
	start = siz;

	// First pre-format all audio data before playing it back.

	do
	{
		sndplay.sound = playseg;
		if ( siz > 65535L )
		{
			sndplay.sndlen = 65535L;
			siz-=65535L;
			playseg+=65535L;
		}
		else
		{
			sndplay.sndlen = (int) siz;
			siz = 0L;
		}
		MassageAudio(&sndplay);
	} while ( siz != 0L );			// Pre-format sound data.

	playseg = begin;
	siz = start;

	do
	{
		sndplay.sound = playseg;
		if ( siz > 65535L  )
		{
			sndplay.sndlen = 65535L;
			siz-=65535L;
			playseg+=65535L;
		}
		else
		{
			sndplay.sndlen = (int) siz;
			siz = 0L;
		}
		do
		{
			if ( kbhit() ) xcon = 1; // If user presses a key, abort sound playback.
		} while ( SoundStatus() );	 // Wait while previous sound effect is playing.
		if ( !xcon ) DigPlay2(&sndplay);
	} while ( siz != 0L && !xcon );

	return( begin ); // Return address of memory.
}

void far *FileLoad(char *fname,long int *siz)
{
	unsigned char far *data;
	FILE *fph;
	long int insiz;

	fph = fopen(fname, "rb");
	if ( fph == NULL ) return(0);
	fseek( fph, 0L, SEEK_END);
	insiz = ftell( fph );
	fseek( fph, 0L, SEEK_SET);
	data = farmalloc(insiz);    // Allocate memory to read sound file in.
	if ( !data )
	{
		fclose(fph);
		return(0);
	}
	fread(data, insiz, 1, fph); // Read sound data into memory.
	fclose(fph); // Close out the file.
	*siz = insiz; // Assign total size.
	return(data);
}
