# void __newroot_premount_fstab (
#    **fs, **mp, **fstype, **opts,
#    **want_mp, **mounted!
#    **NEWROOT_PREMOUNT_FSCK=y
# )
#
#  Helper function for fstab_iterator().
#
#  Mounts NEWROOT/mp and sets mounted to 1 if mp matchs want_mp.
#  Checks the filesystem before mounting it if NEWROOT_PREMOUNT_FSCK is
#  set to y.
#
#  Always returns 0, failure is catched by irun().
#
__newroot_premount_fstab() {
   [ "x${mp}" = "x${want_mp}" ] || return 0

   local v0 newroot_mp
   newroot_doprefix "${mp}"
   newroot_mp="${v0}"

   # busybox doesn't support the defaults/auto/noauto mount options,
   #  the lines below provides partial support for filtering them out
   #
   #  *** partial := each option will be filtered out at most once ***
   #
   local opts="${opts}" opt opts_head opts_tail

   for opt in 'defaults' 'noauto' 'auto'; do
      case "${opts}" in
         "${opt}")
            opts=""
            break
         ;;
         "${opt},"*)
            opts="${opts#${opt},}"
         ;;
         *",${opt}")
            opts="${opts%,${opt}}"
         ;;
         ?*",${opt},"?*)
            # bash could do this with opts="${opts/,${opt},/,}"
            opts_head="${opts%%,${opt},*}"
            opts_tail="${opts#*,${opt},}"

            opts="${opts_head},${opts_tail}"
         ;;
      esac
   done
   # -- end option filter

   case "${fstype}" in
      ## from /proc/filesystems
      ##  (TODO: grep nodev lines from /proc/filesystems at runtime)
      ##
      'sysfs'|\
      'proc'|\
      'cgroup'|\
      'cpuset'|\
      'tmpfs'|\
      'devtmpfs'|\
      'binfmt_misc'|\
      'debugfs'|\
      'devpts')
         imount_fs \
            "${newroot_mp}" "${fs}" "${opts}" "${fstype}" && \
         mounted=1
         return ${?}
      ;;

      'cifs'|'nfs'|'aufs')
         function_die "cifs/nfs/aufs: not implemented (mountpoint=${mp})"
      ;;
   esac

   case "${fs}" in
      /*)
         local fs_file
         # this looks like a file
         newroot_doprefix "${fs}"
         if [ -f "${v0}" ]; then
            fs_file="${v0}"
         else
            function_die "file ${v0} is missing but required for mounting ${mp}"
         fi

         imount_fs \
            "${newroot_mp}" "${fs_file}" "${opts}" "${fstype}" && \
         mounted=1
      ;;
      *)
         imount_disk \
            "${newroot_mp}" "${fs}" "${opts}" "${fstype}" \
            "${NEWROOT_PREMOUNT_FSCK:-y}" && \
         mounted=1
      ;;
   esac
}

# int newroot_premount ( mp )
#
#  Reads the NEWROOT/etc/fstab and mounts the given mountpoint.
#  Returns 0 on success, else 1.
#
newroot_premount() {
   local v0 want_mp="${1:?}" mounted=0
   newroot_doprefix /etc/fstab
   if [ -r "${v0}" ]; then
      # fstab_iterator() must not fail
      F_FSTAB_ITER=__newroot_premount_fstab irun fstab_iterator "${v0}"
   else
      ${LOGGER} -0 --level=WARN "/etc/fstab is missing in ${NEWROOT-}"
   fi
   [ ${mounted-0} -eq 1 ]
}

# void newroot_premount_all (
#    **CMDLINE_PREMOUNT=,
#    **CMDLINE_NO_USR=n,
#    **CMDLINE_FSCK=y
# )
#
#  Mounts all mountpoints listed in CMDLINE_PREMOUNT if set, else
#  tries to mount /usr.
#
newroot_premount_all() {
   local NEWROOT_PREMOUNT_FSCK="${CMDLINE_FSCK:-y}"

   if [ -n "${CMDLINE_PREMOUNT-}" ]; then
      set -- ${CMDLINE_PREMOUNT}
      while [ $# -gt 0 ]; do
         [ -z "${1-}" ] || irun newroot_premount "${1}"
         shift
      done
   elif [ "${CMDLINE_NO_USR:-n}" != "y" ]; then
      newroot_premount /usr || ${LOGGER} -0 --level=INFO "/usr is not separate"
   fi
   return 0
}
