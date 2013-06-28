#!/bin/bash

# Script for decompiling android boot.img, recovery.img and single RamDisks. .img's with header
# words (KERNEL/ROOTFS/RECOVERY) are supported as well as .img's without these words (simply gzip'd)
# Usage:
#   ./unpack.sh <file>
#      <file> is a path whose file name contains *recovery*, *boot*, *ram* or *Ram*.
#             This name determines the script's behavior.
#             Paths and names with spaces are supported.

echo ### Script for unpacking android boot.img & recovery.img (c) SpellCaster (based on igor_newman's scripts) ###

# Check params
FULLPATH=$1
BASEDIR=${FULLPATH%/*}
FULLNAME=${FULLPATH##*/}
FILENAME=${FULLNAME%.*}

if [ "$BASEDIR" == "$FULLNAME" ]; # process the case with empty path
then
  BASEDIR="." 
fi

if [[ "$FILENAME" =~ boot ]];
then
  FS=ROOTFS
  DESTDIR=$BASEDIR/${FILENAME}_unp
  DOEXTRACT=1
elif [[ "$FILENAME" =~ recovery ]];
then
  FS=RECOVERY
  DESTDIR=$BASEDIR/${FILENAME}_unp
  DOEXTRACT=1
elif [[ "$FILENAME" =~ [rR]am ]];
then
  FS=RECOVERY
  DESTDIR=$BASEDIR/${FILENAME}_unp
  DOEXTRACT=0
else
  echo "Usage: ./unpack.sh (*recovery* | *boot* | *ram* | *Ram* )"
  exit 1
fi

# echo $BASEDIR @@ $FULLNAME @@ $FILENAME
# exit 0

if [ -d "$DESTDIR" ];
then
  rm -rf "$DESTDIR"
fi
mkdir "$DESTDIR"

echo "Unpacking $FULLNAME..."

# Global var for FIND_BY_HEADER_WORD and FIND_BY_GZIP_HEADER because functions can return only 0..255
declare -i POS=0

# Searches thru file $1 for given word $2, returns 0 on success, 1 if not found
function FIND_BY_HEADER_WORD
{
  echo "Searching for $2"
  
  POS=$(grep -o -b -U -a -m 1 "$2" "$1" | grep -o -E "[0-9]+")
    if [ $? -ne 0 ] && [ $POS -lt 8 ];
    then
      echo "$2 not found"  
      return 1
    fi
  # Add 8 bytes of preceding header
  POS=$POS-8
  echo "Found $2 at $POS..."
  return 0
}

# Searches thru file $1 for $2-th occurence of gzip header 1F 8B 08 00, returns 0 on success, 1 if not found
function FIND_BY_GZIP_HEADER
{
  echo "Searching for gzip header #$2"
  
  declare -i COUNT=0
  for POS in $(grep -o -b -U -a -P "\x1F\x8B\x08\x00" "$1" | grep -o -a -E "[0-9]+") ;
  do
    COUNT=$COUNT+1
    if [ $COUNT -eq $2 ];
    then
      echo "Found header at $POS..."
      return 0
    fi
  done

  echo "Header not found"  
  return 1
}

# boot.img or recovery.img => do extracting
if [ $DOEXTRACT -ne 0 ];
then
  # Try to find by header keywords
  FIND_BY_HEADER_WORD "$FULLPATH" "KERNEL"
  if [ $? -eq 0 ];
  then
    NUMKER=$POS
    FIND_BY_HEADER_WORD "$FULLPATH" "$FS"
	if [ $? -eq 0 ];
	then
	  NUMREC=$POS
	fi
  # Try to find by gzip header
  else
    echo "Will try to find GZIP'd images..."
    FIND_BY_GZIP_HEADER "$FULLPATH" 1
    if [ $? -ne 0 ];
    then
      exit 1
    fi
    NUMKER=$POS
    FIND_BY_GZIP_HEADER "$FULLPATH" 2
    if [ $? -ne 0 ];
    then
      exit 1
    fi
    NUMREC=$POS
  fi
  
  echo "Extracting files to $DESTDIR/..."
  
  echo "Extracting kernel..."
  # Copy data from $NUMKER-th to $NUMREC-th byte
  dd if="$FULLPATH" of="$DESTDIR/kernel" bs=1 skip=$NUMKER count=$(($NUMREC-$NUMKER))
  echo "Extracting ramdisk..."
  dd if="$FULLPATH" of="$DESTDIR/ramdisk" bs=$NUMREC skip=1
else
  cp "$FULLPATH" "$DESTDIR/ramdisk"
fi

# For images with header: find where gzip starts
# For images gzip'd only: NUMRAM will be 0
FIND_BY_GZIP_HEADER "$DESTDIR/ramdisk" 1
if [ $? -ne 0 ];
then
  exit 1
fi
NUMRAM=$POS

# Different cases for ram disk with header and without it
if [ $NUMRAM -ne 0 ];
then
  dd if="$DESTDIR/ramdisk" of="$DESTDIR/ram_header" bs=$NUMRAM count=1
  dd if="$DESTDIR/ramdisk" bs="$NUMRAM" skip=1 | gunzip > "$DESTDIR/ramdisk_unz"
else
  mv "$DESTDIR/ramdisk" "$DESTDIR/ramdisk_unz.gz"
  gunzip "$DESTDIR/ramdisk_unz.gz"
fi

echo "Unpacking ramdisk..."

mkdir "$DESTDIR/rmdisk"
pushd "$DESTDIR/rmdisk"
cpio -id < "../ramdisk_unz"
popd

echo "Done!"