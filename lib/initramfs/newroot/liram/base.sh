#@section const
# be extra careful:
#  LIRAM_DISK_MNT_DIR is the directory where the liram disk will be mounted.
#  It should not be confused with the %LIRAM_DISK_MP variable, which
#  contains the _current_ mountpoint of the liram disk and is empty if the
#  disk is not mounted.
#
#  IOW, never reference this var unless 100% sure.
#
#  This variable is a constant since there's no reason why it should be
#  modified at runtime.
#
readonly LIRAM_DISK_MNT_DIR="/mnt/liram_sysdisk"


#@section functions

# @noreturn liram_die(...) wraps initramfs_die(...)
#
#  Unmounts LIRAM_DISK_MP if mounted and calls initramfs_die() afterwards.
#
liram_die() {
   # avoid (infinite) recursion
   local F_INITRAMFS_DIE=
   liram_unmount_sysdisk

   initramfs_die "$@"
}

# @noreturn liram_populate_die (
#    ...,
#    **LIRAM_POPULATE_FUNCTION,
# )
#
#  Wraps liram_die (...).
#
#  It's not mandatory to call this function, the output will be nicer
#  (more informative when not using bash), though.
#
liram_populate_die() {
   if [ -n "${1-}" ]; then
      liram_die "while executing function ${LIRAM_POPULATE_FUNCTION-}: ${1}" "${2-}"
   else
      liram_die "while executing function ${LIRAM_POPULATE_FUNCTION-}." "${2-}"
   fi
}

# @private void liram__init_vars (
#    **LIRAM_DISK!, **LIRAM_DISK_FSTYPE!, **LIRAM_NEED_NET_SETUP!
# )
#
liram__init_vars() {
   case "${LIRAM_DISK}" in
      'nfs='*)
         LIRAM_DISK_FSTYPE="nfs"
         LIRAM_DISK="${LIRAM_DISK#nfs=}"
         LIRAM_NEED_NET_SETUP=y
      ;;
      *)
         : ${LIRAM_DISK_FSTYPE:=auto}
         : ${LIRAM_NEED_NET_SETUP:=n}
      ;;
   esac
}

# void liram_mount_sysdisk ( **LIRAM_DISK, **LIRAM_DISK_FSTYPE=auto )
#
#  Mounts the liram sysdisk.
#
liram_mount_sysdisk() {
   case "${LIRAM_DISK_FSTYPE:-auto}" in
      'nfs')
         initramfs_mount_nfs "${LIRAM_DISK_MNT_DIR?}" "${LIRAM_DISK}"
      ;;
      *)
         imount_disk \
            "${LIRAM_DISK_MNT_DIR?}" "${LIRAM_DISK:?}" \
            "ro" "${LIRAM_DISK_FSTYPE:-auto}"
      ;;
   esac || return ${?}

   LIRAM_DISK_MP="${LIRAM_DISK_MNT_DIR}"
   F_INITRAMFS_DIE=liram_die
}

# void liram_unmount_sysdisk ( **LIRAM_DISK_MP )
#
#  Unmounts the liram sysdisk.
#
liram_unmount_sysdisk() {
   if [ -n "${LIRAM_DISK_MP-}" ]; then
      sync
      iumount "${LIRAM_DISK_MP}" && F_INITRAMFS_DIE="" && LIRAM_DISK_MP=""
   fi
   return 0
}

# @function_alias liram_umount_sydisk() renames liram_unmount_sysdisk()
liram_umount_sysdisk() { liram_unmount_sysdisk "$@"; }

# void liram_mount_rootfs (
#    **NEWROOT, **LIRAMFS_NAME=liramfs, **LIRAM_ROOTFS_SIZE
# )
#
#  Mounts NEWROOT as tmpfs.
#
liram_mount_rootfs() {
   imount_fs \
      "${NEWROOT:?}" "${LIRAMFS_NAME=liramfs}" \
      "mode=0755,size=${LIRAM_ROOTFS_SIZE:?}m" "tmpfs"
}

# int liram_getslot (
#    **LIRAM_DISK_MP, **LIRAM_SLOT, **LIRAM_VIRTUAL_SLOT=n, **SLOT!
# )
#
#  Sets the %SLOT variable and verifies that it exists (as directory).
#
#  Returns 0 if %SLOT exists.
#
#  Calls initramfs_die() if the liram sysdisk is not mounted.
#  Returns 1 if the slot does not exist and LIRAM_VIRTUAL_SLOT is set to 'y',
#  else calls liram_die().
#
liram_getslot() {
   SLOT=
   if [ -n "${LIRAM_DISK_MP-}" ]; then
      SLOT="${LIRAM_DISK_MP%/}/${LIRAM_SLOT#/}"
      if [ -d "${SLOT}" ]; then
         return 0
      elif [ "${LIRAM_VIRTUAL_SLOT:-n}" = "y" ]; then
         return 1
      else
         liram_die "liram sysdisk slot directory '${SLOT}' does not exist."
      fi
   else
      initramfs_die "liram sysdisk not mounted."
   fi
}

# @private int liram_populate__inherit (
#    liram_layout,
#    **SLOT, **SFS_CONTAINER, **TARBALL_SCAN_DIR, **SFS_SCAN_DIR,
#    **LIRAM_UNPACK_NAME_TRY
# ), raises liram_die()
#
#  Populates newroot by calling liram_populate_layout_<LIRAM_LAYOUT>().
#  Raises liram_die() if the layout is not implemented.
#  Passes the return value of the actual populate() function.
#
#  This function should only be called by liram_populate() and
#  liram_populate_layout_*() functions.
#  !!! Never call a liram_populate_layout_<LAYOUT>() function directly.
#
liram_populate__inherit() {
   local LIRAM_LAYOUT_ACTIVE="${1:?}"
   local LIRAM_POPULATE_FUNCTION=liram_populate_layout_${LIRAM_LAYOUT_ACTIVE}

   if function_defined "${LIRAM_POPULATE_FUNCTION}"; then
      local FILESIZE v0
      local rc=0

      # bind populate-specific die() function
      local F_INITRAMFS_DIE=liram_populate_die
      inonfatal "${LIRAM_POPULATE_FUNCTION}" || rc=${?}

      # Always sync after populating newroot, whether successful or not
      # liram_unmount_sysdisk() will sync again, but dont depend on that.
      sync

      return ${rc}
   else
      liram_die "cannot populate NEWROOT using the '${1:?}' layout."
   fi
}

# int liram_populate_inherit(...)
#  WRAPS liram_populate__inherit(...)
#
#  Wraps liram_populate__inherit() with irun().
#  This is what layouts should call in order to inherit other layouts.
#
liram_populate_inherit() { irun liram_populate__inherit "$@"; }

# int liram_populate_helper ( helper_name, *argv, **LIRAM_LAYOUT_ACTIVE )
#
#  Calls a helper function.
#  Should only be called by populate_layout functions.
#
liram_populate_helper() {
   if [ $# -eq 1 ]; then
      irun liram_layout_${LIRAM_LAYOUT_ACTIVE:?}__${1:?}
   else
      local HELPER_NAME="${1:?}"; shift
      irun liram_layout_${LIRAM_LAYOUT_ACTIVE:?}__${HELPER_NAME} "$@"
   fi
}

# int liram_populate ( **LIRAM_LAYOUT=default ), raises liram_die()
#
#  Initializes variables required for populating NEWROOT and calls
#  liram_populate_inherit(<LIRAM_LAYOUT>), which populates NEWROOT.
#
liram_populate() {
   : ${LIRAM_LAYOUT:=default}
   local LIRAM_POPULATE_FUNCTION=liram_populate_layout_${LIRAM_LAYOUT}

   # initialize variables
   local \
      SLOT SFS_CONTAINER TARBALL_SCAN_DIR SFS_SCAN_DIR \
      LIRAM_UNPACK_NAME_TRY="${LIRAM_UNPACK_NAME_TRY:-n}"

   liram_getslot || true

   SFS_SCAN_DIR="${SLOT}"
   TARBALL_SCAN_DIR="${SLOT}"

   liram_populate__inherit "${LIRAM_LAYOUT}"
}

# void liram_init(), raises *die()
#
#  Initializes NEWROOT as tmpfs.
#
#  This includes:
#  * mount NEWROOT
#  * mount the liram sysdisk (readonly)
#  * extract / copy files into NEWROOT, depending on LIRAM_LAYOUT
#  * unmount the liram sysdisk
#
liram_init() {
   irun liram__init_vars
   if [ "${LIRAM_NEED_NET_SETUP:-n}" = "y" ]; then
      irun initramfs_net_setup up
   fi
   irun liram_mount_rootfs
   irun liram_mount_sysdisk
   irun liram_populate
   irun liram_unmount_sysdisk
}
