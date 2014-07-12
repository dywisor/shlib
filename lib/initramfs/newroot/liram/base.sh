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
readonly INITRAMFS_LIRAM_LAYOUTS_DIR="/liram/layouts"


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

# int liram_fetch_uri__http ( src, dest )
#
liram_fetch_uri__http() {
   inonfatal wget -O "${2:?}" "${1:?}"
}

# int liram_fetch_uri__rsync ( src, dest )
#
liram_fetch_uri__rsync() {
   inonfatal rsync -- "${1}" "${2}"
}

# int liarm_fetch_uri__file ( src, dest )
#
liram_fetch_uri__file() {
   inonfatal cp -- "${1}" "${2}"
}

# int liram_parse_uri ( uri, **uri!, **uri_type!, **uri_secure! )
#
liram_parse_uri() {
   uri=
   uri_type=
   uri_secure=n

   case "${1?}" in
      '')
         uri_type=none
         uri_secure=y
      ;;

      'http://'?*)
         uri_type=http
         uri="${1}"
      ;;

      'rsync://'?*)
         uri_type=rsync
         uri="${1}"
      ;;

      'file:///'?*)
         uri_type=builtin-file
         uri_secure=n
         uri="${1#file://}"
      ;;

      'file://./'?*)
         uri_type=file
         uri="${LIRAM_DISK_MNT_DIR}/${1#file://./}"
      ;;

      'file:///'*|'file://./'*)
         true
      ;;

      'file://'?*)
         uri_type=builtin-file
         uri_secure=y
         uri="${INITRAMFS_LIRAM_LAYOUTS_DIR}/${1#file://}"
      ;;

      *'://'*|*'::'|'::'*)
         true
      ;;

      ?*'::'?*)
         uri_type=rsync
         uri="${1}"
      ;;

      /*)
         # file, relative to initramfs /
         uri_type=builtin-file
         uri_secure=n
         uri="${1}"
      ;;

      ./?*)
         # file, relative to liram sysdisk (LIRAM_DISK_MNT_DIR)
         uri_type=file
         uri="${LIRAM_DISK_MNT_DIR}/${1#./}"
      ;;

      *)
         #@varcheck 1
         # file relative to initramfs layouts dir
         uri_type=builtin-file
         uri_secure=y
         uri="${INITRAMFS_LIRAM_LAYOUTS_DIR}/${1}"
      ;;
   esac


   case "${uri_type}" in
      '')
         ${LOGGER} --level=ERROR "cannot parse uri '${1}'"
         return 2
      ;;
      'builtin-file')
         case "${uri}" in
            "/mnt/"*|\
            "${LIRAM_DISK_MNT_DIR%/}/"*|\
            "${NEWROOT%/}/"*)
               # note that $NEWROOT/ uris are not supported as LAYOUT_URI
               uri_secure=n
               uri_type=file
            ;;
         esac
      ;;
   esac

   return 0
}


# void liram_parse_uri_check_insecure ( uri, **uri!, **uri_type! )
#
liram_parse_uri_check_insecure() {
   local uri_secure

   irun liram_parse_uri "${1?}"

   if [ "${uri_secure:?}" != "y" ]; then
      if [ "${LIRAM_INSECURE:-y}" != "y" ]; then
         liram_die "insecure uri of type ${uri_type-X} is not allowed: ${uri}"
      else
         ${LOGGER} --level=INFO "uri ${uri} is insecure."
      fi
   fi

   return 0
}


# @private void liram__init_vars (
#    **LIRAM_DISK!, **LIRAM_DISK_FSTYPE!, **LIRAM_NEED_NET_SETUP!,
#    **LIRAM_LAYOUT:="default"!
# ), raises liram_die()
#
liram__init_vars() {
   local uri uri_type

   if [ -z "${LIRAM_DISK-}" ]; then
      liram_errmsg_liram_disk_not_set
      liram_die "cannot operate without liram sysdisk."
      return 150
   fi

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

   : ${LIRAM_LAYOUT:=default}

   LIRAM_LAYOUT_URI_CMDLINE="${LIRAM_LAYOUT_URI-}"
   irun liram_parse_uri_check_insecure "${LIRAM_LAYOUT_URI_CMDLINE}"

   LIRAM_LAYOUT_URI="${uri?}"
   LIRAM_LAYOUT_URI_TYPE="${uri_type?}"
   #LIRAM_LAYOUT_FILE=

   case "${LIRAM_LAYOUT_URI_TYPE}" in
      none)
         LIRAM_LAYOUT_FILE=
      ;;

      builtin-file)
         LIRAM_LAYOUT_FILE="${LIRAM_LAYOUT_URI}"

         if [ ! -f "${LIRAM_LAYOUT_FILE}" ]; then
            liram_die \
               "builtin recipe file '${LIRAM_LAYOUT_FILE}' does not exist."
         fi
      ;;

      file)
         LIRAM_LAYOUT_FILE="/tmp/liram_layout.sh"

         inonfatal rm -f -- "${LIRAM_LAYOUT_FILE}"
      ;;

      *)
         LIRAM_NEED_NET_SETUP=y
         LIRAM_LAYOUT_FILE="/tmp/liram_layout.sh"

         inonfatal rm -f -- "${LIRAM_LAYOUT_FILE}"
      ;;
   esac
}

# void liram_mount_sysdisk ( **LIRAM_DISK, **LIRAM_DISK_FSTYPE=auto )
#
#  Mounts the liram sysdisk.
#
liram_mount_sysdisk() {
   if [ -n "${LIRAM_DISK_MP-}" ]; then
      ${LOGGER} --level=INFO "liram sysdisk is already mounted."

   else
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
   fi
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
#    **NEWROOT, **LIRAMFS_NAME=liramfs, **LIRAM_ROOTFS_SIZE,
#    **LIRAM_ROOTFS_TYPE=tmpfs, **LIRAM_ROOTFS_ZRAM_FSTYPE=auto
# )
#
#  Mounts NEWROOT as %LIRAM_ROOTFS_TYPE.
#
liram_mount_rootfs() {
   if [ -z "${LIRAM_ROOTFS_SIZE-}" ]; then
      liram_die "LIRAM_ROOTFS_SIZE is not set."
   fi

   case "${LIRAM_ROOTFS_TYPE-}" in
      ''|'tmpfs')
         imount_fs \
            "${NEWROOT:?}" "${LIRAMFS_NAME:=liramfs}" \
            "mode=0755,size=${LIRAM_ROOTFS_SIZE:?}m" "tmpfs"
      ;;
      'zram')
         initramfs_zram_dotmpfs \
            "${NEWROOT:?}" "${LIRAMFS_NAME:=liramfs}" \
            "mode=0755,size=${LIRAM_ROOTFS_SIZE:?}m" \
            "${LIRAM_ROOTFS_ZRAM_FSTYPE:-auto}"
      ;;
      *)
         liram_die "unknown LIRAM_ROOTFS_TYPE '${LIRAM_ROOTFS_TYPE-}'."
      ;;
   esac
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
   # already set by liram__init_vars()
   : ${LIRAM_LAYOUT:=default}
   if [ -c /dev/kmsg ]; then
      echo "liram: layout=${LIRAM_LAYOUT}" > /dev/kmsg
   fi

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

# void liram__fetch_layout (
#    **LIRAM_LAYOUT_URI_TYPE, **LIRAM_LAYOUT_URI, **LIRAM_LAYOUT_FILE
# )
#
liram__fetch_layout() {
   local tmpfile

   tmpfile="${LIRAM_LAYOUT_FILE}.fetch_tmp"

   irun rm -f "${tmpfile}"

   irun liram_fetch_uri__${LIRAM_LAYOUT_URI_TYPE:?} \
      "${LIRAM_LAYOUT_URI}" "${tmpfile}"

   if [ -f "${tmpfile}" ] && [ ! -h "${tmpfile}" ]; then
      irun mv -f -- "${tmpfile}" "${LIRAM_LAYOUT_FILE}"
   else
      liram_die "expected to get a layout file, got garbage."
   fi
}

# void liram__inject_layout ( **LIRAM_LAYOUT_FILE, **LIRAM_LAYOUT )
#
#  Loads a layout file.
#
liram__inject_layout() {
   local func

   if [ ! -f "${LIRAM_LAYOUT_FILE}" ]; then
      liram_die "layout file ${LIRAM_LAYOUT_FILE} is missing (not a file)."
      return
   fi

   for func in \
      init_layout do_layout \
      "liram_init_layout_${LIRAM_LAYOUT}" \
      "liram_populate_layout_${LIRAM_LAYOUT}"
   do
      if function_defined "${func}"; then
         ${LOGGER} --level=WARN "unregistering function ${func}()"
         unset -f "${func}" || ${LOGGER} --level=ERROR "unset -f failed."
      fi
   done

   ${LOGGER} --level=INFO "loading layout file ${LIRAM_LAYOUT_FILE}"
   if . "${LIRAM_LAYOUT_FILE}"; then
      func="liram_init_layout_${LIRAM_LAYOUT}"
      if function_defined "${func}"; then
         true
      elif function_defined init_layout; then
         irun function_alias init_layout "${func}"
      fi

      func="liram_populate_layout_${LIRAM_LAYOUT}"
      if function_defined "${func}"; then
         true
      elif function_defined do_layout; then
         irun function_alias do_layout "${func}"
      else
         liram_die \
            "layout file ${LIRAM_LAYOUT_FILE} does not provide a populate function."
      fi

   else
      liram_die "failed to load layout file ${LIRAM_LAYOUT_FILE}."
   fi
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
   if [ -n "${LIRAM_DISK_MP-}" ]; then
      ${LOGGER} --level=WARN "forcefully resetting \$LIRAM_DISK_MP."
      irun liram_unmount_sysdisk
   fi

   irun liram__init_vars
   if [ -c /dev/kmsg ]; then
      echo "liram: initializing real root as tmpfs" > /dev/kmsg
   fi

   if [ "${LIRAM_NEED_NET_SETUP:-n}" = "y" ]; then
      irun initramfs_net_setup up
   fi

   case "${LIRAM_LAYOUT_URI_TYPE}" in
      'none')
         true
      ;;
      'builtin-file')
         irun liram__inject_layout
      ;;
      'file')
         # need sysdisk
         irun liram_mount_sysdisk
         irun liram__fetch_layout
         irun liram__inject_layout
      ;;
      *)
         irun liram__fetch_layout
         irun liram__inject_layout
      ;;
   esac


   if function_defined "liram_init_layout_${LIRAM_LAYOUT}"; then
      irun "liram_init_layout_${LIRAM_LAYOUT}"
   else
      irun liram_mount_rootfs
   fi

   irun liram_mount_sysdisk
   irun liram_populate
   irun liram_unmount_sysdisk
}
