#@section vars

#@section functions

# void pack_set_src_dir ( src_dir, **PACK_SRC_ROOT, **PACK_SRC! )
#
#  Sets the directory that will be packed.
#
pack_set_src_dir() {
   PACK_SRC=
   local v0

   fs_doprefix_if "${1?}" "${PACK_SRC_ROOT-}"
   if get_fspath "${v0}"; then
      PACK_SRC="${v0}"
   fi
}

# void pack_set_src_root ( root_dir, **PACK_SRC_ROOT! )
#
#  Sets the src root directory (root directory for dirs to be packed).
#
pack_set_src_root() {
   PACK_SRC_ROOT=
   local v0
   if [ -n "${1?}" ] && get_fspath "${1}"; then
      PACK_SRC_ROOT="${v0}"
   fi
}

# void pack_set_image_dir ( image_dir, **PACK_IMAGE_DIR! )
#
#  Sets the image directory (where packed files will be stored).
#
pack_set_image_dir() {
   PACK_IMAGE_DIR=
   local v0

   if [ -n "${1?}" ] && get_fspath "${1}"; then
      PACK_IMAGE_DIR="${v0}"
   fi
}

# @private int pack_vars__get_compress_opt (
#    name, user_choice, default, caller_func=
# ), raises die()
#
pack_vars__get_compress_opt() {
   case "${2?}" in
      'none')
         return 1
      ;;
      ''|'default')
         if compress_get_${1:?}_opt "${3?}"; then
            return 0
         else
            function_die "'${3}' compression is not supported" "${4-}"
         fi
      ;;
      *)
      if compress_get_${1:?}_opt "${2?}"; then
         return 0
      else
         function_die "'${2?}' compression is not supported" "${4-}"
      fi
   esac
}

# void pack_set_tarball_compression (
#    compress_format, **PACK_COMPRESS_TARBALL!, **PACK_COMPRESS__TAR_OPT!
# ), raises die()
#
pack_set_tarball_compression() {
   local compress_name compress_tar_opt

   if pack_vars__get_compress_opt \
      tar "${1?}" gzip pack_set_tarball_compression
   then
      PACK_COMPRESS_TARBALL="${compress_name}"
      PACK_COMPRESS__TAR_OPT="${compress_tar_opt}"
   else
      PACK_COMPRESS_TARBALL="none"
      PACK_COMPRESS__TAR_OPT=
   fi
}

# void pack_set_squashfs_compression (
#    compress_format, **PACK_COMPRESS_SQUASHFS!, **PACK_COMPRESS__MKSFS_OPT!
# ), raises die()
#
pack_set_squashfs_compression() {
   local compress_name compress_mksfs_opt
   if pack_vars__get_compress_opt \
      mksfs "${1?}" gzip pack_set_squashfs_compression
   then
      PACK_COMPRESS_SQUASHFS="${compress_name}"
      PACK_COMPRESS__MKSFS_OPT="${compress_mksfs_opt}"
   else
      PACK_COMPRESS_SQUASHFS="none"
      PACK_COMPRESS__MKSFS_OPT=
      function_die \
         "mksquashfs does not support no compression" \
         "pack_set_squashfs_compression"
   fi
}

# void pack_set_compression (
#    compress_format,
#    **PACK_COMPRESS_TARBALL!, **PACK_COMPRESS__TAR_OPT!,
#    **PACK_COMPRESS_SQUASHFS!, **PACK_COMPRESS__MKSFS_OPT!
# )
#
#  Sets the compression format.
#  "" and "default" can be used to set the defaults (gzip for tar and squashfs),
#  whereas "none" disables compression (not supported by squashfs).
#
pack_set_compression() {
   pack_set_tarball_compression "${1-}"
   pack_set_squashfs_compression "${2-${1-}}"
}

pack_set_type() {
   case "${1-}" in
      ''|'tar'|'tarball')
         PACK_TYPE=tar
      ;;
      'squashfs'|'sfs')
         PACK_TYPE=squashfs
      ;;
      *)
         die "unknown pack type '${1}'."
      ;;
   esac
}

# void pack_get_destfile ( name=**PACK_NAME, **v0! )
#
pack_get_destfile() {
   v0=

   if [ -z "${PACK_IMAGE_DIR-}" ]; then
      function_die "pack image dir is not set (or empty)."
   fi

   fs_doprefix_if "${1-${PACK_NAME}}" "${PACK_IMAGE_DIR}"
   get_abspath "${v0}"

   if [ -z "${v0}" ]; then
      function_die "failed to get pack destfile"
   fi

   case "${PACK_TYPE}" in
      'squashfs')
         v0="${v0}.sfs"
      ;;
      'tar')
         case "${PACK_COMPRESS_TARBALL}" in
            gzip)
               #v0="${v0}.tar.gz"
               v0="${v0}.tgz"
            ;;
            bzip2)
               #v0="${v0}.tar.bz2"
               v0="${v0}.tbz2"
            ;;
            xz)
               #v0="${v0}.tar.xz"
               v0="${v0}.txz"
            ;;
            lzop|lzo)
               v0="${v0}.tar.lzo"
               #v0="${v0}.tzo"
            ;;
            *)
               v0="${v0}.tar"
            ;;
         esac
      ;;
      *)
         function_die "unsupported pack type '${PACK_TYPE}'"
      ;;
   esac
}

# int pack_set_genscript_destfile ( fspath, **PACK_GENSCRIPT_DEST! )
#
pack_set_genscript_destfile() {
   PACK_GENSCRIPT_DEST=
   local v0

   if [ -z "${1?}" ]; then
      return 0
   elif get_fspath "${1}"; then
      PACK_GENSCRIPT_DEST="${v0}"
      return 0
   else
      return 1
   fi
}
