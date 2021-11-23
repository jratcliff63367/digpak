;***************************************************************************
;	NAME:  ultramid.inc
; 	COPYRIGHT:
; 	"Copyright (c) 1991,1992,1993 by Forte Technologies
; 
;        "This software is furnished under a license and may be used,
;        copied, or disclosed only in accordance with the terms of such
;        license and with the inclusion of the above copyright notice.
;        This software or any other copies thereof may not be provided or
;        otherwise made available to any other person. No title to and
;        ownership of the software is hereby transfered."
;***************************************************************************
;  CREATION DATE: 04/01/93
;--------------------------------------------------------------------------*
;     VERSION	DATE	   NAME		DESCRIPTION
;>	1.0	04/01/93   ultramid.inc main interface to UltraMID
;**************************************************************************/
; calling parameters to ULTRAMID TSR
; AX should have a function request
; digital functions

TSR_START_DIGITAL	    equ 0
TSR_PLAY_NEXT_BUFFER	    equ 1
TSR_SET_PAN    	            equ 2
TSR_SET_VOLUME		    equ 3
TSR_SET_RATE	    	    equ 4
TSR_PAUSE_DIGITAL	    equ 5
TSR_RESTART_DIGITAL	    equ 6
TSR_STOP_DIGITAL	    equ 7
TSR_GET_DIGITAL_POSITION    equ 8
TSR_VOICE_STATUS	    equ 9
; MIDI functions
TSR_LOAD_MIDI_PATCHES	    equ 10
TSR_LOAD_XMIDI_PATCHES	    equ 11
TSR_LOAD_PATCH	    	    equ 12
TSR_UNLOAD_PATCH	    equ 13
TSR_START_SEQUENCE	    equ 14
TSR_UNLOAD_ALL_PATCHES	    equ 15
TSR_MIDI_OUT	    	    equ 16
TSR_MIDI_OUT_STR	    equ 17
TSR_ALL_NOTES_OFF	    equ 18
; resource functions
TSR_ALLOCATE_MEMORY	    equ 19
TSR_FREE_MEMORY		    equ 20
TSR_FREE_TSR		    equ 21
; semaphore
TSR_SEM_ENTER		    equ 22
TSR_SEM_LEAVE		    equ 23
TSR_ADD_EXTERNAL_SEMAPHORE  equ 24
TSR_CLEAR_EXTERNAL_SEMAPHORE equ 25
TSR_APP_START		    equ 26
TSR_APP_END		    equ 27
TSR_SET_MIDI_CALLBACK	    equ 28
TSR_CLEAR_MIDI_CALLBACK	    equ 29
TSR_SHUTDOWN_TSR	    equ 30
TSR_RELOAD_TSR		    equ 31

; data type
UM_8BIT		EQU	1	; 1 use 8 bit data 
				; 0 use 16 bit data 
UM_PRELOAD	EQU	2	; preload data 
UM_INVERT_MSB	EQU	4	; invert most significant bit during dma 
UM_STEREO	EQU	8	; 1 for stereo data 

UM_STOP_SOUND	EQU	0
UM_MORE_DATA	EQU	1
UM_BUFFER_DONE	EQU	2
UM_PAUSE	EQU	3

UM_ERR_FRAMING	EQU	16
UM_ERR_OVERRUN	EQU	32

um_sound_struct struc
	um_sound_data label dword
	um_sound_data_off dw ?
	um_sound_data_seg dw ?
	um_stereo_mem label dword
	um_stereo_mem_off dw ?
	um_stereo_mem_seg dw ?
	um_sound_len    dd ?
	um_gf1mem	dd ?
	um_pan	     db ?
	um_volume    dw ?
	um_sample_rate  dw ?
	label um_voice     word
	um_priority     dw ?
	um_data_type    db ?
	um_callback_addr label dword
	um_callback_addr_off dw ?
	um_callback_addr_seg dw ?
um_sound_struct ENDS
