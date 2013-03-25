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
