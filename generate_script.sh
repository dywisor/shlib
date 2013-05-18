#!/bin/sh
## (EXPERIMENTAL)
set -u

. "${0%/*}/loader.sh" "${0%/*}/lib" && \
loader_load autodie die message || exit
autodie loader_load argparse scriptinfo misc/qwhich fs/dodir_minimal

HELP_DESCRIPTION="make shell scripts"
HELP_BODY="generate shell scripts using ${SCRIPT_DIR}/lib \
and the templates from ${SCRIPT_DIR}/scripts

"

HELP_OPTIONS="
--standalone   (-S) -- make a standalone script,
                       else create a script that relies
                       on a big shlib file
--shlib        (-L) -- shlib file to link against
                       (mutually exclusive with --standalone)
--interpreter  (-I) -- set interpreter (defaults to /bin/sh)
--bash         (-B) -- set interpreter to /bin/bash and use bash modules
--output       (-O) -- write script to file (defaults to '-', stdout)
--chmod             -- chmod output file (defaults to 0755)
--verify       (-C) -- perform basic script verification, needs -O
--name         (-N) -- name of the script
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

argparse_set_output() {
	argparse_need_arg "$@"
	case "${1}" in
		'-')
			SCRIPT_OUTFILE=
		;;
		*)
			SCRIPT_OUTFILE=$(readlink -m "${1}")
		;;
	esac
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
			argparse_need_arg "$@"
			SHLIB_TARGET="${1}"
		;;
		'B')
			SCRIPT_BASH=y
			SCRIPT_INTERPRETER=/bin/bash
		;;
		'l')
			LIST_SCRIPTS=y
		;;
		'I')
			argparse_need_arg "$@"
			SCRIPT_INTERPRETER="${1}"
		;;
		'O')
			argparse_set_output "$@"
		;;
		'C')
			SCRIPT_VERIFY=y
		;;
		'N')
			argparse_need_arg "$@"
			IN_SCRIPT_NAME="${1}"
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
			SCRIPT_INTERPRETER=/bin/bash
		;;
		'shlib')
			argparse_need_arg "$@"
			SHLIB_TARGET="${1}"
		;;
		'list')
			LIST_SCRIPTS=y
		;;
		'interpreter')
			argparse_need_arg "$@"
			SCRIPT_INTERPRETER="${1}"
		;;
		'output')
			argparse_set_output "$@"
		;;
		'verify')
			SCRIPT_VERIFY=y
		;;
		'chmod')
			argparse_need_arg "$@"
			SCRIPT_CHMOD="${1}"
		;;
		'name')
			argparse_need_arg "$@"
			IN_SCRIPT_NAME="${1}"
		;;
		*)
			argparse_unknown
		;;
	esac
}

argparse_autodetect

argparse_parse "$@" 1>&2 || die "argparse() failed"

if [ "${LIST_SCRIPTS:-n}" = "y" ]; then
	list_scripts
fi


[ -n "${IN_SCRIPT-}" ]   || die "${HELP_USAGE}"

if [ -z "${NEEDS_SHLIB-}" ]; then
	if [ -e "${IN_SCRIPT}.depend" ] || [ -e "${IN_SCRIPT%.sh}.depend" ]; then
		NEEDS_SHLIB=y
	else
		NEEDS_SHLIB=n
	fi
fi

makescript() {
	if [ "${SCRIPT_STANDALONE=n}" = "y" ]; then
		local opts="${SHLIBCC_ARGS=-u --strip-virtual}"
		if [ "${NEEDS_SHLIB}" = "y" ]; then
			opts="${opts} -D"
		else
			opts="${opts} --allow-empty --short-header"
		fi
		[ "${SCRIPT_BASH=n}" != "y" ] || opts="${opts} --bash"

		"${SCRIPT_DIR}/CC" ${opts} --stable-sort --main "${IN_SCRIPT}"
	else
		if [ -z "${IN_SCRIPT_NAME-}" ]; then
			IN_SCRIPT_NAME="${IN_SCRIPT##*/}"
			IN_SCRIPT_NAME="${IN_SCRIPT_NAME%.*}"
		fi

		: ${SHLIB_TARGET:=/sh/lib/shlib.sh}
		{
			echo "#!${SCRIPT_INTERPRETER:-/bin/sh}"
			echo '# -*- coding: utf-8 -*-'
			echo '#'
			echo "# script ${IN_SCRIPT_NAME}"
			echo '#'
			if [ "${SCRIPT_BASH=n}" = "y" ]; then
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
}

makescript_file() {
	dodir_clean "${SCRIPT_OUTFILE%/*}" && makescript > "${SCRIPT_OUTFILE:?}"
}

if [ -z "${SCRIPT_OUTFILE-}" ]; then
	[ "${SCRIPT_VERIFY:-n}" != "y" ] || argparse_die "--verify needs --output"
	autodie makescript
else
	rc=0
	makescript_file || rc=$?
	if [ ${rc} -ne 0 ]; then
		if [ "${SCRIPT_OUTFILE_REMOVE:-y}" = "y" ]; then
			[ ! -e "${SCRIPT_OUTFILE}" ] || autodie rm -- "${SCRIPT_OUTFILE}"
		fi
		die "makescript_file() returned ${rc}."
	fi
	autodie test -s "${SCRIPT_OUTFILE}"

	if [ "${SCRIPT_VERIFY:-n}" = "y" ]; then
		if [ "${SCRIPT_BASH=n}" = "y" ]; then
			autodie bash -n "${SCRIPT_OUTFILE}"
		else
			#local interpreter
			for interpreter in "bash" "busybox ash" "dash"; do
				if qwhich "${interpreter%% *}"; then
					autodie ${interpreter} -n "${SCRIPT_OUTFILE}"
				else
					ewarn "'${interpreter}' is not available."
				fi
			done
		fi
	fi

	autodie chmod ${SCRIPT_CHMOD:-0755} "${SCRIPT_OUTFILE}"
fi
