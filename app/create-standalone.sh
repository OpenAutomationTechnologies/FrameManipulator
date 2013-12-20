#!/bin/bash
#
################################################################################
#  (c) Bernecker + Rainer Industrie-Elektronik Ges.m.b.H.
#      A-5142 Eggelsberg, B&R Strasse 1
#      www.br-automation.com
################################################################################
#

source create-this-app.settings

STANDALONE_DIR="./standalone"
TOOL_DIR="$FM_DIR/tools"


while [ $# -gt 0 ]
do
  case "$1" in
      --standalonedir)
          shift
          STANDALONE_DIR=$1
          echo "INFO: Overwritten STANDALONE_DIR to $STANDALONE_DIR"
          ;;
      --help)
          echo "Usage: ${0} [OPTION]"
          echo
          echo "  --standalonedir PATH  path to stand-alone folder"
          echo
          exit 1
          ;;
  esac
  shift
done



if [ ! -f ./Makefile ]; then
    echo "Missing Makefile!"
    echo "Please run create-this-app first"
    exit 1
fi

echo "Create standalone-folder $STANDALONE_DIR"
mkdir "$STANDALONE_DIR"

echo "Copy sof-file $STANDALONE_DIR/standalone.sof"
SOPC_SOF=`ls $SOPC_DIR*.sof`
cp "$SOPC_SOF" "$STANDALONE_DIR/standalone.sof" || {
    echo "Copy sof-file failed"
    exit 1
}

echo "Copy elf-file $STANDALONE_DIR/standalone.elf"
SOPC_ELF=`ls *.elf`
cp "$SOPC_ELF" "$STANDALONE_DIR/standalone.elf" || {
    echo "Copy elf-file failed"
    exit 1
}

echo "Copy download-script $TOOL_DIR/altera-nios2/flash-device.sh"
cp "$TOOL_DIR/altera-nios2/flash-device.sh" "$STANDALONE_DIR/flash-device.sh" || {
    echo "Copy download-script failed"
    exit 1
}

echo "Create SysID-file $STANDALONE_DIR/SysID.data"
make print-sysid > "$STANDALONE_DIR/SysID.data" || {
    echo "Create SysID-file failed"
    exit 1
}

echo "Create base-address-file $STANDALONE_DIR/base.data"
make print-base-address > "$STANDALONE_DIR/base.data" || {
    echo "Create base-address-file failed"
    exit 1
}


exit 0
