readonly CONFIG_FILE=/etc/conf.d/squashed_portage

readonly HELP_USAGE="Usage: ${SCRIPT_NAME} [--no-config] <mode> [<name> [<mountpoint> [<size>]]]
where <mode> is start|stop|save|testsave|printenv|--help|@<function>"

# @noreturn die_usage ( code=, msg= ), raises exit()
#
die_usage() {
   if [ "x${1-}" = "x0" ]; then
      echo "${HELP_USAGE?}"
      exit 0
   else
      [ -z "${2-}" ] || eerror "${2}"
      die "${HELP_USAGE:?}" "${1-}"
   fi
}

# void need_tree ( **HAVE_TREE ), raises die_usage()
#
need_tree() {
   [ "${HAVE_TREE:?}" = "y" ] || die_usage 12 "name or mountpoint missing"
}

# int portage_sfs_generic_action ( subfunc, **... )
#
portage_sfs_generic_action() {
   local func_name="${1#portage_sfs_}" func
   func="portage_sfs_${func_name}"

   if [ "${func_name#_}" != "${func_name}" ]; then
      die_usage 65 "cannot call private function ${func}()"

   elif [ -n "${BASH_VERSION-}" ] && [ "${FUNCNAME}" = "${func}" ]; then
      die_usage 67 "infinite recursion detected (${FUNCNAME})"

   elif [ "${func}" = "portage_sfs_generic_action" ]; then
      # it's still possible to export a function that leads to inf rec
      die_usage 68 "possible infinitite recursion detected (${func})"

   elif function_defined "${func}"; then
      ${func} "${PORTAGE_NAME?}" "${PORTAGE_MP?}" "${PORTAGE_SFS_MEM_SIZE-}"

   else
      die_usage 66 "no such function: ${func}"
   fi
}

# read main config
if [ "x${1-}" = "x--no-config" ]; then
   readonly NO_CONFIG=y
   shift
else
   readonly NO_CONFIG=n
   readconfig "${CONFIG_FILE}"
fi

: ${PORTAGE_NAME=} ${PORTAGE_MP=}
mode="${1-}"
[ -z "${2-}" ] || PORTAGE_NAME="${2}"

# read %PORTAGE_NAME specific config file (if it exists)
if \
   [ "${NO_CONFIG}" != "y" ] && \
   [ -n "${PORTAGE_NAME}" ] && [ -e "${CONFIG_FILE}.${PORTAGE_NAME}" ]
then
#   readonly MY__PORTAGE_NAME="${PORTAGE_NAME}"
   readconfig "${CONFIG_FILE}.${PORTAGE_NAME}"
#   if [ "x${MY__PORTAGE_NAME}" != "x${PORTAGE_NAME}" ]; then
#      ewarn "PORTAGE_NAME has been modified while reading ${CONFIG_FILE}.${PORTAGE_NAME}."
#   fi
fi

[ -z "${3-}" ] || PORTAGE_MP="${3}"
[ -z "${4-}" ] || PORTAGE_SFS_MEM_SIZE="${4}"

# set PORTAGE_MP if unset
#  /usr/portage if PORTAGE_NAME is gentoo
#  /var/portage/tree/<PORTAGE_NAME> otherwise
#
if [ -n "${PORTAGE_NAME}" ]; then
   if [ -z "${PORTAGE_MP}" ]; then
      case "${PORTAGE_NAME}" in
         'gentoo')
            PORTAGE_MP="/usr/portage"
         ;;
         *)
            PORTAGE_MP="/var/portage/tree/${PORTAGE_NAME}"
         ;;
      esac
   fi

   HAVE_TREE=y
else
   HAVE_TREE=n
fi

# determine actual mode (unalias %mode)
#
case "${mode}" in
   '+'|'load'|'reload'|'start'|'restart')
      mode="reload_tree"
   ;;
   '-'|'stop')
      mode="eject"
   ;;
   'testsave')
      mode="test_save"
   ;;
   'p')
      mode="printenv"
   ;;
esac

# run requested mode
case "${mode}" in
   '')
      die_usage 64
   ;;
   '-h'|'--help')
      die_usage 0
   ;;
   @?*)
      # call portage_sfs_* subfunction directly
      [ "${HAVE_TREE?}" != "y" ] || portage_sfs_generic_action reset
      portage_sfs_generic_action "${mode#@}"
   ;;
   'reload_tree')
      need_tree
      portage_sfs_generic_action "reload_tree"
   ;;
   'save'|'test_save'|'eject'|'save_today')
      need_tree
      portage_sfs_generic_action reset
      portage_sfs_"${mode}"
   ;;
   'printenv')
      [ "${HAVE_TREE?}" != "y" ] || portage_sfs_generic_action reset
      portage_sfs_printenv
   ;;
   *)
      die_usage 64 "unknown mode '${mode}'"
   ;;
esac
