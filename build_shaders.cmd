@echo off
setlocal enabledelayedexpansion

:: Query the registry for the InstallLocation key for sbox and if its found set the contents of the InstallLocation key to a variable
FOR /F "skip=2 tokens=2,*" %%A IN ('reg.exe query "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Steam App 590830" /v "InstallLocation"') DO set "sboxinstalldir=%%B"

set vfxcompile=%sboxinstalldir%\bin\win64\vfxcompile.exe

pushd shaders

::for /r %%i in (*.shader) do CALL echo "%%i"
for /r %%i in (*.shader) do "%vfxcompile%" "%%i"

popd

echo.
echo [92m========== Finished Compiling Shaders! ==========[37m
echo.

pause 
endlocal

:echo_shaders
@echo %1
exit /b