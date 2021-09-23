# Build just the orphan digpak drivers.

ibmbak.com:      shell.asm soundrv.inc
		tasm -zi /m5  /x /dBUILD=13 shell,ibmbak
		tlink /v ibmbak
		tdstrip -s ibmbak
		exe2bin ibmbak.exe ibmbak.com
		erase ibmbak.exe

ibmsnd.com:      shell.asm soundrv.inc
		tasm -zi /m5  /x /dBUILD=5 shell,ibmsnd
		tlink /v ibmsnd
		tdstrip -s ibmsnd
		exe2bin ibmsnd.exe ibmsnd.com
		erase ibmsnd.exe


adlib.com:      shell.asm soundrv.inc
		tasm -zi /m5  /x /dBUILD=1 shell,adlib
		tlink /v adlib
		tdstrip -s adlib
		exe2bin adlib.exe adlib.com
		erase adlib.exe


vmsnd.com:      shell.asm soundrv.inc
		tasm -zi /m5  /x /dBUILD=3 shell,vmsnd
		tlink /v vmsnd
		tdstrip -s vmsnd
		exe2bin vmsnd.exe vmsnd.com
		erase vmsnd.exe

smsnd.com:      shell.asm soundrv.inc
		tasm -zi /m5  /x /dBUILD=4 shell,smsnd
		tlink /v smsnd
		tdstrip -s smsnd
		exe2bin smsnd.exe smsnd.com
		erase smsnd.exe

digisp.com:      shell.asm soundrv.inc
		tasm -zi /m5  /x /dBUILD=6 shell,digisp
		tlink /v digisp
		tdstrip -s digisp
		exe2bin digisp.exe digisp.com
		erase digisp.exe

# Used on Tandy 3 voice systems.  None of these machines are VGA, driver
# only applicable when addressing extremely low end hardware, like the
# PC Jr <g>
tanextx.com:      shell.asm soundrv.inc
		tasm -zi /m5  /x /dBUILD=7 shell,tanextx
		tlink /v tanextx
		tdstrip -s tanextx
		exe2bin tanextx.exe tanextx.com
		erase tanextx.exe

# Street Electronics Echo II.  Used in schools primarily.
echoii.com:      shell.asm soundrv.inc
		tasm -zi /m5  /x /dBUILD=11 shell,echoii
		tlink /v echoii
		tdstrip -s echoii
		exe2bin echoii.exe echoii.com
		erase echoii.exe

# Lantastic Voice Adapter.  Not a wide scale consumer device.
lantsnd.com:      shell.asm soundrv.inc
		tasm -zi /m5  /x /dBUILD=12 shell,lantsnd
		tlink /v lantsnd
		tdstrip -s lantsnd
		exe2bin lantsnd.exe lantsnd.com
		erase lantsnd.exe

# 1 bit digital audio PC Speaker Driver.  Lousy quality, but least
# intrusive on running application.
ibm1bit.com:      shell.asm soundrv.inc
		tasm -zi /m5  /x /dBUILD=14 shell,ibm1bit
		tlink /v ibm1bit
		tdstrip -s ibm1bit
		exe2bin ibm1bit.exe ibm1bit.com
		erase ibm1bit.exe

# Talking Technologies BigMouth.  No one actually owns this device.
# A highly orphan piece of hardware.
bigmouth.com:      shell.asm soundrv.inc
		tasm -zi /m5  /x /dBUILD=16 shell,bigmouth
		tlink /v bigmouth
		tdstrip -s bigmouth
		exe2bin bigmouth.exe bigmouth.com
		erase bigmouth.exe

