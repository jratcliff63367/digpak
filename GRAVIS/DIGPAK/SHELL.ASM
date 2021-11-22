
        LOCALS                  ;; Enable local labels

        IDEAL                   ;; Use Turbo Assembler's IDEAL mode
	JUMPS
	P386

        INCLUDE "PROLOGUE.MAC"          ;; common prologue
	INCLUDE "ultmidi.inc"

VERSION_NUMBER	equ	340

ISEXE		equ	0
ISCOM		equ	1

PLAYBACK	equ	1	;0
MASSAGE 	equ	2	;1
FIXEDFREQ	equ	4	;2
USESTIMER	equ	8	;3
SHARESTIMER	equ	16	;4 True if supports timer sharing.
LOOPEND 	equ	32	;5 Supports looping,and pending sounds.
STEREOPAN	equ	64	;6 supports stereo panning.
STEREOPLAY	equ	128	;7 Supports stereo playback!
AUDIORECORD	equ	256	;8 support digital sound recording.
DMABACKFILL     equ     512     ;9 DMA backfill
PCM16           equ     1024
PCM16STEREO     equ     2048


Struc	SOUNDSPEC

PLAYADR FARPTR	<>	; Address of sound sample to be played.
PLAYLEN dw	?	; Length of sound sample to be played.
ISPLAYING FARPTR <>	 ; Address of our playing sample semephore.
FREQUENCY dw	?	; Frequency to play it at.

	Ends

Macro	IN_TSR
	push	ds
	push	es
	push	si
	push	di
	mov	ax,cs
	mov	ds,ax
	mov	es,ax
	endm

Macro	OUT_TSR
	pop	di
	pop	si
	pop	es
	pop	ds
	endm

Macro	WaitSound
	LOCAL	@@WT
@@WT:	mov	ax,689h
	int	66h
	or	ax,ax
	jnz	@@WT
	endm

Macro	Dally
	jmp	$+2
	endm

Macro	ConvertDPMI seg,indx
	LOCAL	@@HOP
	cmp	[cs:DPMI],0	; In 32 bit DPMI mode?
	je	@@HOP
	push	eax		; Save EAX
	mov	eax,indx	; Get the entire 32 bit flat-model address.
	shr	eax,4		; leave just the segment portion.
	mov	seg,ax		 ; place the segment into DS
	and	indx,0Fh	 ; leave just the offset portion.
	pop	eax
@@HOP:
	endm

PCM_8_MONO	equ	0
PCM_8_STEREO	equ	1
PCM_16_MONO	equ	2
PCM_16_STEREO	equ	3

KINT	equ	66h

SEGMENT  _TEXT PARA PUBLIC 'CODE'
        ENDS

	ASSUME	CS: _TEXT, DS: _TEXT, SS: NOTHING, ES: NOTHING


SEGMENT _TEXT
IF	ISCOM
	org	100h
ENDIF

START:
	jmp	LoadSound		; Load the digitized sound driver
	db	"DIGPAK",0,13,10        ; Digitized Sound Package Identity String
IDENTIFIER:
;; =============[*][	     1	       2	 3	    ]
;; =============[*][1234567890123456789012345678901234567890]
        db      "Advanced Gravis UltraSound",0,13,10
	db	"The Audio Solution, Copyright (c) 1993",0,13,10
	db	"Written by John W. Ratcliff",0,13,10

IF	ISCOM
	org	200h		; Beginning address of jumps.
	jmp	InstallInterupt 	; Install the interupt vector.
	jmp	DeInstallInterupt	; De-install the interupt.
ENDIF
;; Unique data areas to individual hardware implementations.
_io_addx	dw	-1	    ; Default I/O address.
_intr_num	dw	-1	    ; Default is interupt #7
fixed_dma	dw	-1	    ; hard coded to dma #1 righ now.

JumpTable	dw	offset	FUNCT1
		dw	offset	FUNCT2
		dw	offset	FUNCT3
		dw	offset	FUNCT4
		dw	offset	FUNCT5
		dw	offset	FUNCT6
		dw	offset	FUNCT7
		dw	offset	FUNCT8
		dw	offset	FUNCT9
		dw	offset	FUNCTA
		dw	offset	FUNCTB
		dw	offset	FUNCTC
		dw	offset	FUNCTD
		dw	offset	FUNCTE
		dw	offset	FUNCTF
		dw	offset	FUNCT10
		dw	offset	FUNCT11
		dw	offset	FUNCT12
		dw	offset	FUNCT13
		dw	offset	FUNCT14
		dw	offset	FUNCT15 ; Set DMA backfill mode.
		dw	offset	FUNCT16 ; Report DMAC count.
		dw	offset	FUNCT17 ; Verify DMA block.
		dw	offset	FUNCT18 ; Set PCM volume.
		dw	offset	FUNCT19 ; set 32 bit register mode

JumpPtr         dw      ?
st_mem		db 2*1024 dup (?)
	INCLUDE "vol.inc"
umss		um_sound_struct <>		     ;UltraMID sound structure
playing		dw ?
playseg		dw ?
chk_hook_str	db	'ULTRAMID', 0
label		gf1hook	dword
hookoff		dw	0
hookseg		dw	0

_voice_status	dw	0
CallBacks	dw	0	; Callback to application flag.
LABEL		CALLBACK	DWORD	     ; Callback address label.
CallLow 	dw	0	; Low word of callback address.
CallHigh	dw	0	; High word of callback address.
CallDS		dw	0	; Value of DS register at callback time.

DivisorRate	dw	0	; Default divisor rate.

PlayMode	dw	PCM_8_MONO	; Default play mode is 8 bit PCM.

INDIGPAK	dw	0

;; Set's the DIGPAK semaphore
Macro	SetSemaphore
	mov	[cs:INDIGPAK],1
	endm

;; Clear's the semaphore, and does an IRET
Macro	ClearSemaphoreIRET
	mov	[cs:INDIGPAK],0
	iret
	endm

Macro	ClearSemaphore
	mov	[cs:INDIGPAK],0
	endm

DPMI		dw	0

;; Data used by Kernel interupt
KJUMP	FARPTR	<>		; Address
OLDIN	FARPTR	<>		; Original interupt vector.
ID      db      'KERN'          ; 4B45524Eh Interupt identifier string.
IND     db      'KR'            ; 4B52h indicates a kernel installed interupt.

        public SoundInterupt
Proc	SoundInterupt far
;;; Usage: DS:SI -> point to sound structure to play.
;; FUNCT1  AX = 0688h	 DigPlay
;; FUNCT2  AX = 0689h	 Sound Status
;; FUNCT3  AX = 068Ah	 Massage Audio
;; FUNCT4  AX = 068Bh	 DigPlay2, pre-massaged audio.
;; FUNCT5  AX = 068Ch	 Report audio capabilities.
;; FUNCT6  AX = 068Dh	 Report playback address.
;; FUNCT7  AX = 068Eh	 Set Callback address.
;; FUNCT8  AX = 068Fh	 Stop Sound.
;; FUNCT9  AX = 0690h	 Set Hardware addresses.
;; FUNCTA  AX = 0691h	 Report Current callback address.
;; FUNCTB  AX = 0692h	 Restore hardware vectors.
;; FUNCTC  AX = 0693h	 Set Timer Divisor Sharing Rate
;; FUNCTD  AX = 0694h	 Play preformatted loop
;; FUNCTE  AX = 0695h	 Post Pending Audio
;; FUNCTF  AX = 0696h	 Report Pending Status
;; FUNCT10 AX = 0697h	 Set Stereo Panning value.
;; FUNCT11 AX = 698h	 Set DigPak Play mode.
;; FUNCT12 AX = 699h	 Report Address of pending status flag.
;; FUNCT13 AX = 69Ah	 Set Recording mode 0 off 1 on.
;; FUNCT14 AX = 69Bh	 StopNextLoop
;; FUNCT15 AX = 69Ch	 Set DMA backfill mode.
;; FUNCT16 AX = 69Dh	 Report current DMAC count.
;; FUNCT17 AX = 69Eh	 Verify DMA block.
;; FUNCT18 AX = 69Fh	 Set PCM volume.
;; FUNCT19 AX = 6A0h	 Set DPMI mode
	cmp	ax,0688h
	jb	@@CHAIN
	cmp	ax,06A0h
	ja	@@CHAIN

	SetSemaphore		; Set the inside DigPak semaphore
	sti

	sub	ax,0688h
	shl	ax,1
	add	ax,offset JumpTable
	xchg	ax,bx
	mov	bx,[cs:bx]
	xchg	ax,bx
	mov	[cs:JumpPtr],ax
	jmp	[cs:JumpPtr]	;; Near jump will be modified!!
@@CHAIN:
	cmp	[OLDIN.XPTR.POFF],0
	jne	@@CHAIN1
	cmp	[OLDIN.XPTR.PSEG],0
	je	@@IRET
@@CHAIN1:
	jmp	[cs:OLDIN.DPTR] 	; Chain to original interrupt vector.
@@IRET:
	ClearSemaphoreIRET
	endp


FUNCT1:
;;**************************************************************************
;:Function #1: DigPlay, Play an 8 bit digitized sound.
;:
;:	  INPUT:  AX = 688h    Command number.
;:		  DS:SI        Point to a sound structure that
;:			       describes the sound effect to be played.
;;**************************************************************************
	PushCREGS

	ConvertDPMI ds,esi
	call	CompleteSound
	call	SetAudio
	call	PlaySound

	PopCREGS
	ClearSemaphoreIRET
FUNCT2:
;;**************************************************************************
;:Function #2: SoundStatus, Check current status of sound driver.
;:
;:	  INPUT:  AX = 689h
;:	  OUTPUT: AX = 0       No sound is playing.
;:		     = 1       Sound effect currently playing.
;;		    DX = 1	 Looping a sound effect
;;		  BX = Version numer, in decimal, times 100, so that 3.20
;;		       would be 300.  Version number begins with version 3.10
;;		       which includes the DigPak semaphore.
;;**************************************************************************
	mov	bx,VERSION_NUMBER  ; Return VERSION NUMBER in BX! 3.20
	cmp	[cs:LOOPING],1	; Looping a sample?
	jne	@@REP
	mov	ax,1
	mov	dx,1		; Return high word looping flag.
	ClearSemaphoreIRET
@@REP:
	mov	ax,[cs:_voice_status]
	xor	dx,dx		; Not looping
	ClearSemaphoreIRET
FUNCT3:
;;**************************************************************************
;:Function #3: MassageAudio, Preformat audio data into ouptut hardware format.
;:
;:	  INPUT:  AX = 68Ah
;:		  DS:SI        Point to address of sound structure.
;;**************************************************************************
	ClearSemaphoreIRET
FUNCT4:
;;**************************************************************************
;:Function #4: DigPlay2, Play preformatted audio data.
;:
;:	  INPUT:  AX = 68Bh
;:		  DS:SI        Point to address of sound structure.
;;**************************************************************************
	PushCREGS

	ConvertDPMI ds,esi
	call	CompleteSound
	call	DoSoundPlay

	PopCREGS
	ClearSemaphoreIRET
FUNCT5:
;;**************************************************************************
;:Function #5: AudioCapabilities, Report capabilities of hardware device.
;:
;:	  INPUT:  AX = 68Ch
;:	  OUTPUT: AX = Bit 0 -> On, supports background playback.
;:				Off, driver only plays as a foreground process.
;:		       Bit 1 -> On, source data is reformatted for output device.
;:				 Off, device handles raw 8 bit unsigned audio.
;:		       Bit 2 -> On, Device plays back at a fixed frequency, but
;:				    the audio driver will downsample input data
;:				    to fit.
;:				Off, device plays back at user specified frequency.
;:				(NOTE: You can still playback an audio sample at
;:				       whatever frequency you wish.  The driver
;:				       will simply downsample the data to fit
;:				       the output hardware.  Currently it does
;:				       not support upsampling though.)
;:		       Bit 3 -> On, this device uses the timer interrupt vector
;:				during sound playback.
;:		  DX = If this device plays back at a fixed frequency the DX
;:		       register will contain that fixed frequency playback rate.
;;**************************************************************************
	mov	ax,(PLAYBACK OR STEREOPLAY OR LOOPEND OR STEREOPAN OR PCM16 OR PCM16STEREO)
        mov     bx,cs
	lea	cx,[IDENTIFIER]
	ClearSemaphoreIRET
FUNCT6:
;;**************************************************************************
;:Function #6: ReportSample, Report current playback address.
;:
;:	  INPUT:  AX = 68Dh
;:	  OUTPUT: AX = Current playback address.  Obviously this only
;:		       applies to background drivers.  Note that for some
;:		       drivers this playback address is an aproximation
;:		       and not necessarily the EXACT sample location.
;:		       You can use this service to synchronize
;:		       animation or video effects temporaly with the
;:		       audio output.
;;**************************************************************************
	mov	ax, TSR_GET_DIGITAL_POSITION
	call	[cs:gf1hook]
	; far ptr ax:dx needs to be converted to near ptr
	sub	ax, [cs:playseg]
	shl	ax, 2
	add	ax, dx
	ClearSemaphoreIRET
FUNCT7:
;;**************************************************************************
;:Function #7: SetCallBackAddress, sets a user's sound completion
;:		       callback addess.
;:
;:	  INPUT: AX = 068Eh
;:		 BX = Offset portion of far procedure to callback.
;:		 DX = Segment portion of far procedure to callback.
;:		 DS = Data Segment register value to load at callback time.
;:	  OUTPUT: None.
;:
;:		 This function allows the user to specify a callback
;:		 address of a far procedure to be invoked when a sound
;:		 effect has completed being played.  This function is
;:		 disabled by default.  Sending a valid address to this
;:		 function will cause a callback to occur whenever a sound
;:		 sample has completed being played.  The callers DS register
;:		 will be loaded for him at callback time.  Be very careful
;:		 when using this feature.  The application callback procedure
;:		 is being invoked typically during a hardware interupt.
;:		 Your application should spend a small an amount of time
;:		 as possible during this callback.  Remember that the
;:		 callback must be a far procedure.  The sound driver
;:		 preserves ALL registers so your callback function does
;:		 not need to do so.  Do not perform any DOS functions
;:		 during callback time because DOS is not re-entrent.
;:		 Keep in mind that your own application has been interupted
;:		 by the hardware it this point.  Be very careful when making
;:		 assumptions about the state of your application during
;:		 callback time.  Hardware callbacks are generally used
;:		 to communicate sound event information to the application
;:		 or to perform a technique called double-buffering, whereby
;:		 your application immediatly posts another sound effect to
;:		 be played at the exact time that the last sound effect
;:		 has completed.
;:
;:		 WARNING!!! Be sure to turn off hardware callbacks when
;:		 your application leaves!!! Otherwise, harware callbacks
;:		 will be pointing off into memory that no longer contains
;:		 code.	This function is for advanced programmers only.
;;**************************************************************************
	or	bx,bx
	jnz	@@SC1
	or	dx,dx
	jnz	@@SC1
	xor	ax,ax
	mov	[cs:CallBacks],ax		; Callbacks disabled.
	mov	[cs:CallLow],ax 		; Low address.
	mov	[cs:CallHigh],ax
	jmp	@@EXIT
@@SC1:	mov	[cs:CallLow],bx
	mov	[cs:CallHigh],dx
	mov	[cs:CallDS],ds
	mov	[cs:CallBacks],1

@@EXIT:
	ClearSemaphoreIRET
FUNCT8:
;;**************************************************************************
;:Function #8: StopSound, stop currently playing sound.
;:
;:	  INPUT: AX = 68Fh
;:	  OUTPUT: None.
;:
;:		Will cause any currently playing sound effect to be
;:		terminated.
;;**************************************************************************
	mov	[cs:PENDING],0	; Turn pending flag OFF when stop-sound called.
	mov	[word cs:LOOPING],0
	call	StopSound
	ClearSemaphoreIRET
FUNCT9:
;;**************************************************************************
;:Function #9: SetAudioHardware, set up hardware information.
;:
;:	  INPUT: AX = 690h
;:		 BX = IRQ if device needs one set.
;:		 CX = BASE I/O Address, if device needs one set.
;:		 DX = OTHER, some other possible information the hardware might need.
;:
;:	  OUTPUT: NONE.
;:
;:
;:	  Certain harware can be reconfigured to different IRQ and base
;:	  address settings.  This function call allows the application
;:	  programmer to overide these default settings.  The interpretation
;:	  of these parameters might change from driver to driver.  Currently
;:	  only the SBLASTER (Creative Labs SoundBlaster) driver can be
;:	  reconfigured, upon request of Derek Smart.
;;**************************************************************************

	ClearSemaphoreIRET
FUNCTA:
;;**************************************************************************
;;FUNCTION #10: ReportCallbackAddress
;;
;;	  INPUT: AX = 691h
;;	  OUTPUT: AX:DX -> far pointer to current callback address.
;;		  BX -> original caller's DS register.
;;
;;	  This function should probably never need to be used by your
;;	  application software.  It is provided because the MIDPAK,
;;	  MIDI driver, needs to revector hardware callbacks so that
;;	  it can handle hardware contention problems between digitized
;;	  sound playback and synthesized sound playback.
;;**************************************************************************
	mov	ax,[cs:CallLow]
	mov	dx,[cs:CallHigh]
	mov	bx,[cs:CallDS]
	ClearSemaphoreIRET
FUNCTB:
;;**************************************************************************
;;FUNCTION #11: RestoreHardware
;;
;;	  INPUT: AX = 692h
;;	  OUTPUT:
;;
;;		Put hardware back to initial state.  Invoked by the
;;		DeInstall code.  Not to be called by an application program!
;;**************************************************************************
	mov	[cs:CallBacks],0	;
	mov	[word cs:CallBack],0
	mov	[word cs:CallBack+2],0
	mov	[cs:PENDING],0
	mov	[word cs:LOOPING],0
	call	StopSound
	mov	ax,TSR_FREE_MEMORY
	mov	dx,[word cs:umss.um_gf1mem.XPTR.POFF]
	mov	bx,[word cs:umss.um_gf1mem.XPTR.PSEG]
	call	[cs:gf1hook]
	mov	ax, TSR_CLEAR_EXTERNAL_SEMAPHORE
	mov	bx, cs
	lea	dx,[INDIGPAK]
	call	[cs:gf1hook]
	mov	ax, TSR_APP_END
	call	[cs:gf1hook]
	ClearSemaphoreIRET
FUNCTC:
;;**************************************************************************
;; FUNCTION #12: SetTimerDivsorRate
;;
;;	   INPUT: AX = 693h
;;		  DX = Countdown timer divisor rate, so that timer based
;;		       drivers can service application timer interrupts
;;		       at their previous rate.	Service rate will be an
;;		       aproximation, that is fairly close.  To reset timer
;;		       divisor to default of 18.2 pass a 0 in the DX register.
;;**************************************************************************
	mov	[cs:DivisorRate],dx    ; Set timer divisor rate.
	ClearSemaphoreIRET
FUNCTD:
;;**************************************************************************
;; FUNCTION #13: DigPlayLoop
;;
;;	   INPUT: AX = 694h
;;		  DS:SI ->sound structure, preformated data.
;; Here's the process...
;;	Remember the current callback address.
;;	Set new callback address to US!
;;	Save sound structure.
;;	Call DigPlay.
;;	At call back, keep playing.
;;	This gets done until StopSound is called.
;;	Stop sound checks to see if we need to restore the callback address.
;;	If PlaySound is invoked, and we are currently looping a sound then
;;	stopsound is invoked.
;;**************************************************************************
	PushCREGS
	ConvertDPMI ds,esi
	push	cs
	pop	es
	lea	di,[LOOPSND]
	mov	cx,SIZE LOOPSND
	rep	movsb
	mov	ax,068Fh	; Stop any currently playing sound.
	int	66h		; do it.
	mov	[cs:LOOPING],1	   ; We are now looping a sound sample.
	push	cs
	pop	ds
	lea	si,[LOOPSND]
	mov	ax,068Bh	; Do FUNCT4
	PopCREGS
	jmp	FUNCT4		; Do a DigPlay2
FUNCTE:
;;**************************************************************************
;; FUNCTION #14: PostAudioPending
;;
;;	   INPUT: AX = 695h
;;		  DS:SI ->sound structure, preformated data.
;;	   OUTPUT: AX = 0  Sound was started playing.
;;		   AX = 1  Sound was posted as pending to play.
;;**************************************************************************
	PushCREGS
	ConvertDPMI ds,esi
	cli    ; Turn off interupts while making this determination.
	mov	ax,[cs:_voice_status]
	or	ax,ax		; Currently playing a sound?
	jnz	@@POST		; yes->try to post pending.
	sti			; We can play it now.
	call	DoSoundPlay	;
	xor	ax,ax		; Return, audio sample is now playing.
	PopCREGS
	ClearSemaphoreIRET
@@POST: cmp	[cs:PENDING],1	; Already have a pending sound effect?
	jne	@@POST2 	; no, post it for pending play.
	mov	ax,2		; return code of two.
	PopCREGS
	ClearSemaphoreIRET
@@POST2:mov	[cs:PENDING],1
	push	cs
	pop	es
	lea	di,[PENDSND]	; Pending sound.
	mov	cx,SIZE PENDSND
	rep	movsb
	mov	[cs:PENDING],1
	mov	ax,1		; Posted as pending.
	PopCREGS
	ClearSemaphoreIRET
FUNCTF:
;;**************************************************************************
;; FUNCTION #15: AudioPendingStatus
;;
;;	INPUT:	AX = 696h
;;
;;	OUTPUT: AX = 0 No sound is playing.
;;		AX = 1 Sound playing, sound pending.
;;		AX = 2 Sound playing, no sound pending.
;;**************************************************************************
	cli		; Clear interrupts while we make this determination.
	mov	ax,[cs:_voice_status]
	or	ax,ax		; Currently playing a sound?
	jnz	@@POST		; yes->try to post pending.
	ClearSemaphoreIRET
@@POST: cmp	[cs:PENDING],1	; Have a sound pending?
	je	@@PEND		; yes, return pending status.
	mov	ax,1		; Sound is playing, but no sound is pending.
	ClearSemaphoreIRET
@@PEND:
	mov	ax,2
	ClearSemaphoreIRET
FUNCT10:
;;**************************************************************************
;; FUNCTION #16: SetStereoPan
;;
;;	   INPUT: AX = 697h
;;		  DX = stereo pan value. 0 full volume right.
;;					64 full volume both.
;;				       127 full volume left.
;;	 OUTPUT: AX = 0 command ignored, driver doesn't support stereo panning.
;;		 AX = 1 pan set.
;;**************************************************************************
	mov	ax, 127
	sub	ax, dx
	mov	cl, 3
	shr	ax, cl
	mov	[cs:umss.um_pan], al
	cmp	[cs:playing],0
	je	@@ret
	mov	ax, TSR_SET_PAN
	mov	cx, [cs:playing]
	dec	cx
	call	[cs:gf1hook]
@@ret:	mov	ax, 1
	ClearSemaphoreIRET
FUNCT11:
;;**************************************************************************
;; FUNCTION #17: SetPlayMode
;;
;;	   INPUT: AX = 698h
;;		  DX = Play Mode function.
;;			  DX = 0 -> 8 bit PCM
;;			     = 1 -> 8 bit Stereo PCM (left/right)
;;			     = 2 -> 16 bit PCM
;;			     = 3 -> 16 bit PCM stereo.
;;
;;	 OUTPUT: AX = 1 -> mode set.
;;		 AX = 0 -> mode not supported by this driver.
;;
;;**************************************************************************
	mov	[cs:PlayMode],dx
	mov	ax,1		; Set!
	ClearSemaphoreIRET
FUNCT12:
;;**************************************************************************
;; FUNCTION #18: Report Address of Pending Flag
;;
;;	   INPUT: AX = 699h
;;
;;	 OUTPUT: AX:DX -> form far address of pending status flag.
;;		 BX:DX -> form address of DigPak interrupt semaphore.
;;
;;**************************************************************************
	mov	dx,cs		; Code segment.
	lea	ax,[PENDING]	; Address of pending flag.
	lea	bx,[INDIGPAK]	; Address of semaphore address.
	ClearSemaphoreIRET

FUNCT13:
;;**************************************************************************
;; FUNCTION #19: Set audio recording mode.
;;
;;	   INPUT: AX = 69Ah
;;		  DX = 0 turn audio recording ON.
;;		     = 1 turn audio recording OFF.
;;
;;	 OUTPUT: AX = 0 sound driver doesn't support audio recording.
;;		 AX = 1 audio recording mode is set.
;;
;;**************************************************************************
	mov	ax,0
	ClearSemaphoreIRET

FUNCT14:
;;**************************************************************************
;; FUNCTION #20: StopNextLoop
;;
;;	   INPUT: AX = 69Bh
;;
;;	   OUTPUT: NOTHING, Stop Looped sample, next time around.
;;
;;**************************************************************************
	mov	[cs:CallBacks],0
	mov	[cs:LOOPING],0
	ClearSemaphoreIRET
FUNCT15:
;;**************************************************************************
;; FUNCTION #21: Set DMA back fill mode.
;;
;;	   INPUT: AX = 69Ch
;;		  BX = backfill mode 0 means turn it off.
;;		       and a 1 means to turn it off.
;;
;;	   OUTPUT: AX = 1 -> back fill mode set.
;;			0 -> driver doesn't support DMA backfill.
;;
;;**************************************************************************
	; The UltraSound supports this type of buffering internal to
        ; the sound card.  UltraSound can't use autoinit DMA mode because
        ; the DMA xfer rate is 680Kb/s and most sound is played at 8Kb/s,
        ; 11Kb/s or 22Kb/s.
	xor	ax,ax		; Not a backfill driver.
	ClearSemaphoreIRET
FUNCT16:
;;**************************************************************************
;; FUNCTION #22: Report current DMAC count.
;;
;;	   INPUT: AX = 69Dh
;;
;;	   OUTPUT: AX = Current DMAC count.
;;
;;**************************************************************************
	ClearSemaphoreIRET
FUNCT17:
;;**************************************************************************
;; FUNCTION #23: Verify DMA block, check to see if it crosses a 64k page
;;		 boundary for the user.
;;
;;	   INPUT: AX = 69Eh
;;		  ES:BX -> address of sound.
;;		  CX	-> length of sound effect.
;;
;;	   OUTPUT: AX = 1 Block is ok, DOESN'T cross 64k bounadary.
;;		   AX = 0 block failed, DOES cross 64k boundary.
;;
;;**************************************************************************
	; ultrasound card doesn't care about page boundary
	; The UltraMID TSR handles dma xfers across 64K boundaries.
	mov	ax, 1
	ClearSemaphoreIRET

FUNCT18:
;;**************************************************************************
;; FUNCTION #24: Set PCM volume.
;;
;;	   INPUT: AX = 69Eh
;;		  BX = Left channel volume (or both if mono) 0-256
;;		  CX = Right channel volume (or both if mono) 0-256
;;
;;	   OUTPUT: AX = 1 Volume set
;;		   AX = 0 Device doesn't support volume setting.
;;
;;**************************************************************************
	shl	bx,1
	mov	ax,[cs:(bx+gf1_volumes)]
	mov	[cs:umss.um_volume],ax
	cmp	[cs:playing],0
	je	@@ret
	mov	bx, ax
	mov	ax, TSR_SET_VOLUME
	mov	cx, [cs:playing]
	dec	cx
	call	[cs:gf1hook]
@@ret:	mov	ax, 1
	ClearSemaphoreIRET
FUNCT19:
	mov	[cs:DPMI],dx
	ClearSemaphoreIRET

;****************************************************************************
;double buffer callback from UltraMID
Proc	C um_callback	FAR,reason,voice,buff:FAR PTR,bufflen:FAR PTR,bufrate:FAR PTR
	USES	ds,si,di
	push	cs
	pop	ds
                     
	cmp	[reason], UM_STOP_SOUND
	je	@@stop
	cmp	[reason], UM_MORE_DATA
	je	@@more_data
	cmp	[reason], UM_BUFFER_DONE
	je	@@voice_done
	jmp	@@exit

@@more_data:
	cmp	[cs:LOOPING],0
	jne	@@play_loop
	cmp	[cs:PENDING],1
	je	@@pending
	jmp	@@exit

@@play_loop:
	les	di,[buff]
	lds	si,[cs:LOOPSND.PLAYADR.DPTR]
	mov	[cs:playseg], ds
	mov	[word es:di], si
	mov	[word es:di+2], ds
	les	di,[bufflen]
	mov	cx,[cs:LOOPSND.PLAYLEN]
	mov	[word es:di], cx
	mov	[word es:di+2], 0
	les	di,[bufrate]
	mov	ax, [cs:LOOPSND.FREQUENCY]
	mov	[word es:di], ax
	mov	ax, 1
	jmp	@@keep_going
@@pending:
	mov	[cs:PENDING],0
	les	di,[buff]
	lds	si,[cs:PENDSND.PLAYADR.DPTR]
	mov	[cs:playseg], ds
	mov	[word es:di], si
	mov	[word es:di+2], ds
	les	di,[bufflen]
	mov	cx,[cs:PENDSND.PLAYLEN]
	mov	[word es:di], cx
	mov	[word es:di+2],0
	les	di,[bufrate]
	mov	ax, [cs:PENDSND.FREQUENCY]
	mov	[word es:di], ax
	mov	ax, 1
	jmp	@@keep_going
	
@@voice_done:
; flash
;	mov	dx, 3dah
;	in	al, dx
;	mov	dx, 3c0h
;	mov	al, 31h
;	out	dx, al
;	mov	al, 0h
;	out	dx, al
; flash
	jmp	@@exit
@@stop:
	mov	[cs:playing], 0
	mov	[cs:_voice_status], 0
	mov	[cs:LOOPING], 0
@@exit:			
; Tell the O.S. to stop buffering.
	mov	ax, 0
@@keep_going:
	ret
	ENDP

Proc	DoSoundPlay	near
	PushCREGS
	call	SetAudio
	call	PlaySound
	PopCREGS
	ret
	endp


Proc	CheckCallBack	near
	cmp	[cs:CallBacks],0	; Callbacks enabled?
	je	GOUT		; no, exit.
	PushAll 		; Save all registers
	mov	ds,[cs:CallDS]	; Get DS register.
	call	[cs:CallBack]	; far call to application.
	PopAll			; Restore all registers.
GOUT:
	ret
	endp

SAVECALLBACK	dd	?	; Saved callback address.
SAVECALLDS	dw	?
LOOPING 	dw	0	; True if we were looping.

LOOPSND 	SOUNDSPEC	<>

PENDING 	dw	0	; True, when second sound sample is pending.
PENDSND         SOUNDSPEC <>    ; Sound structure of pending sound.

Proc    SetAudio        near
	mov	[ds:(SOUNDSPEC ptr si).ISPLAYING.XPTR.POFF],offset _voice_status
	mov	[ds:(SOUNDSPEC ptr si).ISPLAYING.XPTR.PSEG],cs
	les	bx,[ds:(SOUNDSPEC ptr si).PLAYADR.DPTR]
	mov	cx,[ds:(SOUNDSPEC ptr si).PLAYLEN]
	mov	dx,[ds:(SOUNDSPEC si).FREQUENCY]
	push	cs
	pop	ds		; DS = Code group.
	ret
	endp

Proc	EndLoop near
	mov	[cs:CallBacks],0	;
	mov	[word cs:CallBack],0
	mov	[word cs:CallBack+2],0
	mov	[word cs:LOOPING],0
	call	StopSound
	ret
	endp

Proc	CompleteSound	near
	cmp	[cs:LOOPING],1    ; In loop callback?
	jne	YES
	call	EndLoop 	; don't wait for loop to complete, end it!
YES:
WT:	cmp	[cs:_voice_status],0	 ; Wait until last sound completed.
	jne	WT
	ret
	endp


SMALL_MODEL     equ     1

Macro	CPROC	name		; Macro to establish a C callable procedure.
	public	_&name
IF	SMALL_MODEL
Proc	_&name	near
ELSE
Proc	_&name	far
ENDIF
	endm



ORG_INT_ADDX    dd      ?       ; Original IRQ address.

Macro	INISR
	push	es		; Save registers that are used
	push	ds
	push	di
	push	si
	push	cx
	push	bx
	cld
	mov	ax,cs
	mov	es,ax
	mov	ds,ax		; Establish data addressability.
	endm

Macro	OUTISR
	pop	bx
	pop	cx
	pop	si
	pop	di
	pop	ds
	pop	es
	endm

SPEAKERSTATE	db	-1


Proc	PlaySound	near
;; CX ->number of bytes in sound sample.
;; ES:BX -> far address of sound sample to be played.
;; DX ->rate to play at.

	mov	al, 0
	test    [PlayMode], 1	; check for stereo
	je	@@notst
	or	al, UM_STEREO
@@notst:
	test	[PlayMode], 2	; 16 bit
	jnz	@@16bit
	or	al, UM_8BIT OR UM_INVERT_MSB
@@16bit:
	mov	[cs:umss.um_data_type], al
	mov	[cs:umss.um_sample_rate], dx
	mov	[cs:umss.um_sound_data.XPTR.PSEG], es
	mov	[cs:playseg], es
	mov	[cs:umss.um_sound_data.XPTR.POFF], bx
	mov	[word cs:umss.um_sound_len.XPTR.POFF], cx
	mov	[word cs:umss.um_sound_len.XPTR.PSEG], 0
	mov	[cs:umss.um_priority], 0
	mov	ax, cs
	mov	es, ax
	mov	di, OFFSET umss
	mov	ax, TSR_START_DIGITAL
; flash
;	push	dx
;	push	ax
;	mov	dx, 3dah
;	in	al, dx
;	mov	dx, 3c0h
;	mov	al, 31h
;	out	dx, al
;	mov	al, 1h
;	out	dx, al
;	pop	ax
;	pop	dx
; flash
	call	[cs:gf1hook]
	add	ax,1
	mov	[cs:playing], ax
	jz	@@done
        MOV	[cs:_voice_status],1
@@done:
	ret
	endp

Proc	StopSound	near

        push    ds
        push    cs
        pop     ds

	mov	ax, 1
        CMP     [cs:_voice_status], 0
        JZ      stopped

	mov	cx, [cs:playing]
	dec	cx
	mov	ax, TSR_STOP_DIGITAL
	call	[cs:gf1hook]

	call	CheckCallBack	; Check callbacks.

	SUB    AX,AX

stopped:
        pop     ds
	ret
	endp


Proc	DoCallBacks	near
	cmp	[cs:CallBacks],0
	je	@@GOUT
	PushAll 		; Save all registers
	mov	ds,[cs:CallDS]	; Get DS register.
	call	[cs:CallBack]	; far call to application.
	PopAll			; Restore all registers.
@@GOUT: ret
	endp

LABEL	SUICIDE byte		;; Where to delete ourselves from memory
hard	db	"UltraMID TSR not detected.",13,10,'$'
msg0	db	"UltraSound DIGPAK Sound Driver"
	db	" - Copyright (c) 1992, THE Audio Solution:v3.2",13,10,'$'
msg1	db	"The Sound Driver is already resident.",13,10,'$'
msg1a	 db	 "The Sound Driver is resident, through MIDPAK.",13,10,'$'
msg1b	 db	 "A Sound Driver cannot be loaded on top of MIDPAK.  Unload MIDPAK first.",13,10,'$'
msg2	db	"Unable to install Sound Driver interrupt vector",13,10,'$'
msg2a	db	"UltraSound card out of memory.  Load digpak before midi,",13,10,"or use -c option with UltraMID",13,10,'$'
msg3    db      "Invalid command line",13,10,'$'
msg4	db	"Sound Driver isn't in memory",13,10,'$'
msg5	db	"Sound Driver unloaded",13,10,'$'
msg5a	db	"Sound Driver can't be unloaded, unload MIDPAK first.",13,10,'$'
param   dw      4 dup(?)        ;; Used for parameter passing.
Installed	dw	0

Proc	LoadSound near
	mov	ax,cs	;;
	mov	ds,ax	;; establish data segment

IF	ISEXE
	sub	ax,10h	;;
ENDIF
	mov	es,ax	;; point ES to PSP

	call	CheckIn
	mov	[Installed],ax		;; Save in installed flag.
	call	ParseCommandLine	;; Build a command line.
	cmp	[_argc],0
	je	NoArg
	cmp	[_argc],1
	jne	BC
	mov	bx,[_argv]
	mov	al,[bx]
	cmp	al,'u'
	je	ULOAD
	cmp	al,'U'
	je	ULOAD
BC:
	Message msg3	;; Invalid command line
        DOSTerminate

ULOAD:	mov	ax,[Installed]
	or	ax,ax
	jnz	DOU
	Message msg4	;; wasn't loaded.
	DOSTerminate	;; Terminate with message.
DOU:	cmp	ax,2
	jne	OKU
	Message msg5a
	DOSTerminate
OKU:
	CALLF	DeInstallInterupt
	Message msg5	;; Display message
	DOSTerminate	;; terminate

NoArg:	or	ax,ax	;; Already loaded?
	jz	DOLO	;; no->load it.
	cmp	ax,2
	jne	TEMP
	Message msg1a
	DOSTerminate
TEMP: cmp	ax,3
	jne	TEMPA
	jmp short DOLO
	Message msg1b
	DOSTerminate
TEMPA:
	Message msg1	;; message
	DOSTerminate	;;
DOLO: CALLF	InstallInterupt
	or	ax,ax	;; Was there an error?
	jz	HOP1	;; no->continue
	cmp	ax, 2	;; no memory
	jne	@@ERR
	Message	msg2a
@@ERR:
	Message msg2	;; display the error message
	Message hard	; Hardware error message if there is one.
	DOSTerminate	;; exit to dos
HOP1:
;;; The Kernel is now installed.
;;; Announce the Kernel's presence.
	Message msg0
        DosTSR  SUICIDE         ;; Terminate ourselves bud.
				; Only temporary....
	endp

Proc	InstallInterupt 	far
	IN_TSR

	call	HardwareInit	;; Initialize hardware.
	or	ax,ax		;; Error initializing hardware?
	jnz	@@OUT

	mov	[param],KINT		;; The interupt kernel is going into.
	mov	[param+2],offset SoundInterupt ;; offset of interupt routine
	mov	[param+4],cs		;; Our code segment.
	PushEA	param			;; push the address of the parameter list
	call	InstallInt		;; Install the interupt.
	add	sp,2			;; clean up stack
@@OUT:

	OUT_TSR
	ret
	endp

Proc	DeInstallInterupt	far
	IN_TSR
	mov	[param],KINT		;; Interupt requested to be unloaded.
	PushEA	param			;; pass parameter.
	call	UnLoad			;; Unload it
	add	sp,2			;; clean up stack
	OUT_TSR
	ret
	endp


Proc	CheckIn near
	push	ds		; Save ds register.
	push	si

	mov	si,66h*4h	; get vector number
        xor     ax,ax           ; zero
        mov     ds,ax           ; point it there
	lds	si,[ds:si]	; get address of interupt vector
        or      si,si           ; zero?
        jz      @@CIOUT         ; exit if zero
        sub     si,6            ; point back to identifier

	cmp	[word si],'IM'  ; Midi driver?
	jne	@@NEX
	cmp	[word si+2],'ID'  ; full midi driver identity string?
	jne	@@NEX

;; Ok, a MIDI driver is loaded at this address.
	mov	ax,701h 	; Digitized Sound capabilities request.
	int	66h		; Request.
	or	ax,ax		; digitized sound driver available?
	jnz	@@INMID 	; yes, report that to the caller.
	mov	ax,3		; Not available, but mid pak is in!
	jmp short @@EXT 	; exit with return code.
@@INMID:
	mov	ax,2		; Sound driver resident, through MIDPAK.
	jmp short @@EXT
@@NEX:
	cmp	[word si],454Bh ; equal?
        jne     @@CIOUT         ; exit if not equal
	cmp	[word si+2],4E52h    ; equal?
        jne     @@CIOUT
@@OK:	mov	ax,1
@@EXT:
	pop	si
	pop	ds
	ret
@@CIOUT: xor	ax,ax		; Zero return code.
	jmp short @@EXT
	endp



Proc	InstallINT near
	ARG	DATA:WORD
;; Usage: IntallINT(&parms)
;; offset 0: interupt
;;        2: offset of interupt code
;;        4: segment of interupt code
	PENTER	0
	PushCREGS

	mov	bx,[DATA]	; Get address of parameter table
        mov     ax,[bx]         ; get the interupt vector.
        mov     di,ax           ; save interupt vector into DI as well
        mov     si,[bx+2]       ; get offset
        mov     ds,[bx+4]       ; get segment.
        mov     ah,35h          ; Get interupt vector
        int     21h             ; Do DOS call to get vector.
	mov	[ds:si-10],bx	; Save the old offset.
	mov	[ds:si-8],es	; Save the old segment
        cld
        xor     ax,ax
        mov     es,ax
	ShiftL	di,2		;
        mov     ax,si           ; get offset.
        cli
        stosw
        mov     ax,ds           ; code segment
        stosw                   ; store it.
        sti
        xor     ax,ax           ; Success

	PopCREGS
	PLEAVE
	ret
	endp

Proc	UnLoad near
	ARG	DATA:WORD
;; Usage: UnLoad(&vector)
;; Returns: AX = 0 success
;           AX nonzero, couldn't unload interupt vector.
	PENTER	0
	PushCREGS

	mov	ax,68Fh ; Stop sound playback!
	int	KINT	; Invoke interrupt.
	WaitSound
	mov	ax,692h ; Deinstall hardware vectors.
	int	KINT

	mov	bx,[DATA]	; get address of interupt vector
        mov     bx,[bx]         ; get the interupt vector.
        mov     dx,bx           ; put it into DX as well
	ShiftL	bx,2		;
        xor     ax,ax
        mov     ds,ax           ; Segment zero
	lds	si,[ds:bx]	; get address of interupt vector
        or      si,si           ; zero?
        jz      UOUT          ; exit if zero
	cmp	[WORD ds:si-2],524Bh ;'KR' Is this a kernel installed interupt?
        push    ds              ; save DS
        mov     ax,dx           ; Get interupt vector.
        mov     ah,25h          ; Do DOS 25h set interupt vector.
	mov	dx,[ds:si-10]	 ; get old offset
	mov	ds,[ds:si-8]	; get old segment
        int     21h             ; set interupt vector.
        pop     ax              ; get back segment of program.
IF	ISEXE
        sub     ax,10h          ; point to program's PSP
ENDIF
        mov     es,ax
	push	es
	mov	es,[es:2Ch]	; Environment space.
	mov	ah,49h
	int	21h		; Free it up.
	pop	es
        mov     ah,49h          ; free memory.
        int     21h             ; free up the memory used by us.

EXIT: PopCREGS
	PLEAVE
        ret
UOUT: mov     ax,1
        jmp short EXIT
	endp

;; This procedure parses the command line and builds an array of
;; pointers to each argument.  Arguments are seperated by space's.
;; these spaces get replaced by zero bytes.
_argc	 dw	 0	 ; The argument count
_argv	dw	16 dup(0) ; Up to 16 arguments.
command db	128 dup(?)
Proc	ParseCommandLine	near
	mov	[_argc],0
	cmp	[byte es:80h],2
	jb	@@END
	xor	cx,cx
	mov	cl,[es:80h]	; Get length.
	SwapSegs
	dec	cx		; Less one
	lea	di,[command]
	mov	si,82h
	rep	movsb
	push	cs
	pop	ds
	lea	di,[_argv]	; Argument list.
	lea	si,[command]	; Start address.
@@SET:	inc	[_argc] 	; Increment argument counter.
	mov	ax,si		; Base argument addres.
	stosw
@@NEX:	lodsb			; Get characters until we hit space of eol
	cmp	al,32
	jne	@@NEX2
	mov	[byte ds:si-1],0 ; Turn space into a zero byte.
	jmp short @@SET
@@NEX2:
	cmp	al,13
	je	@@END1
	or	al,al
	jnz	@@NEX		; Keep skipping to next arg.
@@END1: mov	[byte ds:si-1],0	; Zero byte terminate last arg
@@END:
	ret
	endp

;;************************************************************************
;; Unique harware init code.
;;************************************************************************
Proc	HardwareInit	near
	xor	ax,ax		;; success code by default.

GF1_VECTORS	EQU	8
HOOK_STR_SIZE	EQU	8
	push	ds
	push	cs
	pop	ds
; Get the segment and offset for the GF1 hook calls
; Loop from vector 78 to 7f checking for the stamp.
; Set es to first vectors segment.
	mov	al,078h
	mov	cx,GF1_VECTORS
next_vector:
	mov	ah,035h
	int	21h
; es is segment of gf1 driver.
; di is Offset into GF1AIL.COM's vector stamp.
	mov	di,0103H

; ds:si is gf166.com string es:di is hook vectors'
	mov	si,offset chk_hook_str
	push	cx
	mov	cx,HOOK_STR_SIZE
	cld
	repe	cmpsb
	jcxz	vector_valid
; Setup for next vector check.
	pop	cx
	inc	al
	loop	next_vector
	jmp	gf1ail_not_found
vector_valid:
	pop	cx
	pop	ds

	mov	ah,035h
	int	21h
	mov     [cs:hookoff], bx
	mov     [cs:hookseg], es

	mov	ax, TSR_APP_START
	call	[cs:gf1hook]
	; would have DIGPAK use TSR's semaphore, but the report semaphore
	; address function must use the same segment as the pending flag.
	mov	ax, TSR_ADD_EXTERNAL_SEMAPHORE
	mov	bx, cs
	lea	dx,[INDIGPAK]
	call	[cs:gf1hook]

	mov	[cs:umss.um_stereo_mem.XPTR.PSEG], cs
	mov	[cs:umss.um_stereo_mem.XPTR.POFF], OFFSET st_mem
	mov	[cs:umss.um_callback_addr.XPTR.PSEG], cs
	mov	[cs:umss.um_callback_addr.XPTR.POFF], OFFSET um_callback
	mov	[cs:umss.um_pan], 7
	mov	[cs:umss.um_volume], 4095
	mov	ax,TSR_ALLOCATE_MEMORY
	xor	bx,bx
	mov	dx, 8*1024
	call    [cs:gf1hook]
	mov	[word cs:umss.um_gf1mem.XPTR.POFF], ax
	mov	[word cs:umss.um_gf1mem.XPTR.PSEG], dx
	or	ax, dx
	cmp	ax,0
	je	not_good
	mov	ax,0
	jmp	check_ok
not_good:
	mov	ax,2
	jmp	NOKS

gf1ail_not_found:
	pop	ds
	mov	ax,1
check_ok:
	cmp	ax,0
	je	OKS
	mov	ax,1
	jmp short NOKS
OKS:	xor	ax,ax
NOKS:
	ret

	endp

	ENDS

	end	START
