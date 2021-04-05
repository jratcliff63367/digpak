
;   /*\
;---|*|----====< Pro Audio Spectrum Hardware State Table >====----
;---|*|
;---|*| Media Vision, Inc. (c) Copyright 1991. All Rights Reserved
;---|*|
;   \*/

MVState struc
  _sysspkrtmr	 db	0	;    42 System Speaker Timer Address
  _systmrctlr	 db	0	;    43 System Timer Control
  _sysspkrreg	 db	0	;    61 System Speaker Register
  _joystick	 db	0	;   201 Joystick Register
  _lfmaddr	 db	0	;   388 Left  FM Synth Address
  _lfmdata	 db	0	;   389 Left  FM Synth Data
  _rfmaddr	 db	0	;   38A Right FM Synth Address
  _rfmdata	 db	0	;   38B Right FM Synth Data
  _RESRVD1	 db	4 dup(0);	reserved
  _audiomixr	 db	0	;   B88 Audio Mixer Control
  _intrctlrst	 db	0	;   B89 Interrupt Status
  _audiofilt	 db	0	;   B8A Audio Filter Control
  _intrctlr	 db	0	;   B8B Interrupt Control
  _pcmdata	 db	0	;   F88 PCM Data I/O Register
  _RESRVD2	 db	0	;	reserved
  _crosschannel  db	0	;   F8A Cross Channel
  _RESRVD3	 db	0	;	reserved
  _samplerate	 dw	0	;  1388 Sample Rate Timer
  _samplecnt	 dw	0	;  1389 Sample Count Register
  _spkrtmr	 dw	0	;  138A Shadow Speaker Timer Count
  _tmrctlr	 db	0	;  138B Shadow Speaker Timer Control
  _RESRVD4	 db	8 dup(0);	reserved
MVState ends


;   /*\
;---|*| end of STATE.H
;   \*/

