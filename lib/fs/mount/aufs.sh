## EXPERIMENTAL, needs testing

: ${AUFS_TMPFS_OPTS=mode=0775,dev,exec,suid}

# void __aufs_branchline ( perm, *branches )
#
#  Prepares a <branch 1>=<perm>:<branch 2>=<perm>:... string and
#  stores it in __AUFS_BRANCHES.
#
__aufs_branchline() {
   local perm="${1:?}"
   __AUFS_BRANCHES=

   while shift && [ $# -gt 0 ]; do
      [ -z "${1}" ] || __AUFS_BRANCHES="${__AUFS_BRANCHES}:${1}=${perm}"
   done
   __AUFS_BRANCHES="${__AUFS_BRANCHES#:}"
}

# void __aufs_check_support(), raises die()
#
#  Dies if aufs is not supported by the kernel, else does nothing.
#
__aufs_check_support() {
   fstype_supported aufs || die "kernel does not support the aufs filesystem"
}

# int aufs_tmpfs_backed (
#    aufs_mountpoint,
#    tmpfs_mountpoint,
#    tmpfs_size,
#    realreadonly_branches=,
#    readonly_branches=,
#    aufs_name=<auto>,
#    aufs_opts=
# )
#
#  Mounts a tmpfs-backed aufs at aufs_mountpoint after creating a tmpfs of
#  tmpfs_size size (if set to a non-zero value, else assumes that the tmpfs
#  is already mounted). The tmpfs size will be 'm' unless otherwise specified.
#
#  Attaches the realreadonly and readonly branches to the aufs mountpoint.
#  At least one (real)readonly branch must be given, else you should
#  use a tmpfs directly.
#
aufs_tmpfs_backed() {
   __aufs_check_support

   local aufs_mp="${1:?}" tmpfs_mp="${2:?}" tmpfs_size="${3?}" \
      branches_rr="${4-}" branches_ro="${5-}" \
      aufs_name="${6-}" aufs_opts="${7-}"

   # have any ro/rr branch?
   if [ -z "${branches_rr}${branches_ro}" ]; then
      function_die "no branches specified"
   fi

   # set tmpfs_size
   if [ -n "${tmpfs_size}" ] && [ -z "${tmpfs_size##*[0-9]}" ]; then
      tmpfs_size="${tmpfs_size}m"
   fi

   # set name if empty
   if [ -z "${aufs_name}" ]; then
      aufs_name="${tmpfs_mp##*/}"
      [ -n "${aufs_name}" ] || aufs_name="rootfs"
   fi

   # get all branches
   local __AUFS_BRANCHES branches="${tmpfs_mp}=rw"

   if [ -n "${branches_ro}" ]; then
      __aufs_branchline ro ${branches_ro}
      branches="${branches}:${__AUFS_BRANCHES}"
   fi

   if [ -n "${branches_rr}" ]; then
      __aufs_branchline rr ${branches_rr}
      branches="${branches}:${__AUFS_BRANCHES}"
   fi

   # mount the tmpfs
   if [ -n "${tmpfs_size}" ]; then
      domount_fs "${tmpfs_mp}" "${aufs_name}_mem" \
         "${AUFS_TMPFS_OPTS?},size=${tmpfs_size}" "tmpfs" || return
   else
      dodir_clean "${tmpfs_mp}" || return
   fi

   # mount the aufs
   domount_fs "${aufs_mp}" "${aufs_name}" \
      "br:${branches},nowarn_perm${aufs_opts:+,}${aufs_opts}" "aufs"
}
