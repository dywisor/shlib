# ----------------------------------------------------------------------------
#
# This module provides functions to manage a squashfs file container,
# which is a tmpfs of dynamic size that stores squashfs files and
# is able to mount them later on.
#
# Only one container can accessible at any time, but switching between them
# is possible via sfs_container_init() provided you have enough information
# about the other container (e.g. its mountpoint).
#
#
# This module can be considered generic (i.e. not newroot-specific),
# with the exception of:
#
# * sfs_container_mount ( sfs_name, <<mp>> )
# * sfs_container_init  ( <<mp>>, ... )
#
# which is why these functions also exist as newroot_* function.
#
#
# Functions provided by this module (quickref):
#
# void newroot_sfs_container_init()  -- mp, size_m; raises initramfs_die()
# int  newroot_sfs_container_mount() -- name, mp
# int  sfs_container_avail()
# int  sfs_container_downsize()
# int  sfs_container_finalize()
# int  sfs_container_import()        -- sfs_file, sfs_name
# void sfs_container_init()          -- mp, size_m; raises initramfs_die()
# int  sfs_container_lock()
# int  sfs_container_mount()         -- name, mp
# int  sfs_container_unlock()
#
#
# Example code using this module:
#
# # initialize the container with an initial size of 50 MiB
# sfs_container_init "${NEWROOT}/SFS/default"
#
# # copy files and assign names to them,
# #  the container will increase its size automatically
# irun sfs_container_import ${FILES}/usr.sfs  usr
# irun sfs_container_import ${FILES}/home.sfs home
#
# # lock the container and reduce its size
# irun sfs_container_finalize
#
# # mount the imported files
# irun sfs_container_mount usr  ${NEWROOT}/usr
# irun sfs_container_mount home ${NEWROOT}/home
#
#
# Also see the squashfs_container_aufs module which extends this module by
# providing tmpfs-writable squashfs mounts.
#
# ----------------------------------------------------------------------------

# int newroot_sfs_container_mount ( sfs_name, mp, **SFS_CONTAINER )
#
#  Prefixes mp with %NEWROOT and calls
#  sfs_container_mount ( sfs_name, newroot_mp ).
#
newroot_sfs_container_mount() {
   local v0
   newroot_doprefix "${2:?}"
   sfs_container_mount "${1}" "${v0}"
}

# void newroot_sfs_container_init ( mp, ... )
#
#  Prefixes mp with $NEWROOT and calls
#  sfs_container_init ( newroot_mp, ... ) afterwards.
#
newroot_sfs_container_init() {
   local v0
   newroot_doprefix "${1:?}"
   shift
   sfs_container_init "${v0}" "$@"
}


# @private int sfs_container__init_new()
#
#  Initializes a new squashfs container (mounts the tmpfs).
#
sfs_container__init_new() {
   local mount_size=$(( ${SFS_CONTAINER_SIZE} + ${SFS_CONTAINER_SPARE_SIZE} ))

   inonfatal dotmpfs \
      "${SFS_CONTAINER}" "${SFS_CONTAINER_NAME}" \
      "${SFS_CONTAINER_MOUNT_OPTS},size=${mount_size}m" && \
   SFS_CONTAINER_SIZE="${mount_size}"
}

# @private int sfs_container__init_lazy()
#
#  Intitializes a sfs container that already exists.
#
sfs_container__init_lazy() {
   if [ ${SFS_CONTAINER_SIZE} -le 0 ]; then
      local FILESIZE
      inonfatal get_filesize "${SFS_CONTAINER}" || return
      SFS_CONTAINER_SIZE="${FILESIZE}"
   fi
}

# @private int sfs_container__resize ( new_size_m )
#
#  Resizes the (current) sfs container.
#
sfs_container__resize() {
   inonfatal tmpfs_resize_m "${SFS_CONTAINER}" "${1:?}" && \
      SFS_CONTAINER_SIZE="${1}"
}

# int sfs_container_avail ( lenient=y, **SFS_CONTAINER )
#
#  Returns 0 if SFS_CONTAINER exists (as directory), else 1.
#  Also tries whether "anything" is mounted at SFS_CONTAINER if the first
#  arg is not 'y'.
#
sfs_container_avail() {
   [ -n "${SFS_CONTAINER-}" ] && [ -d "${SFS_CONTAINER}" ] || return 1
   [ "${1:-y}" = "y" ] || is_mounted "${SFS_CONTAINER}"
}

# void sfs_container_init (
#    mp, name="sfs_container", size_m=0, spare_size=50, mount_opts="mode=0711",
#    **SFS_CONTAINER!, **SFS_CONTAINER_NAME!, **SFS_CONTAINER_SIZE!,
#    **SFS_CONTAINER_SPARE_SIZE!, **SFS_CONTAINER_MOUNT_OPTS!
# ), raises die()
#
#  Initializes a squashfs container at the given position, either a new
#  one or one that already exists.
#
#  Always returns 0. Dies on failure.
#
sfs_container_init() {
## "close" previous container?
##   if [ -n "${SFS_CONTAINER-}" ]; then
##      true
##   fi

   SFS_CONTAINER="${1:?}"
   SFS_CONTAINER_NAME="${2:-sfs_container}"
   SFS_CONTAINER_SIZE="${3:-0}"
   SFS_CONTAINER_SPARE_SIZE="${4:-50}"
   SFS_CONTAINER_MOUNT_OPTS="${5:-mode=0711}"

   if sfs_container_avail "n"; then
      irun sfs_container__init_lazy
   else
      irun sfs_container__init_new
   fi
}

# int sfs_container_import ( sfs_file, sfs_name, size_increase_m=-1, **SFS_CONTAINER )
#
#  Imports a squashfs file into the current container.
#  Increases the container's size by size_increase_m if set to a value greater
#  than zero. A value less than zero means that the container will be
#  increased by the sfs_file's size.
#
#  (Strings will be interpreted as < 0)
#
sfs_container_import() {
   sfs_container_avail || return
   set -- "${1:?}" "${2:?}" "${3:--1}"
   local sfs_dest="${SFS_CONTAINER}/${2#/}.sfs"

   # basic checks + tmpfs resize
   if [ ! -f "${1}" ]; then

      return 40

   elif [ -e "${sfs_dest}" ]; then

      return 39

   elif [ "${3}" -eq 0 2>/dev/null ]; then

      true

   elif [ "${3}" -gt 0 2>/dev/null ]; then

      sfs_container__resize $(( ${SFS_CONTAINER_SIZE} + ${3} )) || return

   else
      local FILESIZE

      inonfatal get_filesize "${1}" && \
      sfs_container__resize $(( ${SFS_CONTAINER_SIZE} + ${FILESIZE} )) || return
   fi

   # copy
   if initramfs_copy_file "${1}" "${sfs_dest}"; then
      inonfatal chmod 0400 "${sfs_dest}"
      inonfatal chown 0:0 "${sfs_dest}"
      return 0
   else
      return ${?}
   fi
}

# int sfs_container_lock ( **SFS_CONTAINER )
#
#  "Locks" the current sfs container. Syncs and remounts the container
#  readonly afterwards.
#
#  !!! You have to call this function before mounting any sfs file,
#      else remounting will fail.
#
sfs_container_lock() {
   sync
   inonfatal remount_ro "${SFS_CONTAINER}"
}

# int sfs_container_unlock ( **SFS_CONTAINER )
#
#  "Unlocks" the current sfs container by mounting it in read-write mode.
#  See sfs_container_lock().
#
sfs_container_unlock() {
   inonfatal remount_rw "${SFS_CONTAINER}"
}

# int sfs_container_mount ( sfs_name, mp, **SFS_CONTAINER )
#
#  Mounts a squashfs file that has been imported into the container earlier.
#
sfs_container_mount() {
   inonfatal dosquashfs "${SFS_CONTAINER}/${1:?}.sfs" "${2:?}"
}

# int sfs_container_downsize()
#
#  Reduces the size of the current squashfs container
#  to what's actually required.
#
sfs_container_downsize() {
   local v0
   sfs_container_avail && \
   inonfatal tmpfs_downsize \
      "${SFS_CONTAINER}" "${SFS_CONTAINER_SIZE}" \
      "${SFS_CONTAINER_SPARE_SIZE}" && \
   SFS_CONTAINER_SIZE="${v0:?}"
}

# int sfs_container_finalize()
#
#  Calls sfs_container_lock() and sfs_container_downsize().
#
sfs_container_finalize() {
   inonfatal sfs_container_lock && \
   inonfatal sfs_container_downsize
}
