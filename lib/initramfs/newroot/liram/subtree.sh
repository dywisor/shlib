# void liram_mount_subtree (
#    mp, size_m, name=<auto>, opts="mode=0755", **NEWROOT
# ), raises liram_die()
#
#  Mounts a subtree with the given size at NEWROOT/mp.
#
liram_mount_subtree() {
   if [ -z "${1-}" ]; then
      liram_die "liram_mount_subtree(): missing 'mp' arg."
   elif [ -z "${2-}" ]; then
      liram_die "liram_mount_subtree(): missing 'size_m' arg."
   elif [ "x${3-}" != "x@virtual" ]; then

      # enable LIRAM_ETC_INCREMENTAL
      ## mv %NEWROOT/etc <somewhere> fails if etc is a tmpfs
      ##
      [ "${1#/}" != 'etc' ] || LIRAM_ETC_INCREMENTAL=y

      liram_log "Mounting subtree /${1#/} with size=${2}m"
      imount_fs \
         "${NEWROOT?}/${1#/}" "${3:-liram_${1##*/}}" \
         "${4:-mode=0755},size=${2}m" "tmpfs"
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
