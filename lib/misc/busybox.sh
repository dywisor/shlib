: ${BUSYBOX:=/bin/busybox}

# int busybox_overlay ( overlay_dir, **BUSYBOX )
#
#  Installs all busybox applets into overlay_dir if BUSYBOX exists.
#
busybox_overlay() {
   if [ -x "${BUSYBOX}" ] && [ ! -f "${1?}" ]; then
      [ -d "${1}" ] || ${BUSYBOX} mkdir "${1}" || return
      ${BUSYBOX} --install -s "${1}" || return
   else
      return 0
   fi
}

# int is_busybox_command ( command )
#
#  Returns 0 if command (either a name, e.g. "ls" or a path, e.g. "/bin/ls")
#  is a symlink to busybox, else a non-zero value will be returned.
#
is_busybox_command() {
   case "${1-}" in
      '')
         return 2
      ;;
      /*)
         if [ -h "${1}" ]; then
            local link_target=`readlink -f "${1}"`
            [ "${link_target}" = "${BUSYBOX}" ] || return 1

         elif [ "${1}" != "${BUSYBOX}" ]; then
            return 1
         fi
      ;;
      *)
         # resolve by recursion
         is_busybox_command "$(which ${1})" || return
      ;;
   esac
   return 0
}
