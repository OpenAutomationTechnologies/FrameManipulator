#!/bin/bash
#
################################################################################
#  (c) Bernecker + Rainer Industrie-Elektronik Ges.m.b.H.
#      A-5142 Eggelsberg, B&R Strasse 1
#      www.br-automation.com
################################################################################
#

SKIP_DOC=

while [ $# -gt 0 ]
do
  case "$1" in
      --skip-doc)
          SKIP_DOC=1
          echo "INFO: Skip generate development documentation"
          ;;
      --help)
          echo "Usage: ${0} [OPTION]"
          echo
          echo "  --skip-doc        skip generate development documentation"
          echo
          exit 1
          ;;
  esac
  shift
done


#Load Images
IMAGE_LIST=`ls "./images/"*.gv `


#convert images via dot
for IMAGE in $IMAGE_LIST
do

    #remove extension
    IMAGE_NAME=${IMAGE%.*}
    echo "Create Image ${IMAGE_NAME}.png"

    #convert
    dot -Tpng "${IMAGE}" -o "${IMAGE_NAME}.png"

done

#generate document
if [ -z "$SKIP_DOC" ]; then
    echo "Generate development documentation"
    doxygen

fi
