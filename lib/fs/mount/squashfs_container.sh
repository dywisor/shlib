#@section header
# ----------------------------------------------------------------------------
#
# This module provides functions to manage a squashfs file container,
# which is a tmpfs of dynamic size that stores squashfs files and
# is able to mount them later on.
#
# Managing "normal" directories as container is possible, too.
# See sfs_container_init() for details.
#
# Only one container can accessible at any time, but switching between them
# is possible via sfs_container_init() provided you have enough information
# about the other container (e.g. its mountpoint).
#
#
# Functions provided by this module (quickref):
#
# int  sfs_container_avail()
# int  sfs_container_downsize()
# int  sfs_container_finalize()
# int  sfs_container_import()        -- sfs_file, sfs_name
# int  sfs_container_remove()        -- sfs_name
# void sfs_container_init()          -- mp, size_m
# int  sfs_container_lock()
# int  sfs_container_mount()         -- sfs_name, mp
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
# sfs_container_import ${FILES}/usr.sfs  usr
# sfs_container_import ${FILES}/home.sfs home
#
# # lock the container and reduce its size
# sfs_container_finalize
#
# # mount the imported files
# sfs_container_mount usr  ${NEWROOT}/usr
# sfs_container_mount home ${NEWROOT}/home
#
# Note:
#   The initramfs/newroot/squashfs_container provides handy wrapper functions
#   which make the example code above obsolete.
#   See gentoo/squashed_portage for a "real world" example.
#
#
# Also see the squashfs_container_aufs module which extends this module by
# providing tmpfs-writable squashfs mounts.
#
# ----------------------------------------------------------------------------


#@section functions

# @private int sfs_container__resize ( new_size_m )
#
#  Resizes the (current) sfs container.
#
sfs_container__resize() {
   sfs_container__isdir || \
   tmpfs_resize_m "${SFS_CONTAINER}" "${1:?}" && SFS_CONTAINER_SIZE="${1}"
}

# @private int sfs_container__isdir ( **SFS_CONTAINER_SIZE )
#
#  Returns 0 if the current container is a normal directory and not a tmpfs.
#
sfs_container__isdir() {
   ## size < 0 means "is dir"
   [ ${SFS_CONTAINER_SIZE?} -lt 0 ]
}

# int sfs_container_avail ( lenient=y, **SFS_CONTAINER )
#
#  Returns 0 if SFS_CONTAINER exists (as directory), else 1.
#  Also checks whether "anything" is mounted at SFS_CONTAINER if the first
#  arg is not 'y'.
#
sfs_container_avail() {
   [ -n "${SFS_CONTAINER-}" ] && [ -d "${SFS_CONTAINER}" ] || return 1
   [ "${1:-y}" = "y" ] || \
      sfs_container__isdir || is_mounted "${SFS_CONTAINER}"
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
#  Passing a negative size_m results in not mounting any tmpfs, the
#  container will be a normal directory.
#
#  Returns 0 on success, else != 0.
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

   if sfs_container__isdir; then
      # just a normal directory, create it if it does not exist

      dodir_clean "${SFS_CONTAINER}"

   elif sfs_container_avail "n"; then
      # lazy init

      if [ ${SFS_CONTAINER_SIZE} -eq 0 ]; then
         local FILESIZE
         get_filesize "${SFS_CONTAINER}" || return
         SFS_CONTAINER_SIZE="${FILESIZE}"
      fi

   else
      # init tmpfs container

      local mount_size=$(( ${SFS_CONTAINER_SIZE} + ${SFS_CONTAINER_SPARE_SIZE} ))

      dotmpfs \
         "${SFS_CONTAINER}" "${SFS_CONTAINER_NAME}" \
         "${SFS_CONTAINER_MOUNT_OPTS},size=${mount_size}m" && \
      SFS_CONTAINER_SIZE="${mount_size}"
   fi
}

# int sfs_container_import (
#    sfs_file, sfs_name, size_increase_m=-1, remove_existing=n,
#    **SFS_CONTAINER, **SFS_CONTAINER_SIZE,
#    **F_SFS_CONTAINER_COPYFILE=<default>
# )
#
#  Imports a squashfs file into the current container.
#  Increases the container's size by size_increase_m if set to a value greater
#  than zero. A value less than zero means that the container will be
#  increased by the sfs_file's size.
#
#  File transfer is actually handled by calling
#   F_SFS_CONTAINER_COPYFILE ( sfs_src_file, sfs_dest_file )
#  if set, else an internal implementation ("cp -L") will be used.
#
#  (Strings will be interpreted as < 0)
#
#
sfs_container_import() {
   sfs_container_avail || return
   set -- "${1:?}" "${2:?}" "${3:--1}" "${4:-n}"
   local sfs_dest="${SFS_CONTAINER}/${2#/}.sfs"

   # basic checks / delete old file + tmpfs resize

   [ -f "${1}" ] || return 40

   if [ -e "${sfs_dest}" ]; then

      if [ "${4}" = "y" ]; then
         rm -- "${sfs_dest}" || return 38
      else
         return 39
      fi
   fi

   if [ "${3}" -eq 0 2>/dev/null ] || sfs_container__isdir; then

      true

   elif [ "${3}" -gt 0 2>/dev/null ]; then

      sfs_container__resize \
         $(( ${SFS_CONTAINER_SIZE} + ${3} )) || return

   else
      local FILESIZE

      get_filesize "${1}" && \
      sfs_container__resize \
         $(( ${SFS_CONTAINER_SIZE} + ${FILESIZE} )) || return
   fi

   # copy file

   if [ -n "${F_SFS_CONTAINER_COPYFILE-}" ]; then
      # call F_SFS_CONTAINER_COPYFILE and ensure that sfs_dest exists

      ${F_SFS_CONTAINER_COPYFILE} "${1}" "${sfs_dest}" && [ -e "${sfs_dest}" ]

   elif \
      sfs_container__isdir && \
      [ x$(stat -c '%D' "${SFS_CONTAINER}/") = x$(stat -c '%D' "${1}") ]
   then
      # device of $1 is device containing $SFS_CONTAINER
      #  try to hardlink and fall back to copy
      # !!! busybox does not support "ln --logical"
      ln -L -- "${1}" "${sfs_dest}" || cp -L -- "${1}" "${sfs_dest}"
   else
      # default copy
      cp -L -- "${1}" "${sfs_dest}"
   fi
}

# int sfs_container_remove ( sfs_name, **SFS_CONTAINER )
#
#  Removes a squashfs file from the container.
#
#  Returns 0 if a file has been removed.
#
#  Note: As of now, only the file will be removed.
#        The container won't be downsized etc.
#
sfs_container_remove() {
   sfs_container_avail || return
   local sfs_dest="${SFS_CONTAINER}/${1#/}.sfs"

   [ -e "${sfs_dest}" ] && rm -- "${sfs_dest}"
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
   sfs_container__isdir || remount_ro "${SFS_CONTAINER}"
}

# int sfs_container_unlock ( **SFS_CONTAINER )
#
#  "Unlocks" the current sfs container by mounting it in read-write mode.
#  See sfs_container_lock().
#
sfs_container_unlock() {
   sfs_container__isdir || remount_rw "${SFS_CONTAINER}"
}

# int sfs_container_mount ( sfs_name, mp, **SFS_CONTAINER )
#
#  Mounts a squashfs file that has been imported into the container earlier.
#
sfs_container_mount() {
   dosquashfs "${SFS_CONTAINER}/${1:?}.sfs" "${2:?}"
}

# int sfs_container_downsize()
#
#  Reduces the size of the current squashfs container
#  to what's actually required.
#
sfs_container_downsize() {
   local v0
   if ! sfs_container_avail; then
      return 1
   elif sfs_container__isdir; then
      return 0
   else
      tmpfs_downsize \
         "${SFS_CONTAINER}" "${SFS_CONTAINER_SIZE}" \
         "${SFS_CONTAINER_SPARE_SIZE}" && \
      SFS_CONTAINER_SIZE="${v0:?}"
   fi
}

# int sfs_container_finalize()
#
#  Calls sfs_container_lock() and sfs_container_downsize().
#
sfs_container_finalize() {
   sfs_container_lock && \
   sfs_container_downsize
}
