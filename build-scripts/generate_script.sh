#!/usr/bin/shlib-runscript
set -u

print_help() {
cat << EOF
${SCRIPT_NAME} - script generation helper

Usage: ${SCRIPT_FILENAME} [option...] <script_name> -- <shlibcc args>

Options:
  --standalone   (-S) -- make a standalone script,
                         else create a script that relies
                         on a big shlib file
  --shlib        (-L) -- shlib file to link against
                         (mutually exclusive with --standalone)
  --interpreter  (-I) -- set interpreter (defaults to /bin/sh)
  --bash         (-B) -- set interpreter to /bin/bash and use bash modules
  --output       (-O) -- write script to file (defaults to '-', stdout)
  --chmod             -- chmod output file (defaults to 0755)
  --split-lib    (-P) -- write the library to a separate file
  --chmod-lib         -- chmod library file (defaults to 0644)
  --verify       (-C) -- perform basic script verification, needs -O
  --name         (-N) -- name of the script
  --force        (-f) -- overwrite existing files
  --list         (-l) -- list all available scripts

EOF
}

argparse_need_nonempty_arg() {
	[ -n "${2-}" ] || die "option ${1:?} needs a non-empty arg." ${EX_USAGE}
	doshift=2
}

argparse_need_fspath_arg() {
	argparse_need_nonempty_arg "$@"
	autodie get_fspath "${2}"
}

shlib_genscript__options() {
	case "${arg}" in
		-S|--standalone)
			SCRIPT_STANDALONE=y
		;;
		-L|--shlib)
			argparse_need_fspath_arg "$@"
			SHLIB_TARGET="${v0}"
		;;
		-I|--interpreter)
			argparse_need_nonempty_arg "$@"
			SCRIPT_INTERPRETER="${2}"
		;;
		-B|--bash)
			SCRIPT_BASH=y
			SCRIPT_INTERPRETER=/bin/bash
		;;
		-O|--output)
			argparse_need_fspath_arg "$@"
			SCRIPT_OUTFILE="${v0}"
		;;
		--chmod)
			argparse_need_nonempty_arg "$@"
			SCRIPT_CHMOD="${2}"
		;;
		-P|--split-lib)
			argparse_need_fspath_arg "$@"
			SCRIPT_LIB_OUTFILE="${v0}"
		;;
		--chmod-lib)
			argparse_need_nonempty_arg "$@"
			SCRIPT_LIB_CHMOD="${2}"
		;;
		-C|--verify)
			SCRIPT_VERIFY=y
		;;
		-N|--name)
			argparse_need_nonempty_arg "$@"
			IN_SCRIPT_NAME="${2}"
		;;
		-f|--force)
			FORCE=y
		;;
		-l|--list)
			LIST_SCRIPTS=y
		;;
		--)
			doshift=0
			breakparse=true
		;;
		-*|'')
			return 1
		;;
		*)
			if [ -z "${IN_SCRIPT-}" ]; then
				case "${arg}" in
					/*)
						IN_SCRIPT="${arg}"
					;;
					./*)
						IN_SCRIPT="${PWD}/${arg#./}"
					;;
					*)
						IN_SCRIPT="${SHLIB_PRJROOT:?}/scripts/${arg#scripts/}"
						IN_SCRIPT="${IN_SCRIPT%.sh}.sh"
					;;
				esac
				[ -e "${IN_SCRIPT}" ] || die "${arg} (${IN_SCRIPT}) does not exist."

			else
				ewarn "only one positional arg is accepted"
				return 2
			fi
		;;
	esac

	return 0
}

shlib_genscript__global_options() {
	 argparse_minimal_do_parse_global_options "$@"
}

list_scripts() {
	(
		cd "${0%/*}/scripts" && \
			find . -type f -name '*.sh' | \
				sed -r -e 's@^[.]/@@' -e 's@[.]sh$@@' | sort
	)
	exit $?
}




argparse_minimal_parse_args \
	shlib_genscript "options global_options" "$@" || die
[ ${ARGPARSE_DOSHIFT} -lt 1 ] || shift ${ARGPARSE_DOSHIFT} || die
if [ $# -gt 0 ]; then
	shift
	SHLIBCC_ARGS="$*"
fi


if [ "${LIST_SCRIPTS:-n}" = "y" ]; then
	list_scripts
fi

[ -n "${IN_SCRIPT-}" ]   || die "${HELP_USAGE}"

: ${FORCE:=n}

: ${SCRIPT_BASH:=n}

: ${SHLIBCC_LIB_ARGS=--as-lib --strip-virtual}
: ${SHLIBCC_ARGS=-u --strip-virtual}

: ${SCRIPT_STANDALONE:=n}
: ${DEFAULT_SHLIB_TARGET:=/sh/lib/shlib.sh}
: ${SCRIPT_INTERPRETER:=/bin/sh}

: ${SCRIPT_VERIFY:=n}

: ${SCRIPT_OUTFILE=}
[ -n "${SCRIPT_OUTFILE_REMOVE+SET}" ] || SCRIPT_OUTFILE_REMOVE=y
: ${SCRIPT_CHMOD:=0755}

: ${SCRIPT_LIB_OUTFILE=}
: ${SCRIPT_LIB_CHMOD:=0644}

if [ -z "${SCRIPT_OUTFILE}" ] && [ "${SCRIPT_VERIFY}" = "y" ]; then
	argparse_die "--verify needs --output"
fi

if [ -e "${IN_SCRIPT}.depend" ]; then
	NEEDS_SHLIB="${IN_SCRIPT}.depend"
else
	NEEDS_SHLIB="${IN_SCRIPT%.sh}.depend"
	[ -f "${NEEDS_SHLIB}" ] || NEEDS_SHLIB=
fi

if [ -n "${SCRIPT_LIB_OUTFILE}" ]; then
	if [ -z "${NEEDS_SHLIB}" ]; then
		argparse_die "--split-lib: ${IN_SCRIPT%.sh} has no dependencies."
	elif [ -z "${SHLIB_TARGET-}" ]; then
		argparse_die "--split-lib needs --shlib."
	elif [ -z "${SCRIPT_OUTFILE}" ]; then
		argparse_die "--split-lib needs --output."
	fi
fi


makesplitlib() {
	script_force_remove "${SCRIPT_LIB_OUTFILE}" && \
	dodir_minimal "${SCRIPT_LIB_OUTFILE%/*}" || return

	local opts="${SHLIBCC_LIB_ARGS}"
	[ "${SCRIPT_BASH}" != "y" ] || opts="${opts} --bash"

	"${SHLIB_PRJROOT:?}/CC" ${opts} --stable-sort \
		--depfile "${NEEDS_SHLIB:?}" -O "${SCRIPT_LIB_OUTFILE}"
}

makescript() {
	if \
		[ -z "${SCRIPT_LIB_OUTFILE}" ] && [ "${SCRIPT_STANDALONE}" = "y" ]
	then
		local opts="${SHLIBCC_ARGS} --stable-sort"
		[ "${SCRIPT_BASH}" != "y" ] || opts="${opts} --bash"

		if [ -n "${NEEDS_SHLIB}" ]; then
			"${SHLIB_PRJROOT:?}/CC" ${opts} \
				--main "${IN_SCRIPT}" --depfile "${NEEDS_SHLIB}"
		else
			"${SHLIB_PRJROOT:?}/CC" ${opts} \
				--main "${IN_SCRIPT}" --allow-empty --short-header
		fi
	else
		if [ -z "${IN_SCRIPT_NAME-}" ]; then
			IN_SCRIPT_NAME="${IN_SCRIPT##*/}"
			IN_SCRIPT_NAME="${IN_SCRIPT_NAME%.*}"
		fi

		{
			echo "#!${SCRIPT_INTERPRETER}"
			echo '# -*- coding: utf-8 -*-'
			echo '#'
			echo "# script ${IN_SCRIPT_NAME}"
			[ -z "${SCRIPT_LIB_OUTFILE}" ] || echo '# *** split-lib ***'
			echo '#'
			echo "set -u"
			if [ -n "${NEEDS_SHLIB}" ]; then
				echo
				echo ". \"${SHLIB_TARGET:-${DEFAULT_SHLIB_TARGET}}\" -- || exit"
			fi
			echo
			grep -v ^'#![[:blank:]]*/bin' "${IN_SCRIPT}"
		}
	fi
}

makescript_file() {
	script_force_remove "${SCRIPT_OUTFILE}" && \
	dodir_minimal "${SCRIPT_OUTFILE%/*}" && \
	makescript > "${SCRIPT_OUTFILE:?}"
}

shverify_file() {
	autodie test -s "${1}"
	if [ "${SCRIPT_VERIFY}" = "y" ]; then
		einfo "Verifying ${1} ... "
		local any_test

		if qwhich bash; then
			autodie bash -n "${1}" && any_test=bash
		else
			ewarn "'bash' is not available."
		fi

		if [ "${SCRIPT_BASH}" != "y" ]; then
			if qwhich dash; then
				autodie dash -n "${1}" && any_test=dash
			else
				ewarn "'dash' is not available."
			fi

			if qwhich busybox && busybox --list 2>/dev/null | grep -qx ash; then
				autodie busybox ash -n "${1}" && any_test=ash
			else
				ewarn "'busybox ash' is not available."
			fi
		fi

		if [ -z "${any_test-}" ]; then
			die "failed to verify '${1}': no interpreter available."
		fi
	fi
}

script_outfile_remove() {
	if [ "${SCRIPT_OUTFILE_REMOVE}" = "y" ]; then
		[ ! -e "${1}" ] || autodie rm -- "${1}"
	fi
}
script_force_remove() {
	if [ -h "${1}" ] || [ -f "${1}" ]; then
		if [ "${FORCE}" = "y" ]; then
			autodie rm -- "${1}"
			return 0
		else
			die "'${1}' exists."
		fi
	elif [ -e "${1}" ]; then
		die "'${1}' exists, but is neither a file nor a symlink."
	else
		return 0
	fi
}


if [ -z "${SCRIPT_OUTFILE}" ]; then
	autodie makescript
else
	if [ -n "${SCRIPT_LIB_OUTFILE}" ]; then
		rc=0
		makesplitlib || rc=$?
		if [ ${rc} -ne 0 ]; then
			script_outfile_remove "${SCRIPT_LIB_OUTFILE}"
			die "makesplitlib() returned ${rc}."
		fi
		shverify_file "${SCRIPT_LIB_OUTFILE}"
		autodie chmod ${SCRIPT_LIB_CHMOD} "${SCRIPT_LIB_OUTFILE}"
	fi

	rc=0
	makescript_file || rc=$?
	if [ ${rc} -ne 0 ]; then
		script_outfile_remove "${SCRIPT_OUTFILE}"
		die "makescript_file() returned ${rc}."
	fi
	shverify_file "${SCRIPT_OUTFILE}"
	autodie chmod ${SCRIPT_CHMOD} "${SCRIPT_OUTFILE}"
fi
