#!/bin/sh
# /usr/share/vdr/record/record-05-shlib-recordmux.sh
#
#  Calls the recordmux.sh script.
#
#  This file is meant for Gentoo, but may work with other
#  vdr/distribution combinations as well.
#
#
## !! do not use 'set -u' here (remove it if generate_script.sh added it)
RECORDMUX=/sh/lib/vdr-recordmux-hook.sh

if [ -x "${RECORDMUX}" ]; then
   ${RECORDMUX} "$@" || true
fi
