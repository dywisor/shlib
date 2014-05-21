#@section functions

# void liram_mount_subtree (
#    mp, size_m, name=<auto>, opts="mode=0755", type="tmpfs", **NEWROOT
# ), raises liram_die()
#
#  Mounts a subtree with the given size at NEWROOT/mp.
#
liram_mount_subtree() {
   local mp fsname opts

   if [ -z "${1-}" ]; then
      liram_die "liram_mount_subtree(): missing 'mp' arg."
   elif [ -z "${2-}" ]; then
      liram_die "liram_mount_subtree(): missing 'size_m' arg."
   elif [ "x${3-}" != "x@virtual" ]; then

      # enable LIRAM_ETC_INCREMENTAL
      ## mv %NEWROOT/etc <somewhere> fails if etc is a tmpfs
      ##
      [ "${1#/}" != 'etc' ] || LIRAM_ETC_INCREMENTAL=y

      mp="${NEWROOT?}/${1#/}"

      # set %fsname
      # [ "${3:--}" != "-" ] && fsname="${3}" || fsname=<default>
      case "${3-}" in
         ''|'-')
            fsname="liram_${1##*/}"
         ;;
         *)
            fsname="${3}"
         ;;
      esac

      # same for %opts
      case "${4-}" in
         ''|'-')
            opts="mode=0755"
         ;;
         *)
            opts="${4}"
         ;;
      esac

      case "${5-}" in
         ''|tmpfs)
            liram_log "Mounting tmpfs subtree /${1#/} with size=${2}m"
            imount_fs "${mp}" "${fsname}" "${opts},size=${2}m" "tmpfs"
         ;;

         zram|zram=)
            liram_log "Mounting zram subtree /${1#/} with size=${2}m"
            initramfs_zram_dotmpfs "${mp}" "${fsname}" "${opts},size=${2}m"
         ;;

         zram=*)
            liram_log \
               "Mounting zram subtree /${1#/} with size=${2}m with fstype=${5#zram=}"
            initramfs_zram_dotmpfs \
               "${mp}" "${fsname}" "${opts},size=${2}m" "${5#zram=}"
         ;;

         *)
            liram_die "unknown subtree type '${5-}'."
         ;;
      esac
   else
      ## elif [ "${1#/}" = ... ] ...
      case "${1#/}" in
         'etc')
            LIRAM_ETC_TMPFS_SIZE="${2}"
         ;;
         'home')
            LIRAM_HOME_TMPFS_SIZE="${2}"
         ;;
         'usr')
            LIRAM_USR_TMPFS_SIZE="${2}"
         ;;
         'sh'|'scripts')
            LIRAM_SCRIPTS_TMPFS_SIZE="${2}"
         ;;
         *)
            liram_die "unknown @virtual subtree '/${1#/}'."
         ;;
      esac
   fi
}
