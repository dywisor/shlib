#@section functions

main_print_help() {
cat << END_OF_HELP
${SCRIPT_NAME} -- basic liram maintenance

Provides the following tools:
[* pack: pack the current system into a new slot]
[* kernup: fetch/update kernel]
[* update-core: fetch/update core images]
[* fixup: try to fix issues]


Usage: ${SCRIPT_NAME} [-h] [-V] [--pack] [--slot <name>] [arg...]

Options:
  -h, --help, --usage    show this message and exit
  -V, --version          print the version and exit
  -s, --slot <name>      set the base name of the new slot (--pack)
  -P, --pack             set command to 'pack'
  -K, --kernup           set command to 'kernup'      [TODO]
  -U, --update-core      set command to 'update-core' [TODO]
  -F, --fixup            set command to 'fixup'       [TODO]
END_OF_HELP
}

#@section __main__

liram_manage_init_vars || exit

liram_manage_atexit_register || die
atexit_enable TERM EXIT

SCRIPT_MODE=pack

: ${PACK_TARGETS=}

POS_ARGS=
doshift=
while [ ${#} -gt 0 ]; do
   doshift=1
   case "${1}" in
      '')
         true
      ;;
      '--slot'|'-s')
         [ -n "${2-}" ] && [ "${2#-}" = "${2}" ] || die "${1} needs an arg."
         LIRAM_SLOT_NAME="${2}"
         doshift=2
      ;;
      '--pack'|'-P')
         SCRIPT_MODE="pack"
      ;;
      '--fixup'|'-F')
         SCRIPT_MODE="fixup"
      ;;
      '--kernup'|'-K')
         # **LIRAM_MANAGE_X_UPDATE_KERNEL
         SCRIPT_MODE="kernup"
      ;;
      '--update-core'|'-U') # |-u
         # **LIRAM_MANAGE_X_UPDATE_CORE
         SCRIPT_MODE="update-core"
      ;;
      '--help'|'--usage'|'-h')
         main_print_help
         exit ${EX_OK}
      ;;
      '--version'|'-V')
         echo "0.0.2"
         exit ${EX_OK}
      ;;
      '--')
         shift || die
         break
      ;;
      *)
         POS_ARGS="${POS_ARGS}${1:+ }${1}"
      ;;
   esac

   [ ${doshift} -eq 0 ] || shift ${doshift} || die
done
unset -v doshift


case "${SCRIPT_MODE}" in
   'pack')
      PACK_TARGETS="${PACK_TARGETS-}${POS_ARGS:+ }${POS_ARGS}"
      : ${PACK_TARGETS:="${DEFAULT_PACK_TARGETS}"}
      liram_manage_pack_main
   ;;
   'update-core'|'kernup'|'fixup')
      die "script mode '${SCRIPT_MODE}' is not implemented."
   ;;
   *)
      die "unknown script mode ${SCRIPT_MODE}."
   ;;
esac
