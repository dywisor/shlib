#!/bin/sh
#
#  Search the shlib dir for modules that are not part of
#  the "all" library file.
#
# Usage: ./find-not-included.sh [--sort|-s]
#
# Output:
# A <dir> -- dir has no "all.sh" file
# D <dir> -- dir not included by parent directory
# F <dir> -- module file not included
#

S=`readlink -f "${0%/*}/lib"`

if [ ! -d "${S}" ]; then
	echo "'${S}' does not exist." 1>&2
	exit 2
fi

check_dir() {
	local rel="${1#${S}}"
	rel="${rel#/}"

	if [ ! -e "${1}/all.sh" ]; then
		echo "A ${rel}"
	else
		local f n
		for f in "${1}"/*.sh; do
			n="${f##*/}"
			n="${n%*.sh}"
			if [ "${n}" != "all" ]; then
				n="${rel}/${n}"
				n="${n#/}"
				grep -q ^"${n}"$ "${1}/all.depend" || echo "F ${n}"
			fi
		done
		local d
		for d in "${1}"/*; do
			if [ -d "${d}" ]; then
				n="${d##*/}"
				n="${rel}/${n}"
				n="${n#/}"
				grep -q ^"${n}/all"$ "${1}/all.depend" || echo "D ${n}"

				check_dir "${d}"
			fi
		done
	fi
}

case "${1-}" in
	'-s'|'--sort')
		check_dir "${S}" | sort
	;;
	*)
		check_dir "${S}"
	;;
esac
