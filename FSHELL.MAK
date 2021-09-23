

ft2500.com:	 shell.asm soundrv.inc
		tasm -zi /m3 /dBUILD=19 shell,ft2500
		tlink /v ft2500
		tdstrip -s ft2500
		exe2bin ft2500.exe ft2500.com
		erase ft2500.exe

fibmbak.com:	  shell.asm soundrv.inc
		tasm -zi /m3 /dBUILD=13 /dFOREGROUND=1 shell,ibmbak
		tlink /v ibmbak
		tdstrip -s ibmbak
		exe2bin ibmbak.exe fibmbak.com
		erase ibmbak.exe

fadlib.com:	 shell.asm soundrv.inc
		tasm -zi /m3 /dBUILD=1 /dFOREGROUND=1 shell,adlib
		tlink /v adlib
		tdstrip -s adlib
		exe2bin adlib.exe fadlib.com
		erase adlib.exe

fcvxsnd.com:	  shell.asm soundrv.inc
		tasm -zi /m3 /dBUILD=2 /dFOREGROUND=1 shell,cvxsnd
		tlink /v cvxsnd
		tdstrip -s cvxsnd
		exe2bin cvxsnd.exe fcvxsnd.com
		erase cvxsnd.exe

fvmsnd.com:	 shell.asm soundrv.inc
		tasm -zi /m3 /dBUILD=3 /dFOREGROUND=1 shell,vmsnd
		tlink /v vmsnd
		tdstrip -s vmsnd
		exe2bin vmsnd.exe fvmsnd.com
		erase vmsnd.exe

fsmsnd.com:	 shell.asm soundrv.inc
		tasm -zi /m3 /dBUILD=4 /dFOREGROUND=1 shell,smsnd
		tlink /v smsnd
		tdstrip -s smsnd
		exe2bin smsnd.exe fsmsnd.com
		erase smsnd.exe


ftanextx.com:	   shell.asm soundrv.inc
		tasm -zi /m3 /dBUILD=7 /dFOREGROUND=1 shell,tanextx
		tlink /v tanextx
		tdstrip -s tanextx
		exe2bin tanextx.exe ftanextx.com
		erase tanextx.exe

fsource.com:	  shell.asm soundrv.inc
		tasm -zi /m3 /dBUILD=10 /dFOREGROUND=1 shell,source
		tlink /v source
		tdstrip -s source
		exe2bin source.exe fsource.com
		erase source.exe

fechoii.com:	  shell.asm soundrv.inc
		tasm -zi /m3 /dBUILD=11 /dFOREGROUND=1 shell,echoii
		tlink /v echoii
		tdstrip -s echoii
		exe2bin echoii.exe fechoii.com
		erase echoii.exe

fibm1bit.com:	   shell.asm soundrv.inc
		tasm -zi /m3 /dBUILD=14 /dFOREGROUND=1 shell,ibm1bit
		tlink /v ibm1bit
		tdstrip -s ibm1bit
		exe2bin ibm1bit.exe fibm1bit.com
		erase ibm1bit.exe

fbigmouth.com:	    shell.asm soundrv.inc
		tasm -zi /m3 /dBUILD=16 /dFOREGROUND=1 shell,bigmouth
		tlink /v bigmouth
		tdstrip -s bigmouth
		exe2bin bigmouth.exe fbigmouth.com
		erase bigmouth.exe

