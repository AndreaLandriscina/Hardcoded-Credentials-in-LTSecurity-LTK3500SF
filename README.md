# Hardcoded-Credentials-in-LTSecurity-LTK3500SF

- **Device**: LTSecurity LTK3500SF
- **Firmware**: AC3F_V1.1.0_build191121
- **Download link**: https://dl.ltsecurityinc.com/firmware/platinum/latest/AC3F_V1.1.0_191121.zip

## Description
LTSecurity LTK3500SF (firmware AC3F_V1.1.0_build191121) was discovered to contain a hardcoded password for root stored in the file /etc/shadow.

## Proof-Of-Concept
After the download of the firmware via the command *wget https://dl.ltsecurityinc.com/firmware/platinum/latest/AC3F_V1.1.0_191121.zip* and the unpacking with **unzip AC3F_V1.1.0_191121.zip**, it is possible to move inside with **cd DZP20191115128_501__H2_EN_GM_V1.1.0_build191121/** where it is possible to find the firmware's image digicap.dav.

By using **binwalk digicap.dav** we discover that the image contains a CramFS filesystem starting from position 108 with a size of 9928704 bytes.
<img width="793" height="51" alt="image" src="https://github.com/user-attachments/assets/27a65ced-7abb-4c55-8516-ce0728e744b9" />


By using **dd if=digicap.dav of=cramfs.img bs=1 skip=108 count=9928704** we copy the content of the image into cramfs.img. With pycramfs it is possible to extract the filesystem via **pycramfs extract cramfs.img** obtaining the folder cramfs containing all the files and partitions related to the device. Finally, with binwalk we extract the content of the folder ramdisk (**binwalk -eM ramdisk.gz**) that contains the unix-like root of the filesystem (inside _ramdisk.gz.extracted/_40.extracted/ext-root). 

Inside _ramdisk.gz.extracted/_40.extracted/ext-root/etc/shadow file there is the password root:$1$5WxtPNMX$vsdvmM0NegqGN30M4sXa41:15595:0:99999:7::: , stored in a md5crypt hash and reversible with John The Ripper with a dictionary-attack using rockyou wordlist (or just “12345”).

The same password (12345) is also used for guest account.

<img width="499" height="185" alt="image" src="https://github.com/user-attachments/assets/5bdf650e-dd50-4f22-bf4a-1a134de16839" />

An attacker can gain full root access to the device: these credentials can be potentially used to access the device via Telnet/SSH or physical serial console (UART), perform Privilege Escalation if any other low-privilege vulnerability is exploited.
