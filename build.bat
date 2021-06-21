@ECHO OFF

cd src\perl

start "Build Perl" cmd /c pp @libs.txt tp_ohm.pl -o tp_ohm.exe

:loop
ping -n 2 localhost >nul 2>nul
tasklist /fi "WINDOWTITLE eq Build Perl" | findstr "cmd" >nul 2>nul && set Child1=1 || set Child1=
if not defined Child1 goto endloop
goto loop
:endloop

move tp_ohm.exe ..\OpenHardwareMonitor\tp_ohm.exe
cd ..
del ..\installer\OpenHardwareMonitor.tpp
7z a -tzip ..\installer\OpenHardwareMonitor.tpp OpenHardwareMonitor
del OpenHardwareMonitor\tp_ohm.exe
