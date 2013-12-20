#!/bin/bash
#
################################################################################
#  (c) Bernecker + Rainer Industrie-Elektronik Ges.m.b.H.
#      A-5142 Eggelsberg, B&R Strasse 1
#      www.br-automation.com
################################################################################
#


SOURCE_DIR=.
SKIP_CONV_ELF=
SKIP_CONV_SOF=
SKIP_BASE=
IGNORE_SYS=

NAME_ELF_FLASH="elf"
NAME_SOF_FLASH="sof"

while [ $# -gt 0 ]
do
  case "$1" in
      --ignore-sysid)
          IGNORE_SYS=1
          echo "INFO: SysID will be ignored"
          ;;
      --sourcedir)
          shift
          SOURCE_DIR=$1
          echo "INFO: Overwritten SOURCE_DIR to $SOURCE_DIR"
          ;;
      --use-elf-flash)
          shift
          NAME_ELF_FLASH=$1
          SKIP_CONV_ELF=1
          echo "INFO: Generated elf-flash-file $NAME_ELF_FLASH will be used"
          ;;
      --use-sof-flash)
          shift
          NAME_SOF_FLASH=$1
          SKIP_CONV_SOF=1
          echo "INFO: Generated sof-flash-file $NAME_SOF_FLASH will be used"
          ;;
      --set-base)
          shift
          SKIP_BASE=1
          BASE=$1
          echo "INFO: Set base-address to $BASE"
          ;;
      --help)
          echo "Usage: ${0} [OPTION]"
          echo
          echo "  --ignore-sysid                ignore SysID mismatch"
          echo "  --sourcedir     PATH          path to source folder"
          echo "  --use-elf-flash NAME          use existing elf .flash-file"
          echo "  --use-sof-flash NAME          use existing sof .flash-file"
          echo "  --set-base      BASE-ADDRESS  set base-address manually via 0x.."
          echo
          exit 1
          ;;
  esac
  shift
done

######################
#Sources check
if [ -z "$SKIP_CONV_ELF" ]; then
    SOURCE_ELF=`ls $SOURCE_DIR/*.elf` || {
        echo "Missing elf-file"
        exit 1
    }
fi

if [ -z "$SKIP_CONV_SOF" ]; then
    SOURCE_SOF=`ls $SOURCE_DIR/*.sof` || {
        echo "Missing sof-file"
        exit 1
    }
fi

if [ -z "$IGNORE_SYS" ]; then
    ls $SOURCE_DIR/SysID.data || {
        echo "Missing sysid-file"
        exit 1
    }
fi

if [ -z "$SKIP_BASE" ]; then
    ls $SOURCE_DIR/base.data || {
        echo "Missing base-address-file"
        exit 1
    }
fi

######################
#Flash device

#Download bitstream
echo "Download sof-file"
nios2-configure-sof -C "$SOURCE_DIR"|| {
    echo "Downloading bitstream failed"
    exit 1
}

#convert sof to sof-flash file
SOURCE_SOF_FLASH=$SOURCE_DIR/$NAME_SOF_FLASH.flash

if [ -z "$SKIP_CONV_SOF" ]; then
    echo "Convert sof-file $SOURCE_SOF to flash $SOURCE_SOF_FLASH"
    sof2flash --epcs --input="$SOURCE_SOF" --output="$SOURCE_SOF_FLASH"
fi

#convert elf to elf-flash file
SOURCE_ELF_FLASH=$SOURCE_DIR/$NAME_ELF_FLASH.flash

if [ -z "$SKIP_CONV_ELF" ]; then
    echo "Convert elf-file $SOURCE_ELF to flash $SOURCE_ELF_FLASH"
    elf2flash --after="$SOURCE_SOF_FLASH" --input="$SOURCE_ELF" --outfile="$SOURCE_ELF_FLASH" --epcs
fi

#Load SysID from file
if [ -z "$IGNORE_SYS" ]; then
    echo "Load SysID $SOURCE_DIR/SysID.data"
    SYSID=`cat "$SOURCE_DIR/SysID.data"`
    echo "SysID: $SYSID"
fi

#Load base-address from file
if [ -z "$SKIP_BASE" ]; then
    echo "Load base address $SOURCE_DIR/base.data"
    BASE=`cat "$SOURCE_DIR/base.data"`
    echo "Base: $BASE"
fi

#Download
echo "Download flash"
DOWNLOAD_PARAM="$SOURCE_SOF_FLASH $SOURCE_ELF_FLASH --base=$BASE --epcs"

if [ -z "$IGNORE_SYS" ]; then
    DOWNLOAD_PARAM+=" $SYSID"
fi
echo "Start download with $DOWNLOAD_PARAM"
nios2-flash-programmer $DOWNLOAD_PARAM



exit 0
