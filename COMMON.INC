
;   /*\
;---|*|----====< COMMON.INC >====----
;---|*|
;---|*| This file contains the Media Vision hardware definition equates, and.
;---|*| the PC hardware environment.
;---|*|
;---|*| Copyright (c) 1991, Media Vision, Inc.	All Rights Reserved.
;---|*|
;   \*/
;
;	   Product Definition
;
PROAS100	equ	1		;; 1st board - Pro Audio Spectrum

;	   Hardware associated with the product

if PROAS100				;; Media Vision Pro Audio Spectrum

DUALFM		EQU	1		;; Dual FM chips
DUALMIXER	EQU	1		;; Dual mixers
FILTER		EQU	1		;; Has filter after input mixer
VOLUME		EQU	1		;; Has total volume control

TEXTVERSIONHI	EQU	'01'            ;; VERSION 01.00
TEXTVERSIONLO	EQU	'00'

HWREVISION      equ     00000000B       ; the H/W revision #

SYSSPKRTMR	EQU	00042h		;; System Speaker Timer Address
SYSTMRCTLR	EQU	00043h		;; System Timer Control Register
SYSSPKRREG	EQU	00061h		;; System Speaker Register
JOYSTICK	EQU	00201h		;; Joystick Register
LFMADDR 	EQU	00388h		;; Left  FM Synthesizer Address Register
LFMDATA 	EQU	00389h		;; Left  FM Synthesizer Data Register
RFMADDR 	EQU	0038Ah		;; Right FM Synthesizer Address Register
RFMDATA 	EQU	0038Bh		;; Right FM Synthesizer Data Register
DFMADDR 	EQU	00788h		;; Dual  FM Synthesizer Address Register
DFMDATA 	EQU	00789h		;; Dual  FM Synthesizer Data Register
AUDIOMIXR	EQU	00B88h		;; Audio Mixer Control Register
AUDIOFILT	EQU	00B8Ah		;; Audio Filter Control Register
INTRCTLRST	EQU	00B89h		;; Interrupt Control Status Register
INTRCTLR	EQU	00B8Bh		;; Interrupt Control Register write
INTRCTLRRB	EQU	00B8Bh		;; Interrupt Control Register read back
PCMDATA 	EQU	00F88h		;; PCM data I/O register
CROSSCHANNEL	EQU	00F8Ah		;; Cross Channel Register
SAMPLERATE	EQU	01388h		;; (t0) Sample Rate Timer Register
SAMPLECNT	EQU	01389h		;; (t1) Sample Count Register
SPKRTMR 	EQU	0138Ah		;; (t2) Local Speaker Timer Address
TMRCTLR 	EQU	0138Bh		;; Local Timer Control Register
MDIRQVECT	EQU	01788H		;; MIDI-1 IRQ Vector Register
MDSYSCTLR	EQU	01789H		;; MIDI-2 System Control Register
MDSYSSTAT	EQU	0178AH		;; MIDI-3 IRQ Status Register
MDIRQCLR	EQU	0178BH		;; MIDI-4 IRQ Clear Register
MDGROUP1	EQU	01B88H		;; MIDI-5 Group #1 Register
MDGROUP2	EQU	01B89H		;; MIDI-6 Group #2 Register
MDGROUP3	EQU	01B8AH		;; MIDI-7 Group #3 Register
MDGROUP4	EQU	01B8BH		;; MIDI-8 Group #4 Register

;; Special PAS16 stuff!
SAMPLESIZE	equ	08389h	; Sample size register.
;;

;
; Factory Default Settings
;
DEFAULTDMA	equ	1		;; DMA channel 1
DEFAULTIRQ	equ	7		;; IRQ channel 7
DEFAULTINT	equ	65h		;; Interrupt # for software interface

;
; mixer select
;
OUTPUTMIXER	equ	00h		;; output mixer H/W select
INPUTMIXER	equ	40h		;; input mixer select
DEFMIXER	equ	-1		;; use last mixer selected

;
; Filter register bits
;
fFIdatabits	equ	00011111B	;; filter select and decode field bits
fFImutebits	equ	00100000B	;; filter mute field bits
fFIpcmbits	equ	11000000B	;; filter sample rate field bits
bFImute 	equ	00100000B	;; filter mute bit
bFIsrate	equ	01000000B	;; filter sample rate timer mask
bFIsbuff	equ	10000000B	;; filter sample buffer counter mask
FILTERMAX	equ	6		;; six possible settings

;
; Cross Channel Bit definitions
;
fCCcrossbits	EQU	00001111B	;; cross channel bit field
fCCpcmbits	EQU	11110000B	;; pcm/dma control bit field
bCCr2r		EQU	00000001B	;; CROSSCHANNEL Right to Right
bCCl2r		EQU	00000010B	;; CROSSCHANNEL Left  to Right
bCCr2l		EQU	00000100B	;; CROSSCHANNEL Right to Right
bCCl2l		EQU	00001000B	;; CROSSCHANNEL Left  to Left
bCCdac		EQU	00010000B	;; DAC/ADC Control
bCCmono 	EQU	00100000B	;; PCM Monaural Enable
bCCenapcm	EQU	01000000B	;; Enable PCM state machine
bCCdrq		EQU	10000000B	;; Enable DRQ bit

;
; Interrupt Control Register Bits
;
fICintmaskbits	EQU	00011111B	;; interrupt mask field bits
fICrevbits	EQU	11100000B	;; revision mask field bits
fICidbits	EQU	11100000B	;; Board revision ID field bits
bICleftfm	EQU	00000001B	;; Left FM interrupt enable
bICritfm	EQU	00000010B	;; Right FM interrupt enable
bICsamprate	EQU	00000100B	;; Sample Rate timer interrupt enable
bICsampbuff	EQU	00001000B	;; Sample buffer timer interrupt enable
bICmidi 	EQU	00010000B	;; MIDI interrupt enable
   fICrevshr	EQU	5		;; rotate rev bits to lsb

;
; Interrupt Status Register Bits
;
fISints 	EQU	00011111B	;; Interrupt bit field
bISleftfm       EQU     00000001B       ;; Left FM interrupt active
bISritfm	EQU	00000010B	;; Right FM interrupt active
bISsamprate	EQU	00000100B	;; Sample Rate timer interrupt active
bISsampbuff	EQU	00001000B	;; Sample buffer timer interrupt active
bISmidi 	EQU	00010000B	;; MIDI interrupt active
bISPCMlr        EQU     00100000B       ;; PCM left/right active
bISActive	EQU	01000000B	;; Hardware is active (not in reset)
bISClip 	EQU	10000000B	;; Sample Clipping has occured

;
;       cross channel channel #s
;
RIGHT2RIGHT	equ	00h		;; right to right
LEFT2RIGHT	equ	01h		;; left  to right
RIGHT2LEFT	equ	02h		;; right to left
LEFT2LEFT	equ	03h		;; left  to left

;
; left/right mixer channel selection
;

;	left channel values

L_FM		equ	01h
L_IMIXER	equ	02h
L_EXT		equ	03h
L_INT		equ	04h
L_MIC		equ	05h
L_PCM		equ	06h
L_SPEAKER	equ	07h

;	right channel values

R_FM		equ	08h
R_IMIXER	equ	09h
R_EXT		equ	0Ah
R_INT		equ	0Bh
R_MIC		equ	0Ch
R_PCM		equ	0Dh
R_SPEAKER	equ	0Eh

; int 2F application ID codes

INT2FCODE1	equ	0BCH		; Bryan's initials

; int 2F ID (func 0) return register values

INT2FREGBX      equ     6D00h           ; 'm '
INT2FREGCX	equ	0076h		; ' v'
INT2FREGDX	equ	2020h		; UPPERCASE XOR MASK

endif ; PROAS100

;---------------------------====< PC HARDWARE >====---------------------------

; Interrupt Controller #1 Port Addresses and Interrupt Masks

IRQ1MASKREG	EQU	021h		;; 8259 mask register
IRQ1ACKREG	EQU	020h		;; 8259 INT acknowledge register

IRQ2MASKREG	equ	0A1h	; second pic mask
IRQ2ACKREG	equ	0A0h	; second pic aknowledge.

INT0MSK 	EQU	00000001B	;; interrupt 0 mask
INT1MSK 	EQU	00000010B	;; interrupt 1 mask
INT2MSK 	EQU	00000100B	;; interrupt 2 mask
INT3MSK 	EQU	00001000B	;; interrupt 3 mask
INT4MSK 	EQU	00010000B	;; interrupt 4 mask
INT5MSK 	EQU	00100000B	;; interrupt 5 mask
INT6MSK 	EQU	01000000B	;; interrupt 6 mask
INT7MSK 	EQU	10000000B	;; interrupt 7 mask

; Interrupt Controller #2 Port Addresses and Interrupt Masks

IRQ2MASKREG	EQU	0A1h		;; 8259 mask register
IRQ2ACKREG	EQU	0A0h		;; 8259 INT acknowledge register

INT8MSK 	EQU	00000001B	;; interrupt 8 mask
INT9MSK 	EQU	00000010B	;; interrupt 9 mask
INTAMSK 	EQU	00000100B	;; interrupt A mask
INTBMSK 	EQU	00001000B	;; interrupt B mask
INTCMSK 	EQU	00010000B	;; interrupt C mask
INTDMSK 	EQU	00100000B	;; interrupt D mask
INTEMSK 	EQU	01000000B	;; interrupt E mask
INTFMSK 	EQU	10000000B	;; interrupt F mask

EOI		EQU	020h		;; non specific end of interrupt

; dma controller #1 port addresses

DMAC0ADDR	EQU	000h		;; DMA channel 0 Base & Current Address
DMAC0COUNT	EQU	001h		;; DMA channel 0 Base & Current Count
DMAC1ADDR	EQU	002h		;; DMA channel 1 Base & Current Address
DMAC1COUNT	EQU	003h		;; DMA channel 1 Base & Current Count
DMAC2ADDR	EQU	004h		;; DMA channel 2 Base & Current Address
DMAC2COUNT	EQU	005h		;; DMA channel 2 Base & Current Count
DMAC3ADDR	EQU	006h		;; DMA channel 3 Base & Current Address
DMAC3COUNT	EQU	007h		;; DMA channel 3 Base & Current Count

DMA2C4ADDR	EQU	0C0h		;; DMA channel 4 Base & Current Address
DMA2C4COUNT	EQU	0C2h		;; DMA channel 4 Base & Current Count
DMA2C5ADDR	EQU	0C4h		;; DMA channel 5 Base & Current Address
DMA2C5COUNT	EQU	0C6h		;; DMA channel 5 Base & Current Count
DMA2C6ADDR	EQU	0C8h		;; DMA channel 6 Base & Current Address
DMA2C6COUNT	EQU	0CAh		;; DMA channel 6 Base & Current Count
DMA2C7ADDR	EQU	0CCh		;; DMA channel 7 Base & Current Address
DMA2C7COUNT	EQU	0CEh		;; DMA channel 7 Base & Current Count

DMARDSTAT       EQU     008h            ;; DMA read status
DMAWRCNTRL	EQU	008h		;; DMA write command register
DMAWREQ 	EQU	009h		;; DMA write request register
DMAWRSMR	EQU	00Ah		;; DMA write single mask register
DMAWRMODE	EQU	00Bh		;; DMA write mode register
DMACLEAR	EQU	00Ch		;; DMA clear low/high flip-flop
DMARDTEMP	EQU	00Dh		;; DMA read temp register
DMAWRCLR	EQU	00Dh		;; DMA write master clear
DMACLRMSK	EQU	00Eh		;; DMA clear mask register
DMAWRALL	EQU	00Fh		;; DMA write all mask register bits

DMA2RDSTAT      EQU     0D0h            ;; DMA read status
DMA2WRCNTRL	EQU	0D0h		;; DMA write command register
DMA2WREQ	EQU	0D2h		;; DMA write request register
DMA2WRSMR	EQU	0D4h		;; DMA write single mask register
DMA2WRMODE	EQU	0D6h		;; DMA write mode register
DMA2CLEAR	EQU	0D8h		;; DMA clear low/high flip-flop
DMA2RDTEMP	EQU	0DAh		;; DMA read temp register
DMA2WRCLR	EQU	0DAh		;; DMA write master clear
DMA2CLRMSK	EQU	0DCh		;; DMA clear mask register
DMA2WRALL	EQU	0DEh		;; DMA write all mask register bits

CH0PAGEREG	EQU	087h		;; Channel 0 Page Register
CH1PAGEREG	EQU	083h		;; Channel 1 Page Register
CH2PAGEREG	EQU	081h		;; Channel 2 Page Register
CH3PAGEREG	EQU	082h		;; Channel 3 Page Register

CH5PAGEREG      EQU     08Bh            ;; Channel 5 Page Register
CH6PAGEREG	EQU	089h		;; Channel 6 Page Register
CH7PAGEREG	EQU	08Ah		;; Channel 7 Page Register

;
;   /*\
;---|*| end of COMMON.INC
;   \*/
;
