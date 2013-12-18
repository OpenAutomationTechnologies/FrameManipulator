#!/bin/bash
#
################################################################################
#  (c) Bernecker + Rainer Industrie-Elektronik Ges.m.b.H.
#      A-5142 Eggelsberg, B&R Strasse 1
#      www.br-automation.com
################################################################################
#


SOURCE_DIR=.


while [ $# -gt 0 ]
do
  case "$1" in
      --sourcedir)
          shift
          SOURCE_DIR=$1
          echo "INFO: Overwritten SOURCE_DIR to $SOURCE_DIR"
          ;;
      --help)
          echo "Usage: ${0} [OPTION]"
          echo
          echo "  --sourcedir PATH   path to source folder"
          echo
          exit 1
          ;;
  esac
  shift
done


#Sources check
SOURCE_ELF=`ls $SOURCE_DIR/*.elf` || {
    echo "Missing elf-file"
    exit 1
}
SOURCE_SOF=`ls $SOURCE_DIR/*.sof` || {
    echo "Missing sof-file"
    exit 1
}
ls $SOURCE_DIR/SysID.data || {
    echo "Missing sysid-file"
    exit 1
}
ls $SOURCE_DIR/base.data || {
    echo "Missing base-address-file"
    exit 1
}

#Flash device
echo "Download sof-file"
nios2-configure-sof -C "$SOURCE_DIR"

echo "Convert sof-file $SOURCE_SOF to flash $SOURCE_DIR/sof.flash"
sof2flash --epcs --input="$SOURCE_SOF" --output="$SOURCE_DIR/sof.flash"

echo "Convert elf-file $SOURCE_ELF to flash $SOURCE_DIR/elf.flash"
elf2flash --after="$SOURCE_DIR/sof.flash" --input="$SOURCE_ELF" --outfile="$SOURCE_DIR/elf.flash" --epcs

echo "Load SysID $SOURCE_DIR/SysID.data"
SYSID=`cat "$SOURCE_DIR/SysID.data"`
echo "SysID: $SYSID"

echo "Load base address $SOURCE_DIR/base.data"
BASE=`cat "$SOURCE_DIR/base.data"`
echo "Base: $BASE"

echo "Download flash"
nios2-flash-programmer "$SOURCE_DIR/sof.flash" "$SOURCE_DIR/elf.flash" --base=$BASE --epcs $SYSID


exit 0
