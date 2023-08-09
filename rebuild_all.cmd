@echo off
setlocal enabledelayedexpansion

:: Query the registry for the InstallLocation key for sbox and if its found set the contents of the InstallLocation key to a variable
FOR /F "skip=2 tokens=2,*" %%A IN ('reg.exe query "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Steam App 590830" /v "InstallLocation"') DO set "sboxinstalldir=%%B"

set contentbuilder=%sboxinstalldir%\bin\win64\contentbuilder.exe

:: Build all assets ( Excluding maps & shaders )
"%contentbuilder%" -b -o -nop4 -v -f

:: Delete contentbuild folders in .source2 
pushd "%sboxinstalldir%\.source2"

for /f "tokens=* delims=" %%# in ('dir /b /a:d^| findstr /i "contentbuild"') do (
  rd /s /q "%%~f#"
)

popd

rem ..\..\bin\win64\contentbuilder.exe -b -o -nop4 -v -f -spewallcompiles -compileverbose -mergeverbose -spewallcommands

pause
endlocal