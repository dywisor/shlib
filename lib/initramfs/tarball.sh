# @private int initramfs__unpack_tarball ( file, dest )
#
#  Unpacks a tarball into dest. Does not apply any prefixes etc.
#
#  Returns tar's return value.
#
initramfs__unpack_tarball() {
   if ! dodir_minimal "${2}"; then
      return 200
   elif is_busybox_command tar; then
      # Note: last time I've checked busybox' tar, it did not support lzo
      #       archives - using do_uncompress() for all files as workaround
      #
      # Another note: busybox' tar does not support the '-p' switch at runtime
      #
      if compress_supports "${1}"; then
         do_uncompress "${1}" | ${BUSYBOX} tar x -f - -C "${2}"
      else
         ${BUSYBOX} tar x -f "${1}" -C "${2}"
      fi
   else
      tar x -a -p -f "${1}" -C "${2}"
   fi
}

# int initramfs_unpack_tarball ( file, dest )
#
#  Unpacks a tarball into dest. Does not apply any prefixes etc.
## Calls initramfs__unpack_tarball().
#
#  Returns tar's return value.
#
#
initramfs_unpack_tarball() {
   : ${1:?} ${2:?}
   inonfatal initramfs__unpack_tarball "${1}" "${2%/}/"
}
