#!/bin/sh
set -e

# 1) install dependencies
sudo apt update
sudo apt install -y binwalk unzip python3-pip john

# 2) python package
pip3 install --user --break-system-packages pycramfs

# 3) download and unzip firmware
FW_URL="https://dl.ltsecurityinc.com/firmware/platinum/latest/AC3F_V1.1.0_191121.zip"
FW_ZIP="$(basename "$FW_URL")"
wget -c "$FW_URL"
unzip -o "$FW_ZIP"

# 4) move into firmware folder
FW_DIR="DZP20191115128_501__H2_EN_GM_V1.1.0_build191121"
if [ ! -d "$FW_DIR" ]; then
  echo "Directory $FW_DIR not found; listing extracted items:"
  ls -1
  exit 1
fi
cd "$FW_DIR"

# 5) run binwalk to locate cramfs
binwalk digicap.dav

# 6) extract cramfs region with dd
OFFSET=108
LENGTH=9928704
# use byte-accurate skip/count while using large block IO
dd if=digicap.dav of=cramfs.img iflag=skip_bytes,count_bytes skip=$OFFSET count=$LENGTH bs=1M

# 7) extract cramfs filesystem
# Ensure pycramfs in PATH (user install)
PYCRAMFS="$(command -v pycramfs || echo "$HOME/.local/bin/pycramfs")"
if [ ! -x "$PYCRAMFS" ]; then
  echo "pycramfs not found at $PYCRAMFS"
  exit 1
fi
"$PYCRAMFS" extract -f cramfs.img

# 8) find ramdisk.gz inside extracted tree and run binwalk -eM on it
RAM=`find . -type f -iname "ramdisk*.gz" -print -quit || true`
if [ -z "$RAM" ]; then
  RAM=`find . -type f -path "./cramfs.extracted/*" -iname "ramdisk*.gz" -print -quit || true`
fi
if [ -z "$RAM" ]; then
  echo "ramdisk.gz not found; please inspect extracted files."
  exit 1
fi
binwalk -eM "$RAM"

# 9) extract specific extracted shadow file into hash.txt
SHADOW=`find . -type f -path "*_ramdisk.gz.extracted*/*/ext-root/etc/shadow" -print -quit || true`
if [ -z "$SHADOW" ]; then
  SHADOW=`find . -type f -path "*/*/ext-root/etc/shadow" -print -quit || true`
fi
if [ -z "$SHADOW" ]; then
  echo "/etc/shadow not found in extracted ramdisk."
  exit 1
fi
cat "$SHADOW" > hash.txt
echo "Wrote extracted shadow to hash.txt"

# 10) run john against the extracted hash using provided single candidate "12345"
# create a temporary wordlist with the candidate
printf '%s\n' 12345 > wordlist.txt

john --format=md5crypt hash.txt --wordlist=wordlist.txt
john --show --format=md5crypt hash.txt