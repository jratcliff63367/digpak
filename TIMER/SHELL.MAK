
nosound.com:    shell.asm soundrv.inc
		tasm -zi /m5  /x /dBUILD=2 /dNOSOUND=1 shell,nosound
		tlink /v nosound
		tdstrip -s nosound
		exe2bin nosound.exe nosound.com
		erase nosound.exe

