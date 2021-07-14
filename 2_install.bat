@echo off
set drive=i:
if NOT EXIST %Drive%\ (
	echo Please mount the disk image at %Drive%
	pause
	EXIT
)
IF NOT EXIST %Drive%\boot mkdir %Drive%\boot
IF NOT EXIST %Drive%\etc mkdir %Drive%\etc
IF NOT EXIST %Drive%\sys mkdir %Drive%\sys
IF NOT EXIST %Drive%\res mkdir %Drive%\res
IF NOT EXIST %Drive%\fonts mkdir %Drive%\fonts
IF NOT EXIST %Drive%\keys mkdir %Drive%\keys
IF NOT EXIST %Drive%\icons mkdir %Drive%\icons
IF NOT EXIST %Drive%\apps mkdir %Drive%\apps



for /d %%i in (userland\apps\*.*) do (
	echo    %%~ni
	IF NOT EXIST %Drive%\apps\%%~ni.APP mkdir %Drive%\apps\%%~ni.APP
	copy bin\userland\%%~ni.bin %Drive%\apps\%%~ni.APP\main.bin
	if exist userland\apps\%%~ni\app.bmp copy userland\apps\%%~ni\app.bmp %Drive%\apps\%%~ni.APP\app.bmp
)


echo Install kernel ...
if exist %Drive%\boot\kernel.elf del %Drive%\boot\kernel.elf /F /Q

copy bin\kernel.elf %Drive%\boot\kernel.elf
copy menu.lst %Drive%\boot\grub\menu.lst


echo Instal System bin
copy bin\sys\*.* %Drive%\sys

echo install keymaps
copy bin\keymaps\*.* %Drive%\keys

echo Install fonts
copy fonts\*.* %Drive%\fonts

echo install skins
copy skins\*.bmp %Drive%\res\*.bmp

echo install icons
copy icons\*.bmp %Drive%\icons\*.bmp

echo Install config
copy etc\*.* %Drive%\etc

copy bin\res\mousecur.bin %Drive%\res
pause