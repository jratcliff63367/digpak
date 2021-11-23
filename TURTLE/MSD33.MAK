
multisnd.com:	msnd33.asm msnd_dsp.equ msnd.inc
		tasm -zi /m3 /dMSND=1 msnd33
		tlink /v msnd33
		tdstrip -s msnd33
		exe2bin msnd33.exe multisnd.com
		erase msnd33.exe

