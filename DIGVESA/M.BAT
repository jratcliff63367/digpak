@echo off
tasm -zi /m3 /x digvesa
IF ERRORLEVEL 1 GOTO END
tlink /v -m digvesa
IF ERRORLEVEL 1 GOTO END
tdstrip -s digvesa
exe2bin digvesa.exe digvesa.com
copy	digvesa.com soundrv.com
erase digvesa.exe
:END
