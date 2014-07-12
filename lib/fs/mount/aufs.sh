#@section header
## EXPERIMENTAL, needs testing

#@section vars
: ${AUFS_TMPFS_OPTS=mode=0775,dev,exec,suid}


#@section functions

# @private void aufs__branchline ( perm, *branches, **__AUFS_BRANCHES! )
#
#  Prepares a <branch 1>=<perm>:<branch 2>=<perm>:... string and
#  stores it in __AUFS_BRANCHES.
#
aufs__branchline() {
   local perm="${1:?}"
   __AUFS_BRANCHES=

   while shift && [ $# -gt 0 ]; do
      [ -z "${1}" ] || __AUFS_BRANCHES="${__AUFS_BRANCHES}:${1}=${perm}"
   done
   __AUFS_BRANCHES="${__AUFS_BRANCHES#:}"
}

# @DEPRECATED @function_alias __aufs_branchline() renames aufs__branchline()
#
__aufs_branchline() { aufs__branchline "${@}"; }


# int aufs_check_support()
#
#  Returns 0 if aufs is supported by the kernel, else return 1.
#
aufs_check_support() {
   fstype_supported aufs
}

# void aufs_require_support(), raises die()
#
#  Dies if aufs is not supported by the kernel, else does nothing.
#
aufs_require_support() {
   ## aufs-fs ...
   aufs_check_support || die "kernel does not support the aufs filesystem"
}

# @DEPRECATED @function_alias __aufs_check_support()
#  renames aufs_require_support()
#
__aufs_check_support() { aufs_require_support "${@}"; }

# @private aufs__get_branches_opt (
#    writable_branches=,
#    realreadonly_branches=,
#    readonly_branches=,
#    **v0!
# )
#
aufs__get_branches_opt() {
   v0=
   local __AUFS_BRANCHES=

   # BROKEN: __AUFS_BRANCHES gets reset in aufs__branchline
   function_die "broken implementation" "aufs__get_branches_opt"
   [ -z "${1-}" ] || aufs__branchline rw ${1}
   [ -z "${2-}" ] || aufs__branchline rr ${2}
   [ -z "${3-}" ] || aufs__branchline ro ${3}

   [ -n "${__AUFS_BRANCHES}" ] || return 1
   v0="br:${__AUFS_BRANCHES}"
}

# @private aufs__get_mount_opts (
#    writable_branches=,
#    realreadonly_branches=,
#    readonly_branches=,
#    extra_aufs_opts=,
#    **AUFS_DEFAULT_OPTS="nowarn_perm",
#    **v0!
# )
#
aufs__get_mount_opts() {
   v0=
   aufs__get_branches_opt "${1-}" "${2-}" "${3-}" || return 1

   # could merge AUFS_DEFAULT_OPTS branches, but more readable this way
   if [ -z "${AUFS_DEFAULT_OPTS+SET}" ]; then
      v0="${v0},nowarn_perm"

   elif [ -n "${AUFS_DEFAULT_OPTS-}" ]; then
      v0="${v0},${AUFS_DEFAULT_OPTS}"

   fi

   [ -z "${4-}" ] || v0="${v0},${4}"
}



# @private int aufs__domount (
#    aufs_mountpoint,
#    mount_opts,
#    aufs_name="aufs",
# )
#
#  Shorthand for domount_fs (
#     %aufs_mountpoint, %aufs_name, %mount_opts, "aufs"
#  ).
#
aufs__domount() {
   domount_fs "${1:?}" "${3:-aufs}" "${2:?}" "aufs"
}

# int aufs_union (
#    [1] aufs_mountpoint,
#    [2] writable_branches=,
#    [3] realreadonly_branches=,
#    [4] readonly_branches=,
#    [5] aufs_name="aufs",
#    [6] aufs_opts=,
#    **AUFS_DEFAULT_OPTS=<default>,
# )
#
#  aufs-mount.
#
aufs_union() {
   aufs_require_support

   local v0

   aufs__get_mount_opts "${2-}" "${3-}" "${4-}" "${6-}" && \
   aufs__domount "${1:?}" "${v0:?}" "${5:-aufs}"
}



# int aufs_tmpfs_backed (
#    [1] aufs_mountpoint,
#    [2] tmpfs_mountpoint,
#    [3] tmpfs_size,
#    [4] realreadonly_branches=,
#    [5] readonly_branches=,
#    [6] aufs_name=<auto>,
#    [7] aufs_opts=
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
   aufs_require_support

   local v0 mnt_opts
   local aufs_mp tmpfs_mp tmpfs_size branches_rr branches_ro aufs_name aufs_opts

   aufs_mp="${1:?}"
   tmpfs_mp="${2:?}"
   tmpfs_size="${3?}"; tmpfs_size="${tmpfs_size#_}"
   branches_rr="${4-}"
   branches_ro="${5-}"
   aufs_name="${6-}"
   aufs_opts="${7-}"

   # have any ro/rr branch?
   if [ -z "${branches_rr}${branches_ro}" ]; then
      function_die "no branches specified."
   fi

   # set tmpfs_size
   if [ -n "${tmpfs_size}" ] && [ -z "${tmpfs_size##*[0-9]}" ]; then
      tmpfs_size="${tmpfs_size}m"
   fi

   # set name if empty
   if [ -z "${aufs_name}" ]; then
      aufs_name="${tmpfs_mp##*/}"

      if [ -z "${aufs_name}" ]; then
         aufs_name="rootfs"
      else
         aufs_name="${aufs_name%% *}"
         : ${aufs_name:=aufs}
      fi
   fi

   # get mount opts
   aufs__get_mount_opts \
      "${tmpfs_mp}" "${branches_rr}" "${branches_ro}" \
      "${aufs_opts}" || return
   mnt_opts="${v0:?}"


   # mount the tmpfs
   if [ -n "${tmpfs_size}" ]; then
      domount_fs "${tmpfs_mp}" "${aufs_name}_mem" \
         "${AUFS_TMPFS_OPTS?},size=${tmpfs_size}" "tmpfs" || return
   else
      dodir_clean "${tmpfs_mp}" || return
   fi

   # mount the aufs
   aufs__domount "${aufs_mp}" "${mnt_opts}" "${aufs_name}"
}
