
#ifndef LOADABLE_DRIVERS
#define LOADABLE_DRIVERS 1 // Conditional compilation, set to true if
													 // Supporting loadable drivers.
#endif

/* Bit flags to denote audio driver capabilities. */
/* returned by the AudioCapabilities call.				*/
#define PLAYBACK 1    // Bit zero true if can play audio in the background.
#define MASSAGE  2    // Bit one is true if data is massaged.
#define FIXEDFREQ 4   // Bit two is true if driver plays at fixed frequency.
#define USESTIMER 8   // Bit three is true, if driver uses timer.
#define SHARESTIMER 16 // Bit 4, timer can be shared (BETA!!!!!)
#define LOOPEND 32		// bit 5, support looped samples, and pending sounds (BETA!!!)
#define STEREOPAN 64	// Bit 6, supports stereo panning.
#define STEREOPLAY 128 // Bit 7, supports 8 bit PCM stereo playback.
#define AUDIORECORD 256 // Bit 8, supports audio recording!
#define DMABACKFILL 512  // Bit 9, support DMA backfilling.
#define PCM16 1024			// Bit 10, supports 16 bit digital audio.

typedef struct
{
  char far *sound;     // address of audio data.
  unsigned int sndlen; // Length of audio sample.
  int far  *IsPlaying; // Address of play status flag.
  int	   frequency;  // Playback frequency.
} SNDSTRUC;

int  far DigPlay(SNDSTRUC far *sndplay); // 688h -> Play 8 bit digitized sound.
int  far SoundStatus(void);  // 689h -> Report sound driver status.
void far MassageAudio(SNDSTRUC far *sndplay); // 68Ah -> Preformat 8 bit digitized sound.
void far DigPlay2(SNDSTRUC far *sndplay); // 68Bh -> Play preformatted data.
int  far AudioCapabilities(void); // 68Ch -> Report audio driver capabilities.
int  far DigPakIdentityString(char far *str); // 68Ch -> reports ID string of
					      // sound driver. returns string length.
int  far ReportSample(void); // 68Dh -> Report current sample address.
void far SetCallBackAddress(void far *proc); // 68Eh -> Set procedure callback address.
void far StopSound(void); // 68Fh -> Stop current sound from playing.
void far *far ReportCallbackAddress(void); // 691h -> report current callback address.
void far DigPlayLoop(SNDSTRUC far *sndplay);
int  far PostAudioPending(SNDSTRUC far *sndplay);

#define NOTPLAYING 0  // No sound is playing.
#define PLAYINGNOTPENDING 1 // Playing a sound, but no sound is pending.
#define PENDINGSOUND 2			// Playing, and a sound is pending.
int  far AudioPendingStatus(void);

#define FULLRIGHT 0
#define FULLLEFT 127
#define FRONTANDCENTER 64
int far SetStereoPan(int panvalue); // 0-127, 0 full right.
																		//			 64 full volume both.
																		//			127 full volume left.


#define PCM_8_MONO 0
#define PCM_8_STEREO 1
#define PCM_16_MONO 2
#define PCM_16_STEREO 3
int far SetPlayMode(int playmode);
// Return 0 if mode not available, 1 if mode set.

int far SetRecordMode(int mode); // Set audio recording mode.

int far * far ReportPendingAddress(void); // Reports the far address of the pending
// flag.	If this memory location pointed to by this address is 1 that means
// a pending sound effect is still pending.  When this becomes zero, then your
// application software can post the next piece of audio to play.  It is
// preferable to use this semaphore to know when to post the next buffer
// rather than to use the AudioPendingStatus call.

int far *ReportSemaphoreAddress(void); // Reports the far address of the DigPak
// semaphore.  If this semaphore is true, then DigPak is currently active
// and you shouldn't post any DigPak calls.  This is EXTREMELY important if
// you are trying to invoke DigPak functions via a hardware interrupt, where
// you could potentially have interrupted DigPak itself.

void far SetTimerDivisorRate(int rate); // Set the 8253 timer divisor rate.
// If your program, has reprogrammed the 8253 timer to another rate, then
// you must be sure to tell DigPak what that reprogrammed rate it.  Be
// sure to set this BACK to zero when your program exits!!!

int far ReportVersionNumber(void); // Report the DigPak version number.
// Return code is times 100, meaning that version 3.1 would be returned
// as the decimal number 310.  This function wasn't supported prior to
// version 3.1 release, so it will be returned as 0, for versions prior
// to 3.1.

void far StopNextLoop(void); // If a digital sound sample is looping,
// this call will cause it to stop looping, the next time it has
// finished.

int far SetBackFillMode(int mode); // Turn DMA backfill mode on/off, return code
// of 1 means mode was set.  Return code of 0 means driver doesn't support
// DMA backfill.

unsigned int far ReportDMAC(void); // Report current DMA counter.

int far VerifyDMA(char far *data,int length); // Verify this buffer block
// doesn't cross a 64k boundary.  Return code of 1 means the block is OK.
// return code of 0 means the block can't be used, try another.

void far NullSound(char far *sound,int sndlen);

void far SetPCMVolume(int left,int right); // Set PCM volume, in hardware.

/* Support routines */
void far WaitSound(void); // Wait until sound playback completed.
int  far CheckIn(void);   // Is sound driver available? 0 no, 1 yes.

/******************************************************************************/
/* Warning, it you enable LOADABLE_DRIVERS you must prodivde memory allocation*/
/* functions, and access to DOSCALLS.OBJ.				      */
/******************************************************************************/
#if LOADABLE_DRIVERS
int  far LoadSoundDriver(char far *name);  // Load a sound driver by filename, 1 success 0 fail.
void far UnloadSoundDriver(void); // Unload a previously loaded sound driver.
#endif
