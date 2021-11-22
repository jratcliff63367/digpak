        LOCALS                  ;; Enable local labels
        IDEAL                   ;; Use Turbo Assembler's IDEAL mode
	JUMPS
        INCLUDE "PROLOGUE.MAC"          ;; common prologue
	INCLUDE "SOUNDRV.INC"

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

FOREGROUND	equ	0
DIG_CVXSND	equ	1
BACKFLLL	equ	0


KINT	equ	66h

SEGMENT  _TEXT PARA PUBLIC 'CODE'
	 ENDS

	ASSUME	CS: _TEXT, DS: _TEXT, SS: NOTHING, ES: NOTHING


SEGMENT _TEXT
	org	100h
START:
	jmp	LoadSound		; Load the digitized sound driver
	db	"DIGPAK",0,13,10        ; Digitized Sound Package Identity String
IDENTIFIER:
	db	"TIMER BASED DRIVER",0,13,10
	db	"The Audio Solution, Copyright (c) 1993",0,13,10
	db	"Written by John W. Ratcliff",0,13,10
	org	200h		; Beginning address of jumps.
	jmp	InstallInterupt 	; Install the interupt vector.
	jmp	DeInstallInterupt	; De-install the interupt.
DUMMYBASE	dw	-1
DUMMYIRQ	dw	-1
DUMMYEXTRA	dw	-1

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

BACKF	dw	0	; Backfill defaults to off

JumpPtr 	dw	?
PlayingSound	dw	0	; Flag true when sound sample is playing.
CallBacks	dw	0	; Callback to application flag.
LABEL		CALLBACK	DWORD	     ; Callback address label.
CallLow 	dw	0	; Low word of callback address.
CallHigh	dw	0	; High word of callback address.
CallDS		dw	0	; Value of DS register at callback time.

DivisorRate	dw	0	; Default divisor rate.
RecordMode	dw	0	; set audio recording flag.
PlayMode	dw	PCM_8_MONO	; Default play mode is 8 bit PCM.

;; Data used by Kernel interupt
KJUMP	FARPTR	<>		; Address
OLDIN	FARPTR	<>		; Original interupt vector.
ID      db      'KERN'          ; 4B45524Eh Interupt identifier string.
IND     db      'KR'            ; 4B52h indicates a kernel installed interupt.
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

	cmp	ax,0688h
	jb	@@CHAIN
	cmp	ax,069Fh
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
	jne	@@CHAIN2
	cmp	[OLDIN.XPTR.PSEG],0
	je	@@IRET
@@CHAIN2:
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

	HEXPRINT si,0,0
	mov	bx,ds
	HEXPRINT bx,10,0

;;	  call	  CompleteSound
;;	  call	  SetAudio
;;	  mov	  [PlayingSound],1
;;	  call	  Compute256
;;	  call	  PlaySound
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
;;		  BX = Version numer, in decimal, times 100, so that 3.00
;;		       would be 300.  Version number begins with version 3.10
;;		       which includes the DigPak semaphore.
;;**************************************************************************
	mov	bx,330		; Return VERSION NUMBER in BX! 3.30
	cmp	[cs:LOOPING],1	; Looping a sample?
	jne	@@REP
	xor	ax,ax
	mov	dx,1		; Return high word looping flag.
	ClearSemaphoreIRET
@@REP:
	mov	ax,[cs:PlayingSound]
	xor	dx,dx		; Not looping
	ClearSemaphoreIRET
FUNCT3:
;;**************************************************************************
;:Function #3: MassageAudio, Preformat audio data into ouptut hardware format.
;:
;:	  INPUT:  AX = 68Ah
;:		  DS:SI        Point to address of sound structure.
;;**************************************************************************
	PushCREGS

	PopCREGS
	ClearSemaphoreIRET
FUNCT4:
;;**************************************************************************
;:Function #4: DigPlay2, Play preformatted audio data.
;:
;:	  INPUT:  AX = 68Bh
;:		  DS:SI        Point to address of sound structure.
;;**************************************************************************
	PushCREGS
	call	CompleteSound
	call	DoSoundPlay
	mov	[cs:FROMLOOP],0    ; Turn from loop semephore off.
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
	mov	ax,(PLAYBACK OR USESTIMER OR SHARESTIMER)
	mov	bx,cs
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
	xor	ax,ax		; Should compute aproximation!
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
	cmp	[cs:PlayingSound],0	; Currently playing any sound?
	je	@@CNT		; If not playing sound, nothing to stop...
	call	StopSound
@@CNT:	ClearSemaphoreIRET
FUNCT9:
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
	PushAll 	; Save all registers.
	push	cs
	pop	es
	lea	di,[LOOPSND]
	mov	cx,SIZE LOOPSND
	rep	movsb
	mov	ax,068Fh	; Stop any currently playing sound.
	int	66h		; do it.
	mov	[cs:LOOPING],1	   ; We are now looping a sound sample.
	mov	ax,cs
	mov	ds,ax
	mov	dx,ax		;
	mov	ax,068Eh
	lea	bx,[LoopBack]	;
	int	66h		; Set loop callback.
	PopAll
	push	cs
	pop	ds
	lea	si,[LOOPSND]
	mov	[word cs:LOOPSOUND],si
	mov	[word cs:LOOPSOUND+2],ds
	mov	[cs:FROMLOOP],1 ; Set from looping semephore
	mov	ax,068Bh	; Do FUNCT4
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
	cli    ; Turn off interupts while making this determination.
	mov	ax,[cs:PlayingSound]
	or	ax,ax		; Currently playing a sound?
	jnz	@@POST		; yes->try to post pending.
	sti			; We can play it now.
	call	DoSoundPlay	;
	xor	ax,ax		; Return, audio sample is now playing.
	ClearSemaphoreIRET
@@POST: cmp	[cs:PENDING],1	; Already have a pending sound effect?
	jne	@@POST2 	; no, post it for pending play.
	mov	ax,2		; return code of two.
	ClearSemaphoreIRET
@@POST2:mov	[cs:PENDING],1
	push	es
	push	di
	push	cs
	pop	es
	lea	di,[PENDSND]	; Pending sound.
	mov	cx,SIZE PENDSND
	rep	movsb
	mov	[cs:PENDING],1
	mov	[cs:CallBacks],1
	mov	[word cs:CallBack],offset PlayPending
	mov	[word cs:CallBack+2],cs
	mov	[word cs:CallDS],cs
	pop	di
	pop	es
	mov	ax,1		; Posted as pending.
	ClearSemaphoreIRET
FUNCTF:
;;**************************************************************************
;; FUNCTION #15: PendingStatus
;;
;;	   INPUT: AX = 696h
;;	  OUTPUT: AX = 0 No sound is playing.
;;		  AX = 1 Sound playing, sound pending.
;;		  AX = 2 Sound playing, no sound pending.
;;**************************************************************************
	cli		; Clear interrupts while we make this determination.
	mov	ax,[cs:PlayingSound]
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
	mov	ax,1
	cmp	dx,PCM_8_MONO	; ALL drivers support 8 bit PCM mono sound.
	je	@@OK
@@NOT:
	xor	ax,ax
@@OK:
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
;;		  DX = backfill mode 0 means turn it off.
;;		       and a 1 means to turn it on.
;;
;;	   OUTPUT: AX = 1 -> back fill mode set.
;;			0 -> driver doesn't support DMA backfill.
;;
;;**************************************************************************
	xor	ax,ax
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
	push	cx
	push	es
	push	bx
	call	CheckBoundary
	add	sp,6
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
	xor	ax,ax		; Default, volume not set.
	ClearSemaphoreIRET

Macro  GET20BIT
       PUSH   CX
       MOV    CL,4
       ROL    DX,CL
       MOV    CX,DX
       AND    DX,0FH
       AND    CX,0FFF0H
       ADD    AX,CX
       ADC    DX,0
       POP    CX
       endm

Proc    CheckBoundary   near
	ARG	SOURCE:DWORD,SLEN:WORD
	PENTER	0

	mov	ax,[word SOURCE]
	mov	dx,[word SOURCE+2]
	GET20BIT		; Into 20 bit mode.
	mov	bx,dx		; Save DMA page.
	mov	ax,[word SOURCE]
	mov	dx,[word SOURCE+2]
	add	ax,[SLEN]		; Point to end.
	GET20BIT
	mov	ax,1		; Default is OK.
	cmp	bl,dl		; Same DMA page?
	je	@@OK
	xor	ax,ax		; Didn't work.
@@OK:
	PLEAVE
	ret
	endp


Proc	PlayPending	far
	cmp	[PENDING],1  ; Pending?
	jne	@@not
	mov	[PENDING],0
	mov	[cs:CallBacks],0	; No longer have one pending..
	lea	si,[PENDSND]	; Address of pending sound.
	call	DoSoundPlay	; Do a sound play call.
	ret
@@not:
	mov	[cs:CallBacks],0	; Disable callbacks.
	ret
	endp

Proc	DoSoundPlay	near
	PushCREGS		; Save all of the important C registers.
	call	SetAudio
	mov	[PlayingSound],1
	call	Compute256
	call	PlaySound		; Restore important C registers.
	PopCREGS
	ret
	endp


Proc	CheckCallBack	near
	cmp	[cs:CallBacks],0	; Callbacks enabled?
	je	@@GOUT		; no, exit.
	PushAll 		; Save all registers
	mov	ds,[cs:CallDS]	; Get DS register.
	call	[cs:CallBack]	; far call to application.
	PopAll			; Restore all registers.
@@GOUT:
	ret
	endp

INDIGPAK	dw	0	; Inside DigPak semaphore.

FROMLOOP	dw	0
SAVECALLBACK	dd	?	; Saved callback address.
SAVECALLDS	dw	?
LOOPING 	dw	0	; True if we were looping.

LOOPSOUND	dd	?
LOOPSND 	SOUNDSPEC	<>

PENDING 	dw	0	; True, when second sound sample is pending.
PENDSND         SOUNDSPEC <>    ; Sound structure of pending sound.

Proc	LoopBack	far
	mov	ax,068Bh	; Play preformated data.
	mov	[cs:FROMLOOP],1
	lds	si,[LOOPSOUND]	;
	int	66h		; Start playing the sound again.
	ret
	endp

Proc    SetAudio        near
	mov	[ds:(SOUNDSPEC ptr si).ISPLAYING.XPTR.POFF],offset PlayingSound
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
	cmp	[cs:FROMLOOP],1    ; In loop callback?
	jne	@@YES
	call	EndLoop 	; don't wait for loop to complete, end it!
@@YES:
@@WT:	cmp	[cs:PlayingSound],0	; Wait until last sound completed.
	jne	@@WT
	ret
	endp

Proc	Compute256	near
	cmp	dx,256
	jle	@@OK
	push	bx
	push	dx
	mov	ax,cx
	mov	bx,256
	mul	bx
	pop	bx
	div	bx
	mov	cx,ax
	pop	bx
	mov	dx,256		; Playback freq is now 9000!
@@OK:
	ret
	endp

Proc    PlaySound near
;; CX ->number of bytes in sound sample.
;; DS = Code group.
;; ES:BX -> far address of sound sample to be played.
;; DX ->frequency to play data back at.
;; Here we will calculate the interupt rate given the frequency requested.
	mov	si,dx		; Frequency into SI
	mov	dx,0012h	; High word of 1,193,180.
	mov	ax,34DCh	; Low word of 1,193,180.
	div	si		; Divide by frequency passed.
	mov	dx,ax		; Interupt rate result into DX.

	push	dx
	push	bx

	mov	bx,dx		; Count down rate in BX
	xor	dx,dx
	mov	ax,[cs:DivisorRate]
	or	ax,ax
	jnz	@@OK1
	inc	dx
@@OK1:	div	bx
	mov	[RateDown],ax
	mov	[tvalue],ax

	pop	bx
	pop	dx

	mov	[SEGSAMP],es	; segment.
	mov	[ADDRESS+1],bx	  ; offset
	mov	[STARTADDRESS],bx
	mov	[TOTALLENGTH],cx	;
	add	cx,bx		; Compute ending address.
	mov	[COMPARE+5],cx	  ; set for comparison to ending address.
	push	dx		; Save rate.
	call	tinstall	; Install hardware interupt
	pop	dx		; Get back rate.
	call	trate		; Set the timer rate.
	ret
	endp

Proc	StopSound	near
	PushCREGS
	push	cs
	pop	ds
	cmp	[PlayingSound],0
	je	@@GOUT
	call	rtimer		; Restore original timer interupt vector.
	mov	[cs:PlayingSound],0	; Finished playing sound.
	cmp	[cs:CallBacks],0	; Callbacks enabled?
	je	@@GOUT		; no, exit.
	PushAll 		; Save all registers
	mov	ds,[cs:CallDS]	; Get DS register.
	call	[cs:CallBack]	; far call to application.
	PopAll			; Restore all registers.
@@GOUT:
	PopCREGS
	ret
	endp

command_reg     equ 43h
channel_0       equ 40h
channel_2       equ 42h         ; speaker's frequency oscillator.

Proc	trate  near
; This routine sets the rate at which the timer routine is
; interupted and the cutoff value for one bit sound
; called as:
;
; DX ->rate to play sound at.
        mov     al,00110110b
        out     command_reg,al
        jmp     $+2
	mov	ax,dx		; Get rate into AX
        out     channel_0,al
        jmp     $+2
        mov     al,ah
        out     channel_0,al
        ret
	endp


OldTimer FARPTR <>	; Original timer interupt vector.

Proc	tinstall near
; Install timer interupt routine
        push    es              ; save extra segment
	xor	ax,ax
	mov	es,ax
	mov	ax,[es:INT8OFF]     ; Get offset portion.
	mov	[OldTimer.XPTR.POFF],ax
	mov	ax,[es:INT8SEG]
	mov	[OldTimer.XPTR.PSEG],ax
	mov	[word es:INT8OFF],offset timer2
	mov	[es:INT8SEG],cs
	mov	[flag],0	; Re-entrency flag, starts at 0.
        pop     es
        RET
	ENDP

INT8OFF         equ     8*4
INT8SEG         equ     8*4+2

Proc	rtimer near
; This routine restores the timer interupt to what it was originally.
	push	ds
	push	dx
	push	ax

	mov	dx,[cs:DivisorRate]  ; Set timer rate to zero.
	call	trate		; Set timr rate to zero.
	xor	ax,ax
	mov	ds,ax		; Segment zero
	mov	ax,[cs:OldTimer.XPTR.POFF] ; get offset.
	mov	[ds:INT8OFF],ax      ; Set offset.
	mov	ax,[cs:OldTimer.XPTR.PSEG] ; get segment.
	mov	[ds:INT8SEG],ax

	pop	ax
	pop	dx
	pop	ds
        RET
	ENDP

flag	dw	0
tvalue	dw	?
RateDown	dw	?	; Reload decrement count for servicing 18.2
SEGSAMP dw	?		; Segment of sound sample.


TOTALLENGTH	dw	?	;
STARTADDRESS	dw	?	; Starting address of sample
	ALIGN  16
Proc    timer2  FAR
	SetSemaphore
	push	ax		; Save ax
	push	ds		; Save data segment
@@T3:	mov	ds,[cs:SEGSAMP] ; Place into data segment.
LABEL	ADDRESS WORD
	mov	al,[1234h]	; Get offset of data sampel.
@@NEXT:
        inc     [cs:ADDRESS+1]
LABEL   COMPARE WORD
        cmp     [cs:ADDRESS+1],1234h      ; Hit end?
        je      @@OUT
@@GOUT:
        dec     [cs:tvalue]     ; add
        jz      @@T2            ; If not a carry then we didn't over flow.
@@GOUT2:
        pop     ds
	ClearSemaphore
	mov	al,20h
	out	20h,al
	pop	ax
	iret
@@T2:
	ClearSemaphore
	pushf			; Push flags to fake an Interupt.
	call	[cs:OldTimer.DPTR]     ; Call the original interupt vector
	mov	ax,[cs:RateDown]
	mov	[cs:tvalue],ax
	SetSemaphore
	jmp short @@GOUT2
@@OUT:
@@NOTBACK:
	call	StopSound
	jmp short @@GOUT2
	endp



LABEL	SUICIDE byte		;; Where to delete ourselves from memory
hard	db	'$'
msg0    db      "No digital sound card"
	db	" - Copyright (c) 1993, THE Audio Solution:v3.30",13,10,'$'
msg1	db	"DIGPAK Sound Driver is already resident.",13,10,'$'
msg1a	db	"DIGPAK Sound Driver is resident, through MIDPAK.",13,10,'$'
msg1b	db	"A Sound Driver cannot be loaded on top of MIDPAK.  Unload MIDPAK first.",13,10,'$'
msg2	db	"Unable to install Sound Driver interupt vector",13,10,'$'
msg3    db      "Invalid command line",13,10,'$'
msg4	db	"Sound Driver isn't in memory",13,10,'$'
msg5	db	"DIGPAK Sound Driver unloaded",13,10,'$'
msg5a	db	"Sound Driver can't be unloaded, unload MIDPAK first.",13,10,'$'
param   dw      4 dup(?)        ;; Used for parameter passing.
Installed	dw	0
Proc	LoadSound near
	mov	ax,cs			;;
	mov	ds,ax			;; establish data segment
	mov	es,ax			;; point ES to PSP
	call	CheckIn
	mov	[Installed],ax		;; Save in installed flag.
	call	ParseCommandLine	;; Build a command line.
	cmp	[_argc],0
	je	NoArg
	cmp	[_argc],1
	jne	@@BC
	mov	bx,[_argv]
	mov	al,[bx]
	cmp	al,'u'
	je	ULOAD
	cmp	al,'U'
	je	ULOAD
@@BC:
	Message msg3			;; Invalid command line
				DOSTerminate

ULOAD:	mov	ax,[Installed]
	or	ax,ax
	jnz	DOU
	Message msg4			;; wasn't loaded.
	DOSTerminate			;; Terminate with message.
DOU:	cmp	ax,2
	jne	@@OKU
	Message msg5a
	DOSTerminate
@@OKU:
	CALLF	DeInstallInterupt
	Message msg5			;; Display message
	DOSTerminate			;; terminate

NoArg:	or	ax,ax			;; Already loaded?
	jz	@@DOLO			;; no->load it.
	cmp	ax,2
	jne	@@TEMP
	Message msg1a
	DOSTerminate
@@TEMP: cmp	ax,3
	jne	@@TEMPA
	jmp short @@DOLO
	Message msg1b
	DOSTerminate
@@TEMPA:
	Message msg1			;; message
	DOSTerminate			;;
@@DOLO: CALLF	InstallInterupt
	or	ax,ax			;; Was there an error?
	jz	@@HOP1			;; no->continue
	Message msg2			;; display the error message
	Message hard	; Hardware error message if there is one.
	DOSTerminate			;; exit to dos
@@HOP1:
;;; The Kernel is now installed.
;;; Announce the Kernel's presence.
	Message msg0
				DosTSR  SUICIDE         ;; Terminate ourselves bud.
	endp

Proc	InstallInterupt 	far
	int	3
	mov	ax,0B800h
	mov	es,ax
	mov	[byte es:0],'A'
	mov	bx,1234h
	mov	ax,1
	ret


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
				jz      @@UOUT          ; exit if zero
	cmp	[WORD ds:si-2],524Bh ;'KR' Is this a kernel installed interupt?
        push    ds              ; save DS
        mov     ax,dx           ; Get interupt vector.
				mov     ah,25h          ; Do DOS 25h set interupt vector.
	mov	dx,[ds:si-10]	 ; get old offset
	mov	ds,[ds:si-8]	; get old segment
				int     21h             ; set interupt vector.
        pop     ax              ; get back segment of program.
        mov     es,ax
	push	es
	mov	es,[es:2Ch]	; Environment space.
	mov	ah,49h
	int	21h		; Free it up.
	pop	es
        mov     ah,49h          ; free memory.
        int     21h             ; free up the memory used by us.

@@EXIT: PopCREGS
	PLEAVE
        ret
@@UOUT: mov     ax,1
        jmp short @@EXIT
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
	ret
	endp

	ENDS
	end	START

