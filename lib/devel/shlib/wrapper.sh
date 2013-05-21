# @extern void print_command ( exe, *argv, **PRINTCMD_... )
# @extern void print_pwd     ( [message], **PWD, **PRINTCMD_... )


DODIR() { print_command "DODIR" "$*"; autodie dodir_clean "$@"; }

unset -f run
run() { print_pwd "$*"; "$@" || die "command '$*' returned ${?}"; }
RUN() { run "$@"; }

# void nofail ( *cmdv )
nofail()   { "$@" || return 0; }
# @function_alias nonfatal() copies nofail()
nonfatal() { "$@" || return 0; }

# int _CC ( *argv, **SHLIBCC, **SHLIBCC_ARGS )
#
_CC() { ${SHLIBCC:?} -S "${SHLIB_ROOT?}" ${SHLIBCC_ARGS-} "$@"; }

# void CC* ( *argv, **SHLIBCC, **SHLIBCC_ARGS )
#
CC() { print_command "CC" "$*"; autodie _CC "$@"; }

CC_script() {
   print_command "CC [script]" "${dest}${*:+, }${*}"

   local opts="${SHLIBCC_ARGS_SCRIPT-}"
   [ "${SCRIPT_USE_BASH:-n}" != "y" ] || opts="${opts} --bash"
   [ "${SCRIPT_SET_U:-y}"    != "y" ] || opts="${opts} -u"

   autodie _CC ${opts} --depfile --main "${script:?}" -O "${dest:?}" "$@"
}
CC_lib() {
   print_command "CC [lib]" "${dest}${*:+, }${*}"

   local opts="${SHLIBCC_ARGS_LIB-} --as-lib"
   [ "${SCRIPT_USE_BASH:-n}" != "y" ] || opts="${opts} --bash"

   autodie _CC ${opts} -O "${dest:?}" "$@"
}
CC_splitlib() {
   print_command "CC [splitlib]" "${dest}${*:+, }${*}"

   local opts="${SHLIBCC_ARGS_LIB-} --as-lib"
   [ "${SCRIPT_USE_BASH:-n}" != "y" ] || opts="${opts} --bash"

   autodie _CC ${opts} --depfile "${script%.sh}.depend" -O "${dest:?}" "$@"
}

CC_nostdout() {
   die "to be removed"
   print_command "CC" "$*";
   _CC "$@" 1>${DEVNULL:?} || die "'CC $*' returned ${?}."
}
CC_quiet() {
   die "to be removed"
   print_command "CC" "$*";
   _CC "$@" 1>${DEVNULL:?} 2>${DEVNULL} || die "'CC $*' returned ${?}."
}
