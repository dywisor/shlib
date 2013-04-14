#!/bin/sh
# /usr/share/vdr/record/record-05-shlib-recordmux.sh
#
#  Calls the recordmux.sh script.
#
#  This file is meant for Gentoo, but may work with other
#  vdr/distribution combinations as well.
#
#
RECORDMUX=/sh/lib/vdr-recordmux.sh

if [ -x "${RECORDMUX}" ]; then
	${RECORDMUX} "$@" || true
fi
