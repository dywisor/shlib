#@section functions

# int portage_sfs_reload_tree ( portage_tree_name, portage_tree_mp, ... )
#
#  Does whatever necessary to get a writable variant of a squashfs file
#  referenced by %portage_tree_name mounted at %portage_tree_mp, that is:
#
#  * initializes all vars and the squashfs container
#  * unmounts any previous mount
#  * imports the squashfs file
#  * mounts the writable tree at %portage_tree_mp
#
#  Consider this as your "main" function for mounting portage trees.
#  The downside is that the return value is less accurate.
#
#  Calling this function more than once (with different name and mountpoint
#  parameters) is supported.
#
portage_sfs_reload_tree() {
   portage_sfs_init "$@" && \
   portage_sfs_eject && \
   portage_sfs_import && \
   portage_sfs_mount
}

# @private void portage_sfs__setvars ( **... ), raises exit()
#
#  Sets all portage_sfs variables that are required for basic usage.
#  Some vars have to be set before running this function,
#  else the script will forcefully exit.
#
#
portage_sfs__setvars() {
   : ${PORTAGE_SFS_AUFS_ROOT:=/aufs/portage}

   : ${PORTAGE_SFS_IMAGE_DIR:=/var/cache/portage}

   : ${PORTAGE_SFS_NAME:?}

   # sfs container vars
   PORTAGE_SFS_CONTAINER_DIR="${PORTAGE_SFS_AUFS_ROOT}/image"
   : ${PORTAGE_SFS_CONTAINER_NAME:=portage_sfs}
   : ${PORTAGE_SFS_CONTAINER_SIZE:=500}

   # other vars
   # -> mountpoints
   PORTAGE_SFS_MEM_ROOT="${PORTAGE_SFS_AUFS_ROOT}/volatile"
   PORTAGE_SFS_SFS_ROOT="${PORTAGE_SFS_AUFS_ROOT}/persistent"

   PORTAGE_SFS_MEM_MP="${PORTAGE_SFS_MEM_ROOT}/${PORTAGE_SFS_NAME}"
   PORTAGE_SFS_SFS_MP="${PORTAGE_SFS_SFS_ROOT}/${PORTAGE_SFS_NAME}"

   : ${PORTAGE_SFS_MP:?}

   # -> tmpfs size

   : ${PORTAGE_SFS_MEM_SIZE_DEFAULT:=500}

   : ${PORTAGE_SFS_MEM_SIZE:=${PORTAGE_SFS_MEM_SIZE_DEFAULT}}
}

# void portage_sfs_printenv ( **... )
#
#  Prints some portage_sfs related variables to stdout.
#
portage_sfs_printenv() {
   printvar \
      PORTAGE_SFS_NAME \
      PORTAGE_SFS_MP \
      PORTAGE_SFS_IMAGE_DIR \
      PORTAGE_SFS_CONTAINER_NAME \
      PORTAGE_SFS_CONTAINER_SIZE \
      PORTAGE_SFS_AUFS_ROOT \
      PORTAGE_SFS_MEM_ROOT \
      PORTAGE_SFS_MEM_MP \
      PORTAGE_SFS_MEM_SIZE \
      PORTAGE_SFS_MEM_SIZE_DEFAULT \
      PORTAGE_SFS_SFS_ROOT \
      PORTAGE_SFS_SFS_MP
}

# @private void portage_sfs__setvars_save()
#
#  Sets additional variables required for creating a tree snapshot.
#
portage_sfs__setvars_save() {
   PORTAGE_SFS_DESTFILE=

   local dest="${PORTAGE_SFS_IMAGE_DIR}/${PORTAGE_SFS_NAME}_$(date +%F)"

   if [ -e "${dest}.sfs" ]; then
      # beware that there's a race condition if you (want to?) create more
      # than one snapshot of the same tree simultaneously
      local i=1
      while [ -e "${dest}-r${i}.sfs" ]; do
         i=$(( ${i} + 1 ))
      done
      PORTAGE_SFS_DESTFILE="${dest}-r${i}.sfs"
   else
      PORTAGE_SFS_DESTFILE="${dest}.sfs"
   fi
}

# @private void portage_sfs__setvars_save_today()
#
#  Like portage_sfs__setvars_save but doesn't try to find a file name.
#  Useful if you want to check whether an image file has already been
#  created (today).
#
portage_sfs__setvars_save_today() {
   PORTAGE_SFS_DESTFILE="${PORTAGE_SFS_IMAGE_DIR}/${PORTAGE_SFS_NAME}_$(date +%F).sfs"
}

# @private int portage_sfs__save_to (
#    sfs_file, update=n, **PORTAGE_SFS_MP, **...
# )
#
#  Creates a snapshot file of PORTAGE_SFS_MP and stores it as sfs_file.
#  Also updates the image file link if update is set to 'y'.
#
portage_sfs__save_to() {
   if \
      dodir_clean "${PORTAGE_SFS_IMAGE_DIR}" && \
      mksquashfs "${PORTAGE_SFS_MP}" "${1:?}" ${PORTAGE_SFS_MKSFS_OPTS-}
   then
      if [ "${2:-n}" = "y" ]; then
         portage_sfs_update_image_file "${PORTAGE_SFS_DESTFILE}"
         return ${?}
      else
         return 0
      fi
   else
      __quiet__ || eerror "Failed to create ${PORTAGE_SFS_DESTFILE}!"
      return 10
   fi
}


# int portage_sfs_init ( portage_tree_name, portage_tree_mp, ... )
#
#  Calls portage_sfs_reset() and
#  initializes the portage_sfs squahsfs container.
#
#  Note:
#     Locked containers have to be unlocked manually (sfs_container_unlock()).
#
portage_sfs_init() {
   portage_sfs_reset "$@" && \
   sfs_container_init \
      "${PORTAGE_SFS_CONTAINER_DIR}" \
      "${PORTAGE_SFS_CONTAINER_NAME}" \
      "${PORTAGE_SFS_CONTAINER_SIZE}"
}

# void portage_sfs_reset (
#    portage_tree_name, portage_tree_mp, portage_tree_mem_size=
# )
#
#  Sets all variables required for basic usage / mounting a squashed portage
#  tree.
#
portage_sfs_reset() {
   PORTAGE_SFS_NAME="${1:?}"
   PORTAGE_SFS_MP="${2:?}"
   PORTAGE_SFS_MEM_SIZE="${3-}"
   portage_sfs__setvars
}

# int portage_sfs_import ( **PORTAGE_SFS_NAME, **PORTAGE_SFS_IMAGE_DIR )
#
#  Imports the squashfs file.
#
portage_sfs_import() {
   # automatic resize does not work properly when reading a file
   sfs_container_import \
      "${PORTAGE_SFS_IMAGE_DIR}/${PORTAGE_SFS_NAME}.sfs" \
      "${PORTAGE_SFS_NAME}" "0" "y"
}

# int portage_sfs_mount (
#    **PORTAGE_SFS_NAME, **PORTAGE_SFS_MP,
#    **PORTAGE_SFS_MEM_SIZE, **PORTAGE_SFS_SFS_MP, **PORTAGE_SFS_MEM_MP
# )
#
#  Mounts the writable portage tree.
#
portage_sfs_mount() {
   sfs_container_mount_writable_clean \
      "${PORTAGE_SFS_NAME}" \
      "${PORTAGE_SFS_MP}" \
      "${PORTAGE_SFS_MEM_SIZE}" \
      "${PORTAGE_SFS_SFS_MP}" \
      "${PORTAGE_SFS_MEM_MP}"
}

# int portage_sfs_eject (
#    **PORTAGE_SFS_MP, **PORTAGE_SFS_SFS_MP, **PORTAGE_SFS_MEM_MP
# )
#
#  Unmounts the portage tree (if mounted).
#
portage_sfs_eject() {
   if unmount_if_mounted "${PORTAGE_SFS_MP}"; then
      local rc=0

      unmount_if_mounted "${PORTAGE_SFS_SFS_MP}" || rc=2
      # FIXME: remove old squashfs file?
      unmount_if_mounted "${PORTAGE_SFS_MEM_MP}" || rc=$(( ${rc} + 3 ))

      return ${rc}
   else
      return 1
   fi
}

# void portage_sfs_test_save ( quiet=**QUIET=n, **v0! )
#
portage_sfs_test_save() {
   local PORTAGE_SFS_DESTFILE
   portage_sfs__setvars_save
   v0="${PORTAGE_SFS_DESTFILE}"
   [ "{1:-${QUIET:-n}}" = "y" ] || einfo "dest file would be ${v0}."
}

# portage_sfs_save ( **PORTAGE_SFS_DESTFILE!, **PORTAGE_SFS_MP, **... )
#
#  Creates a snapshot of PORTAGE_SFS_MP and stores the resulting squashfs
#  file in PORTAGE_SFS_IMAGE_DIR/. Also updates the image file link.
#
portage_sfs_save() {
   portage_sfs__setvars_save
   portage_sfs__save_to "${PORTAGE_SFS_DESTFILE}" "y"
}

# portage_sfs_save_today ( **PORTAGE_SFS_DESTFILE!, **PORTAGE_SFS_MP, **... )
#
#  Like portage_sfs_save(), but doesn't do anything if a snapshot file
#  has already been created today (date +%F).
#
portage_sfs_save_today() {
   portage_sfs__setvars_save_today
   # test -e, test -f -- be a bit more accurate which requires 2 test commands
   if [ -e "${PORTAGE_SFS_DESTFILE}" ]; then
      if [ -f "${PORTAGE_SFS_DESTFILE}" ]; then
         return 0
      else
         ${LOGGER} --level=WARN "${PORTAGE_SFS_DESTFILE} exists, but is not a file."
         return 132
      fi
   else
      portage_sfs__save_to "${PORTAGE_SFS_DESTFILE}" "y"
   fi
}

# int portage_sfs_update_image_file ( new_file )
#
#  Updates %PORTAGE_SFS_IMAGE_DIR/%PORTAGE_SFS_NAME.sfs so that it either
#  is %new_file (by moving it) or points to %new_file (symlink).
#
portage_sfs_update_image_file() {
   : ${1:?}
   local f="${PORTAGE_SFS_IMAGE_DIR}/${PORTAGE_SFS_NAME}.sfs"

   if [ -h "${f}" ] || [ ! -e "${f}" ]; then
      ${LOGGER} --level=INFO "Updating symlink ${f}"

      if ln -T -s -f -- "${1}" "${f}"; then
         return 0
      else
         ${LOGGER} -0 --level=ERROR "Failed to update symlink ${f}!"
         return 20
      fi

   else
      ${LOGGER} --level=INFO "Moving ${1} => ${f}"

      if mv -T -b -- "${1}" "${f}"; then
         return 0
      else
         ${LOGGER} -0 --level=ERROR "Failed to move ${1}!"
         return 30
      fi
   fi
}
