#@section functions

# @function_alias int systemd_nspawn_setup_root_dir_from_tarball (
#    root_dir, tmpdir, tarball_fetch_func, tarball_file=, *tar_opts,
#    **CMD_PREFIX=
# )
#  WRAPS system_setup_rootfs_from_tarball()
#
systemd_nspawn_setup_root_dir_from_tarball() {
   local SYSTEM_ROOTFS
   system_setup_rootfs_from_tarball "${@}" || return

   if systemd_nspawn_set_root_dir "${SYSTEM_ROOTFS:?}"; then
      return 0
   else
      local ret=${?}
      eerror \
         "systemd_nspawn_setup_root_dir_from_tarball(): set_root_dir() returned ${?} -- does ${SYSTEM_ROOTFS} exist?"
      return ${ret}
   fi
}
