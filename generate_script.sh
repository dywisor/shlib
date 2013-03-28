#!/bin/sh
## (EXPERIMENTAL)
set -u

. "${0%/*}/loader.sh" "${0%/*}/lib" && \
loader_load die_minimal message argparse scriptinfo || exit

HELP_DESCRIPTION="make shell scripts"
HELP_BODY="generate shell scripts using ${SCRIPT_DIR}/shlib
and the templates from ${SCRIPT_DIR}/scripts

"

HELP_OPTIONS="
--standalone   (-S) -- make a standalone script,
                       else create a script that relies
                       on a big shlib file
--shlib        (-L) -- shlib file to link against
                       (mutually exclusive with --standalone)
--bash         (-B) -- create a script that uses /bin/bash
--list         (-l) -- list all available scripts
"
HELP_USAGE="Usage: ${SCRIPT_FILENAME} [option...] <script_name> -- <shlibcc args>"

list_scripts() {
	(
		cd "${0%/*}/scripts" && \
			find . -type f -name '*.sh' | cut -b 3- | rev | cut -b 4- | rev | sort
	)
	exit $?
}

argparse_break() {
	SHLIBCC_ARGS="$*"
}

argparse_arg() {
	if [ -z "${IN_SCRIPT-}" ]; then
		case "${arg}" in
			/*)
				IN_SCRIPT="${arg}"
			;;
			./*)
				IN_SCRIPT="${PWD}/${arg#./}"
			;;
			*)
				IN_SCRIPT="${SCRIPT_DIR}/scripts/${arg#scripts/}"
				IN_SCRIPT="${IN_SCRIPT%.sh}.sh"
			;;
		esac
		[ -e "${IN_SCRIPT}" ] || die "${arg} (${IN_SCRIPT}) does not exist."
	else
		die "only one positional arg is accepted"
	fi
}

argparse_shortopt() {
	case "${shortopt}" in
		'S')
			SCRIPT_STANDALONE=y
		;;
		'L')
			[ -n "${1-}" ] || die "--shlib, -L needs an arg"
			SHLIB_TARGET="${1}"
			doshift=1
		;;
		'B')
			SCRIPT_BASH=y
		;;
		'l')
			list_scripts
		;;
		*)
			argparse_unknown
		;;
	esac
}
argparse_longopt() {
	case "${longopt}" in
		'standalone')
			SCRIPT_STANDALONE=y
		;;
		'bash')
			SCRIPT_BASH=y
		;;
		'shlib')
			[ -n "${1-}" ] || die "--shlib, -L needs an arg"
			SHLIB_TARGET="${1}"
			doshift=1
		;;
		'list')
			list_scripts
		;;
		*)
			argparse_unknown
		;;
	esac
}

argparse_autodetect

argparse_parse "$@"    || die "argparse() failed"
[ -n "${IN_SCRIPT-}" ] || die "${HELP_USAGE}"

if [ -z "${NEEDS_SHLIB-}" ]; then
	if [ -e "${IN_SCRIPT}.depend" ] || [ -e "${IN_SCRIPT%.sh}.depend" ]; then
		NEEDS_SHLIB=y
	else
		NEEDS_SHLIB=n
	fi
fi

if [ "${SCRIPT_STANDALONE=n}" = "y" ]; then
	opts="${SHLIBCC_ARGS=-u --strip-virtual}"
	if [ "${NEEDS_SHLIB}" = "y" ]; then
		opts="${opts} -D"
	else
		opts="${opts} --allow-empty --short-header"
	fi
	[ "${SCRIPT_BASH=n}" != "y" ] || opts="${opts} --bash"

	"${SCRIPT_DIR}/CC" ${opts} --main "${IN_SCRIPT}"
else
	IN_SCRIPT_NAME="${IN_SCRIPT##*/}"
	IN_SCRIPT_NAME="${IN_SCRIPT_NAME%.*}"

	: ${SHLIB_TARGET:=/sh/lib/shlib.sh}
	{
		if [ "${SCRIPT_BASH=n}" = "y" ]; then
			echo '#!/bin/bash'
		else
			echo '#!/bin/sh'
		fi
		echo '# -*- coding: utf-8 -*-'
		echo '#'
		echo "# script ${IN_SCRIPT_NAME}"
		echo '#'
		if [ "${SCRIPT_BASH}" = "y" ]; then
			echo "set -o nounset"
			echo "set +o history"
		else
			echo "set -u"
		fi
		if [ "${NEEDS_SHLIB}" = "y" ]; then
			echo
			echo ". \"${SHLIB_TARGET}\" -- || exit"
		fi
		echo
		grep -v ^'#![[:blank:]]*/bin' "${IN_SCRIPT}"
	}
fi
