/*****************************************************************************/
/* PEND.C -> Plays a digital sound effect using the PostAudioPending calls.  */
/* Written by John W. Ratcliff, September 1992, needs to link to						 */
/* DIGPLAY.OBJ, DOSCALLS.OBJ. 																							 */
/*****************************************************************************/
#include <conio.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <alloc.h>

#include "digplay.h"    // Include DIGPLAY header.
#include "doscalls.h"   // Include DOS tools header.
#include "video.h"      // Include header for VGA graphics tools.
#include "loader.h"      // Include header for VGA graphics tools.

// Define memory allocation functions.	If using DOS memory allocation
// functions, provided through DOSCALLS, then set the conditional compilation
// 'DOSALLOC' to true.  If using C compiler library function memory allocation
// set 'DOSALLOC' to zero.

#define DOSALLOC 0
// Redirect memory allocation to either DOS memory allocate functions located
// in DOSCALLS or to C library far memory allocation functions.
unsigned char far * far memalloc(long int siz)
{
	#if DOSALLOC
		return(fmalloc(siz));  // DOS far memory allocation functions
	#else
		return(farmalloc(siz)); // C's far memory allocation functions.
	#endif
}

void far memfree(char far *memory)
{
	#if DOSALLOC
		ffree(memory);
	#else
		farfree(memory);
	#endif
}

unsigned char far * far memalloc(long int siz); // Our application provided memory allocation functions.
void far memfree(char far *memory); // Application provided free memory allocate function.

int PendingStatus(void);
void PostPending(SNDSTRUC far *snd);

#define SWID 320	// Width of sound data.

char save[SWID];
char buffer[SWID*2];
char far *currentbuffer;
int AUTOINITDMA;
int DMALOAD;

void main(int argc,char **argv)
{
	char far *effect;
	char far *sound;
  long int siz;
	int soundsize;
	int xcon=0;
	SNDSTRUC snd;

	if ( argc != 2 )
	{
		printf("Usage: PEND <filename>\n");
		exit(1);
	}


	effect = fload(argv[1], &siz);
	if ( !effect )
	{
		printf("File '%s' not found, or too large to play.\n",argv[1]);
		exit(1);
	}


	if ( !LoadDigPak("SOUNDRV.COM") )
	{
		printf("Failed to load sound driver.\n");
		exit(1);
	}

	if ( !InitDigPak() )
	{
		UnLoadDigPak();
		printf("Failed to initialize sound driver.\n");
		exit(1);
	}

	AUTOINITDMA = 0; // off by default.


	sound = effect;
	currentbuffer = buffer;
	snd.sndlen = SWID;
	snd.frequency = 11025;
	soundsize = siz;

	if ( AudioCapabilities()&DMABACKFILL )
	{
		if ( VerifyDMA(buffer,SWID*2) )
		{
			AUTOINITDMA = 1;
			DMALOAD = SWID; // First load time.
			NullSound(buffer,SWID*2,0x80);
			farmov(buffer,sound,SWID*2);
			snd.sound = buffer;
			snd.sndlen = SWID*2;
			snd.frequency = 11025;
			SetBackFillMode(1);
			sound += SWID*2;
			siz -= SWID*2;
			DigPlay(&snd);	// Start auto-init dma backfill...
		}
		else
		{
			printf("DMA buffer crosses segment boundary\n");
			exit(1);
		}
	}

	VidOn();

	do
	{
		if (PendingStatus() != PENDINGSOUND)
		{
			farmov(currentbuffer,sound,SWID); // Move into buffer area the audio data.
			snd.sound = currentbuffer; // Set address of play sound location.
			MassageAudio(&snd);
			PostPending(&snd);

			DrawSound(save,320,0); // Erase previous.
			DrawSound(currentbuffer,320,15); // draw the new one.
			farmov(save,currentbuffer,320);

			if ( currentbuffer == buffer ) // Perform flip-flop
				currentbuffer = buffer+SWID;
			else
				currentbuffer = buffer;
			sound+=SWID;	// Advance source sound effect address.
			siz-=SWID;	// Decrement size left to processs.
			if (siz < SWID)
				xcon = 1;
		}
		if (keystat())
			xcon = 1;
	} while (!xcon);

	if (AUTOINITDMA)
	{
		StopSound();
		SetBackFillMode(0);  // Turn DMA back fill mode off!
	}

	VidOff();

	if ( AUTOINITDMA )
		printf("The current driver played this effect IN DMABACKFILL mode.\n");
	else
		printf("Current sound driver NOT in DMABACKFILL mode.\n");
	printf("Now playing sound effect one more time, NOT in DMA mode.\n");
	snd.sndlen = soundsize;
	snd.sound = effect;
	DigPlay(&snd); // Replay sound effect.

	WaitSound();
	UnLoadDigPak();

}


void PostPending(SNDSTRUC far *snd)
{
	if ( AUTOINITDMA==0 ) PostAudioPending(snd);
}

int PendingStatus(void)
{
	int pend;
	int count;

	if (AUTOINITDMA)
	{
		pend = PENDINGSOUND;
		count = ReportDMAC();
		if ( DMALOAD && count < DMALOAD)
		{
			pend = PLAYINGNOTPENDING;
			DMALOAD = 0;
		}
		else
		{
			if (!DMALOAD && count >= SWID )
			{
				pend = PLAYINGNOTPENDING;
				DMALOAD = SWID;
			}
		}
	}
	else
		pend = AudioPendingStatus();

	return(pend);
}
