# @private void dotar__get_file_ext ( short="n", **DOTAR__COMPRESS_OPT, **v0! )
#
#  Determines a file extension suitable for %DOTAR__COMPRESS_OPT and stores
#  it in %v0.
#  Sets %v0 to "tar" if the compression format is unknown or empty.
#
dotar__get_file_ext() {
   case "${DOTAR__COMPRESS_OPT#--}" in
      gzip)
         [ "${1:-n}" = "y" ] && v0="tgz" || v0="tar.gz"
      ;;
      bzip2)
         [ "${1:-n}" = "y" ] && v0="tbz2" || v0="tar.bz2"
      ;;
      xz)
         [ "${1:-n}" = "y" ] && v0="txz" || v0="tar.xz"
      ;;
      lzop)
         v0="tar.lzo"
      ;;
      *)
         v0="tar"
      ;;
   esac
}

# @private void dotar__doprefix_if ( fspath, prefix, readlink_mode="f" )
#
#  Applies %prefix to %fspath if %prefix is a string with non-zero length.
#
dotar__doprefix_if() {
   if [ -n "${2?}" ]; then
      fs_doprefix "${1?}" "${2}"
   else
      v0="${1?}"
   fi
   v0=$(readlink -${3:-f} "${v0}")
}

# void dotar_from ( src_dir, **DOTAR_ROOT_DIR, **DOTAR__SRC_DIR! )
#
#  Sets the directory that will be packed.
#
dotar_from() {
   local v0
   dotar__doprefix_if "${1}" "${DOTAR_ROOT_DIR-}"
   DOTAR__SRC_DIR="${v0}"
}

# void dotar_set_root ( root_dir, **DOTAR_ROOT_DIR! )
#
#  Sets the src root directory (root directory for dirs to be packed).
#
dotar_set_root() {
   if [ -z "${1?}" ]; then
      DOTAR_ROOT_DIR=
   else
      DOTAR_ROOT_DIR=$(readlink -f "${1:?}")
   fi
}

# void dotar_set_image_dir ( image_dir, **DOTAR_IMAGE_DIR! )
#
#  Sets the image directory (where packed files will be stored).
#
dotar_set_image_dir() {
   if [ -z "${1?}" ]; then
      DOTAR_IMAGE_DIR=
   else
      DOTAR_IMAGE_DIR=$(readlink -f "${1:?}")
   fi
}

# void dotar_set_compression ( compress_format, **DOTAR_COMPRESS! )
#
#  Sets the compression format.
#  "" and "none" can be used to disable compression.
#
dotar_set_compression() {
   if [ -n "${1?}" ] && [ "${1}" != "none" ]; then
      DOTAR_COMPRESS="${1}"
      local v0
      compress_detect_taropt "${DOTAR_COMPRESS}"
      DOTAR__COMPRESS_OPT="${v0}"
   else
      DOTAR_COMPRESS=
      DOTAR__COMPRESS_OPT=
   fi
}

# @private void dotar__exclude_append ( relpath, **DOTAR_EXCLUDE! )
#
#  Adds ./%relpath to dotar's exclude list.
#
dotar__exclude_append() {
DOTAR_EXCLUDE="${DOTAR_EXCLUDE-}
--exclude
./${1#/}"
}

# void dotar_exclude ( *fspath, **DOTAR_EXCLUDE! )
#
#  Adds zero or more file paths to dotar's exclude list.
#
dotar_exclude() {
   while [ $# -gt 0 ]; do
      dotar__exclude_append "${1#./}"
      shift
   done
}

# void dotar_exclude_dir ( *dirpath, **DOTAR_EXCLUDE! )
#
#  Adds zero or more directory paths to dotar's exclude list.
#  The directory itself will be part of the tarball, but its contents won't.
#
dotar_exclude_dir() {
   while [ $# -gt 0 ]; do
      dotar__exclude_append "${1#./}/*"
      shift
   done
}

# void dotar_exclude_abs_dir ( *dirpath, **DOTAR_EXCLUDE! )
#
#  Adds zero or more absolute directory paths to dotar's exclude list.
#  See dotar_exclude_dir() for details.
#
dotar_exclude_abs_dir() {
   local reldir
   while [ $# -gt 0 ]; do
      if [ -n "${1}" ]; then
         reldir=$(readlink -f "${1}")
         reldir="${reldir#${DOTAR__SRC_DIR-}}"

         [ "${reldir}" = "${1}" ] || dotar__exclude_append "${reldir}/*"
      fi
      shift
   done
   return 0
}

# void dotar_exclude_image_dir ( **DOTAR_IMAGE_DIR, **DOTAR_EXCLUDE! )
#
#  Adds dotar's image directory to the exclude list.
#
dotar_exclude_image_dir() {
   dotar_exclude_abs_dir "${DOTAR_IMAGE_DIR-}"
}

# void dotar_zap_exclude ( **DOTAR_EXCLUDE! )
#
#  Empties dotar's exclude list.
#
dotar_zap_exclude() {
   DOTAR_EXCLUDE=
}

# void dotar_print_env ( **... )
#
dotar_printenv() {
   printvar \
      DOTAR_ROOT_DIR \
      DOTAR_IMAGE_DIR \
      DOTAR__SRC_DIR \
      DOTAR_COMPRESS \
      DOTAR__COMPRESS_OPT \
      DOTAR_EXCLUDE \
      DOTAR_TAROPTS_APPEND \
      DOTAR_OVERWRITE \
      DOTAR_FAKE
}

# int dotar (
#    name, dest_file=<auto>,
#    **DOTAR_TAROPTS_APPEND, **DOTAR_OVERWRITE=n,
#    **DOTAR__SRC_DIR, **DOTAR_IMAGE_DIR, **DOTAR__COMPRESS_OPT,
#    **DOTAR_FAKE=n
# )
#
#  Packs the configured directory.
#
#  !!! Enables globbing via "set +f"
#
dotar() {
   local name="${1:?}" dest_file="${2-}" v0

   # verify that source directory exists -- **DOTAR__SRC_DIR
   if [ ! -d "${DOTAR__SRC_DIR-}" ]; then
      eerror "dotar source directory '${DOTAR__SRC_DIR}' does not exist."
      return 20

   # set dest_file -- %dest_file, %name, **DOTAR_IMAGE_DIR
   elif [ -z "${dest_file}" ]; then
      [ -n "${DOTAR_IMAGE_DIR-}" ] || function_die "DOTAR_IMAGE_DIR is not set."
      dotar__get_file_ext y
      dest_file="${name}.${v0}"
      dotar__doprefix_if "${dest_file}" "${DOTAR_IMAGE_DIR}" "m"
      dest_file="${v0}"
   fi

   # check if dest file exists -- **DOTAR_OVERWRITE
   if [ -e "${dest_file}" ]; then

      if [ ! -f "${dest_file}" ]; then
         eerror "dotar: dest file '${dest_file}' exists, but is not a file."
         return 21
      elif [ "${DOTAR_OVERWRITE:-n}" != "y" ]; then
         eerror "dotar: dest file '${dest_file}' exists."
         return 22
      fi

   else
      dodir_clean $(dirname "${dest_file}") || return
   fi

   # construct tar cmdv -- **DOTAR_TAROPTS_APPEND, **DOTAR__COMPRESS_OPT,
   #                       **DOTAR_EXCLUDE
   #
   set -- tar c ./ ${DOTAR_TAROPTS_APPEND-} -f "${dest_file}" ${DOTAR__COMPRESS_OPT-}

   set -f
   if [ -n "${DOTAR_EXCLUDE-}" ]; then
      local IFS="${IFS_NEWLINE}"
      set -- "$@" ${DOTAR_EXCLUDE}
      IFS="${IFS_DEFAULT}"
   fi

   # switch to source dir and pack it
   local rc=0
   if [ "${DOTAR_FAKE:-n}" != "y" ]; then
      ( cd "${DOTAR__SRC_DIR}" && "$@"; ) || rc=$?
   else
      einfo "dotar cmd:"
      einfo "${1}"
      shift
      for arg; do
         einfo "${arg}" "**"
      done
   fi
   set +f
   return ${rc}
}
