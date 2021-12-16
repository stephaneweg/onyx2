set mypath=%cd%
cd qemu
qemu-system-i386.exe -m 1G -hda ..\hd.img -device sb16 -net nic,macaddr=02:ca:fe:f0:0d:01,model=ne2k_isa -net user,hostfwd=tcp::5022-:22 -D con
pause