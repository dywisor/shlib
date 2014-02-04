#@section functions


# void|int liram_manage_success ( [value], **LIRAM_MANAGE_SUCCESS! )
#
#  Gets/Sets %LIRAM_MANAGE_SUCCESS.
#
liram_manage_success() {
   if [ -n "${1-}" ]; then
      LIRAM_MANAGE_SUCCESS="${1}"
   else
      case "${LIRAM_MANAGE_SUCCESS:-n}" in
         '0'|'y')
            return 0
         ;;
      esac
      return 1
   fi
}

liram_manage_set_core_image_dir() {
   # TODO: properly get relative paths

   : ${LIRAM_IMAGE_ROOT:?}
   : ${LIRAM_DISK_MP:?}

   case "${1-}" in
      /)
         liram_manage_die "core image dir must not be ${1}."
      ;;
      "none")
         LIRAM_CORE_IMAGE_DIR=
         LIRAM_CORE_IMAGE_RELPATH=
      ;;
      '')
         # builtin default
         LIRAM_CORE_IMAGE_DIR="${LIRAM_IMAGE_ROOT}/core/default"
         LIRAM_CORE_IMAGE_RELPATH="../core/default"
      ;;
      //*)
         # double-slash enforces absolute path
         #  ** NOT SUPPORTED **
         liram_manage_die "absolute core image dir path is not supported."
         LIRAM_CORE_IMAGE_DIR="${1#/}"
         liram_manage_log_warn "cannot set LIRAM_CORE_IMAGE_RELPATH: TODO"
         LIRAM_CORE_IMAGE_RELPATH=
      ;;
      /*)
         # path relative to LIRAM_DISK_MP
         if [ "${LIRAM_IMAGE_ROOT}" != "${LIRAM_DISK_MP}" ]; then
            # COULDFIX: required for symlinking
            liram_manage_log_warn "cannot set LIRAM_CORE_IMAGE_RELPATH: TODO"
            LIRAM_CORE_IMAGE_RELPATH=
         else
            LIRAM_CORE_IMAGE_RELPATH="../${1#/}"
         fi

         LIRAM_CORE_IMAGE_DIR="${LIRAM_DISK_MP}/${1#/}"
      ;;
      *)
         # path relative to LIRAM_IMAGE_ROOT
         LIRAM_CORE_IMAGE_RELPATH="../${1#./}"
         LIRAM_CORE_IMAGE_DIR="${LIRAM_IMAGE_ROOT}/${1#./}"
      ;;
   esac

   LIRAM_CORE_IMAGE_DIR__CONFIG="${1-}"
}


liram_manage_init_vars() {
   # read user-defined config
   readconfig_optional "${CONFFILE:=/etc/liram/config}"

   # load LIRAM_ENV
   readconfig_optional "${LIRAM_ENV:=/LIRAM_ENV}"

   # (un)set vars / apply defaults

   if [ -n "${PACK_TARGETS-}" ]; then
      DEFAULT_PACK_TARGETS="${PACK_TARGETS}"
   fi
   unset -v PACK_TARGETS

   : ${DEVNULL:=/dev/null}

   # DATE_NOW (YYYY-MM-DD), used as default slot name
   DATE_NOW="$(date +%F)"

   # LOCKFILE
   : ${LOCKFILE_ACQUIRE_RETRY:=10}
   : ${LOCKFILE_ACQUIRE_WAIT_INTVL:=0.5}

   # LIRAM_MANAGE_LOCKDIR
   # -> LIRAM_MANAGE_PACK_LOCK
   : ${LIRAM_MANAGE_LOCKDIR:=/run/lock/liram}

   LIRAM_MANAGE_PACK_LOCK="${LIRAM_MANAGE_LOCKDIR}/pack.lock"

   # no locks have been claimed so far
   unset -v LIRAM_MANAGE_HAVE_PACK_LOCK

   # device and mount restore vars must not be set
   unset -v LIRAM_DISK_DEV
   unset -v LIRAM_BOOTDISK_DEV
   unset -v LIRAM_DISK_MOUNT_RESTORE
   unset -v LIRAM_BOOTDISK_MOUNT_RESTORE

   # dest slot vars must not be set
   unset -v LIRAM_DEST_SLOT
   unset -v LIRAM_DEST_SLOT_NAME
   unset -v LIRAM_DEST_SLOT_SUCCESS
   unset -v LIRAM_DEST_SLOT_WORKDIR

   # LIRAM_MANAGE_MNT_ROOT
   : ${LIRAM_MANAGE_MNT_ROOT:=/mnt/liram}

   # LIRAM_DISK_MP, LIRAM_BOOTDISK_MP defaults
   : ${LIRAM_DISK_MP:="${LIRAM_MANAGE_MNT_ROOT}/disk"}
   : ${LIRAM_BOOTDISK_MP:="${LIRAM_MANAGE_MNT_ROOT}/boot"}

   # LIRAM_IMAGE_ROOT
   #  Expected config value is a path relative to %LIRAM_DISK_MP
   #  The runtime value is an absolute path(!)
   #
   LIRAM_IMAGE_ROOT__CONFIG="${LIRAM_IMAGE_ROOT-}"
   if [ -n "${LIRAM_IMAGE_ROOT__CONFIG#/}" ]; then
      LIRAM_IMAGE_ROOT="${LIRAM_DISK_MP}/${LIRAM_IMAGE_ROOT__CONFIG#/}"
   else
      LIRAM_IMAGE_ROOT="${LIRAM_DISK_MP}"
   fi

   # LIRAM_CORE_IMAGE_DIR
   #
   #  Overlay directory whose content will be sym- or hardlinked
   #  into the new slot.
   #
   #  Typically, this should contain host-generated image files
   #  like / and /usr.
   #
   liram_manage_set_core_image_dir "${LIRAM_CORE_IMAGE_DIR-}" || return

   # LIRAM_BOOT_SLOT_NAME renames LIRAM_BOOT_SLOT
   LIRAM_BOOT_SLOT_NAME="${LIRAM_BOOT_SLOT:-current}"
   LIRAM_BOOT_SLOT="${LIRAM_IMAGE_ROOT}/${LIRAM_BOOT_SLOT_NAME}"

   # LIRAM_SLOT_NAME renames LIRAM_SLOT
   LIRAM_SLOT_NAME="${LIRAM_SLOT:-${DATE_NOW}}"
   unset -v LIRAM_SLOT

   # LIRAM_FALLBACK_SLOT_NAME renames LIRAM_FALLBACK_SLOT
   LIRAM_FALLBACK_SLOT_NAME="${LIRAM_FALLBACK_SLOT-}"
   if [ -n "${LIRAM_FALLBACK_SLOT_NAME}" ]; then
      LIRAM_FALLBACK_SLOT"${LIRAM_IMAGE_ROOT}/${LIRAM_FALLBACK_SLOT_NAME}"
   else
      unset -v LIRAM_FALLBACK_SLOT
   fi
}
