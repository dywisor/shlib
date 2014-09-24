#!/bin/sh
set -u

#@funcdef argparse_minimal_parser<namespace,name>
#  int <namespace>__<name> ( *argv, **arg, **doshift!, **breakparse! )
#

#FAKE_MODE=y
#unset -f run_dmc
#run_dmc() { print_cmd "$@"; }

print_help() (
   set -f
cat << EOF
Usage:

  ${SCRIPT_NAME} [option...] <function> [arg...]

    Calls a systemd_hacks function with the given args.
    A leading "systemd_hacks_" can be omitted from the function name.
    See "${SCRIPT_NAME} help" for a list of functions.

  ${SCRIPT_NAME} [option...] -f <script file> [arg...]

    Loads and processes a systemd-hacks setup script.
    Passes all args after <script file> to the file.


Options:
  -T, --target-dir, --root   <dir>  - target dir        [${TARGET_DIR:-<unset>}]
  -L, --[systemd-]libdir     <dir>  - systemd's libdir  [${SYSTEMD_LIBDIR:-<unset>}]
  -C, --[systemd-]confdir    <dir>  - systemd's confdir [${SYSTEMD_CONFDIR:-<unset>}]
  -h, --help                        - prints this message
  -c, --no-color                    - disable colored output [${NO_COLOR:-n}]

  libdir/confdir must be relative to the target dir, with a leading "/",
  e.g. /usr/lib/systemd.

EOF
)



systemd_hacks_script_argparse__globals() {
   case "${arg}" in
      '-L'|'--libdir'|'--systemd-libdir')
         [ -n "${2-}" ] || die "option ${arg} needs a <dir> arg" ${EX_USAGE}
         SYSTEMD_LIBDIR="${2%/}"; : ${SYSTEMD_LIBDIR:=/}
         doshift=2
      ;;
      '-C'|'--confdir'|'--systemd-confdir')
         [ -n "${2-}" ] || die "option ${arg} needs a <dir> arg" ${EX_USAGE}
         SYSTEMD_CONFDIR="${2%/}"; : ${SYSTEMD_CONFDIR:=/}
         doshift=2
      ;;
      '-T'|'--target-dir'|'--root')
         [ -n "${2-}" ] || die "option ${arg} needs a <dir> arg" ${EX_USAGE}
         [ -d "${2}"  ] || die "${arg} ${2} does not exist!" ${EX_USAGE}
         TARGET_DIR="${2%/}"; : ${TARGET_DIR:=/}
         doshift=2
      ;;
      '-c'|'--no-color')
         NO_COLOR=y
         message_bind_functions
      ;;
      *)
         return 1
      ;;
   esac
}

systemd_hacks_script_argparse__main_break_on_unknown() {
   if ! argparse_minimal_do_parse_global_options "$@"; then
      doshift=0
      breakparse=true
   fi
}



argparse_minimal_parse_args \
   systemd_hacks_script_argparse "globals main_break_on_unknown" "$@"

shift ${ARGPARSE_DOSHIFT:?} || die "shift out of bounds"

setup_print_cmd
systemd_hacks_set_default_aliases


case "${TARGET_DIR-}" in
   '')
      case "${1-}" in
         '-h'|'-V'|*help|*version)
            true
         ;;
         *)
            die "no --target-dir given!" ${EX_USAGE}
         ;;
      esac
   ;;
   '/')
      [ "${I_KNOW_WHAT_I_AM_DOING:-n}" = "y" ] || \
         die "unsafe target dir: ${TARGET_DIR}" 222
   ;;
esac

case "${1-}" in
   '-f')
      [ -n "${2-}" ] || die "${1}: missing <file> arg" ${EX_USAGE}

      # allows /dev/null etc as input file
      test_fs_exists "${2}" && [ ! -d "${2}" ] || \
         die "${1}: file ${2} does not exist." ${EX_USAGE}

      ( eval_scriptinfo "${2}" && shift 2 && . "${SCRIPT_FILE}" "$@"; )
      exit ${?}
   ;;

   *)
      run_main_function "$@"
   ;;
esac
