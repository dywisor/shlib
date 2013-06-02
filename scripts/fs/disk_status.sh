#!/bin/sh

# @funcdef DEV_ACTION <function name> ( dev, **dev, **disk, **sysblock )
#

disk_status_default() {
   local v0
   local INDENT="  "
   local smart
   if get_disk_status "${dev:?}"; then
      einfo "${disk}: ${v0}"
      if [ "${v0}" = "active/idle" ]; then
         smart=$( LANG=C LC_ALL=C smartctl -H "${dev}" | \
            grep ^'SMART overall-health self-assessment test result:' | \
            cut -d : -f 2 | str_trim )

         case "${smart}" in
            'PASSED')
               einfo "  smart status: ${smart}"
            ;;
            '')
               eerror "  smart status: UNKNOWN"
            ;;
            *)
               ewarn "  smart status: ${smart}"
            ;;
         esac
      else
         einfo "  smart status: SKIPPED"
      fi
   elif [ ${UID?} -eq 0 ]; then
      eerror "${disk}: unknown status"
   else
      eerror "${disk}: unknown status (are you root?)"
   fi
}

iter_dev() {
   # action:
   : ${1:?}
   local action="${1:?}"
   local dev
   local disk
   local sysblock

   for dev in /dev/[hs]d*[a-z]; do
      disk="${dev##*/}"
      sysblock="/sys/block/${disk}"
      if [ -d "${sysblock}/" ]; then
         if \
            [ "$(cat ${sysblock}/removable 2>/dev/null)" = "0" ] || \
            case "$(cat ${sysblock}/device/vendor 2>/dev/null)" in
               *[aA][tT][aA]*) true ;;
               *) false ;;
            esac
         then
            ${1} "${dev}" || eerror "action '${action}' failed for disk ${disk}."
         fi
      fi
   done
}

#case "${SCRIPT_NAME}" in
#   *)
#      SCRIPT_MODE="disk_status_default"
#   ;;
#esac
#iter_dev ${SCRIPT_MODE}
iter_dev disk_status_default
