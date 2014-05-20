#@section functions

# int zram_tmpfs__from_vars (
#    *mkfs_args,
#    **size_m, **mp, **mount_opts, **fstype, **mode, **owner, **fsname=
#    **ZRAM_!,
# )
#
zram_tmpfs__from_vars() {
   zram_init_any "${size_m?}" tmpfs "${fsname?}" "${fstype?}" "${@}" || return
   # DOES NOT WORK
   [ -z "${fsname?}" ] || ZRAM_FS_NAME="${fsname}"

   zram_disk_mount \
      "${mp?}" "${mount_opts?}" "${fstype?}" "${mode?}" "${owner?}"
}

# @zram_init_any <disk::tmpfs> int zram_tmpfs ( mp, opts, fstype=auto )
#
#  Initializes any free zram device as tmpfs-like mount at %mp.
#  See zram_dotmpfs() for details.
#
zram_tmpfs() {
   #@debug [ -n "${1-}" ] || function_die "missing <mp> arg." "zram_tmpfs"
   local mp="${1:?}"
   shift && zram_dotmpfs "${mp}" "" "${@}"
}

# @zram_init_any <disk::tmpfs> zram_dotmpfs (
#    mp, name=<keep **ZRAM_FS_NAME>, opts, fstype=auto
# )
#
#  Initializes a tmpfs-like zram disk device and mounts it at %mp.
#
#  The %name parameter sets the filesystem's name (label) and defaults
#  to zram<IDENTIFIER> (if empty).
#
#  %opts should be a comma-separated list of tmpfs mount options and must
#  contain a size=<NUMBER>m arg (zram size in megabytes).
#  Percentages etc. are _not_ supported.
#
#  The default mount options are rw,noatime,mode=1777.
#
#  More precisely:
#  * noatime is added to the mount options if no other *atime option specified
#  * writability defaults to rw
#  * mode defaults to 1777 if the mount should be writable else <unset>
#
#  Returns: success (true/false)
#
#  The parameters accepted by this function are more or less in accordance
#  to dotmpfs() from fs/mount/dotmpfs.
#  See zram_tmpfs() for a variant that accepts up to 3 args.
#
#
#  Note that calling zram_init[_any] ... tmpfs ... manually is not recommended,
#  since %opts contains both init- and mount-related options, so you'll end
#  up parsing %opts twice or discarding information (size, mount opts, ...).
#  Use the more generic 'disk' type instead.
#
#  Also, this module does not provide a full set of functions (for example,
#  no zram_tmpfs_mount()).
#
##
## Note for implemententing size=p%:
##  use the following if no calc available:
##   final_size_m := min (
##      sys_mem - $$k,
##      max (
##         ( p * sys_mem ) / 100 > 0,
##         p * ( sys_mem / 100 )
##      )
##   )
##   where $$k >= 0
##
zram_dotmpfs() {
   #@varcheck_emptyok IFS_DEFAULT
   #@debug [ -n "${1-}"    ] || function_die "missing <mp> arg."   "zram_dotmpfs"
   #@debug [ -n "${2+SET}" ] || function_die "missing <name> arg." "zram_dotmpfs"
   #@debug [ -n "${3+SET}" ] || function_die "missing <opts> arg." "zram_dotmpfs"
   : ${1:?} ${2?} ${3?}
   zram_zap_vars
   local size_m mp mount_opts fstype mode owner fsname

   mp="${1}"
   fsname="${2}"
   fstype="${4:-auto}"

   if ! zram_tmpfs_parse_opts "${3?}" "${fstype}"; then
      zram_log_error "failed to parse zram-tmpfs options!"
      return ${EX_USAGE}
   fi

   zram_tmpfs__from_vars
}

# @zram_type_init <disk::tmpfs> zram_init__tmpfs (
#    fsname, fstype:=<default>, *mkfs_args, **ZRAM_,
# )
#
zram_init__tmpfs() {
   [ -z "${1?}" ] || ZRAM_FS_NAME="${1}"
   shift && zram_init__disk "${@}"
}

# int zram_tmpfs_parse_opts (
#    opts=, fstype=, **<see zram_tmpfs_parse_opts_unpacked()>!
# )
#
#  Unpacks the comma-separated %opts list and calls the actual parser function.
#
#  See zram_tmpfs_parse_opts_unpacked() for details.
#
zram_tmpfs_parse_opts() {
   #@varcheck_emptyok IFS_DEFAULT
   local fstype="${2-}"

   local IFS=","
   set -- ${1-}
   IFS="${IFS_DEFAULT}"

   zram_tmpfs_parse_opts_unpacked "${@}"
}

# int zram_tmpfs_parse_opts_unpacked (
#    *opts, **fstype=,
#    **size_m!?, **mount_opts!+={"rw","noatime"}, **mode!:=1777, **owner!:=
# )
#
# @ignored %fstype -- reserved for future usage
#
#  Parses tmpfs mount options and translates them into zram-disk options.
#
#  Note that
#     <opts accepted by this function> != <opts accepted by "mount -t tmpfs">
#
#  For example, this function accepts empty mode=/uid=/gid= args,
#  and requires a size=<NUMBER>[mM] arg (size in megabytes).
#  %mode can be set to anything accepted by chmod (e.g. a=rwx).
#
#  Returns: success (true/false)
#  * EX_USAGE if a mandatory arg was missing in %opts
#
zram_tmpfs_parse_opts_unpacked() {
   size_m=
   mount_opts=
   mode=
   owner=

   local uid= gid= rorw_arg= atime_arg= k v

   # parse options
   #
   # * rw implies a default %mode of 1777 (else %mode is kept)
   # * ro zaps %mode
   # * any non-empty %mode (0500,0777,a=,...) implies rw, else ro/rw is kept
   #
   while [ ${#} -gt 0 ]; do
      k="${1%%=*}"
      v="${1#*=}"
      [ "${v}" != "${1}" ] || v=

      case "${k}" in
         rw)
            rorw_arg="${1}"
            : ${mode:=1777}
         ;;
         ro)
            rorw_arg="${1}"
            mode=
         ;;
         mode)
            mode="${v}"
            [ -z "${mode}" ] || rorw_arg=rw
         ;;
         uid)
            uid="${v}"
         ;;
         gid)
            gid="${v}"
         ;;
         *diratime)
            # not suitable as atime_arg -> store in %mount_opts
            mount_opts="${mount_opts},${1}"
         ;;
         *atime)
            # any other atime arg -> store in %atime_arg
            atime_arg="${1}"
         ;;
         size)
            case "${v}" in
               ?*[mM])
                  size_m="${v%[mM]}"
               ;;
               *)
                  zram_log_error "size arg ${1} is not supported."
                  return 19
               ;;
            esac
         ;;
         *)
            mount_opts="${mount_opts},${1}"
         ;;
      esac

      shift
   done

   if [ -z "${size_m-}" ]; then
      zram_log_error "zram_tmpfs(): missing size= arg!"
      return ${EX_USAGE}
   fi

   # U:G, U:, :G
   [ -z "${uid-}${gid-}" ] || owner="${uid-}:${gid-}"

   # set mount_opts, apply defaults
   : ${rorw_arg:=rw}
   [ "${rorw_arg}" = "ro" ] || : ${mode:=1777}
   : ${atime_arg:=noatime}

   mount_opts="${rorw_arg},${atime_arg}${mount_opts}"

   return 0
}
