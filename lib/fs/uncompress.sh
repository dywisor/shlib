#@section functions

# @private int compress__detect_format (
#    compression_format|file,
#    **decompress_args!, **compress_exe!, **compress_name!
# )
#
#  Sets the compress_exe/decompress_args/compress_name variables.
#
#  Returns 0 on success, 2 if the first arg is empty, else 1.
#
compress__detect_format() {
   decompress_args='-d -c'
   compress_exe=
   compress_name=
   case "${1##*.}" in
      '')
         decompress_args=
         return 2
      ;;
      gzip|gz|tgz)
         compress_exe=gzip
         compress_name="${compress_exe}"
      ;;
      bzip2|bz2|tbz2)
         compress_exe=bzip2
         compress_name="${compress_exe}"
      ;;
      xz|txz)
         compress_exe=xz
         compress_name="${compress_exe}"
      ;;
      lzo|lzop)
         compress_exe=lzop
         compress_name=lzo
      ;;
      *)
         decompress_args=
         compress_name="${compress_exe}"
         return 1
      ;;
   esac
   return 0
}

# @private int compress__set_tar_opt (
#    **compress_name, **compress_exe, **compress_tar_opt!
# )
#
#  Sets the tar options based on %compress_name/%compress_exe.
#
#  Returns 0 if %compress_name is supported, else 2.
#
compress__set_tar_opt() {
   case "${compress_name}" in
      gzip)
         compress_tar_opt="-z"
      ;;
      bzip2)
         compress_tar_opt="-j"
      ;;
      xz)
         compress_tar_opt="-J"
      ;;
      lzo)
         compress_tar_opt="--lzop"
      ;;
      lzma|lzip)
         compress_tar_opt="--${compress_name}"
      ;;
      *)
         if [ -n "${compress_exe}" ]; then
            compress_tar_opt="-I ${compress_exe}"
         else
            return 2
         fi
      ;;
   esac
   return 0
}

# @private int compress__set_mksfs_opt (
#    **compress_name, **compress_mksfs_opt!
# )
#
#  Sets the mksquashfs options based on %compress_name/%compress_exe.
#
#  Returns 0 if %compress_name is supported, else 2.
#
compress__set_mksfs_opt() {
   case "${compress_name}" in
      gzip|xz|lzo)
         compress_mksfs_opt="-comp ${compress_name}"
      ;;
      *)
         return 2
      ;;
   esac
   return 0
}

# int compress_get_name ( compression_format|file, **compress_name! )
#
#  Sets the compress_name variable.
#
#  Returns 0 on success, 2 if the first arg is empty, else 1.
#
compress_get_name() {
   local compress_exe decompress_args
   compress__detect_format "$@"
}

# int compress_get_tar_opt (
#    compression_format|file, **compress_name!, **compress_tar_opt!
# )
#
#  Guesses the compression name and its tar option(s).
#
#  Returns 0 on success, 1 if the compression format could not be guessed,
#  and 2 if it is unsupported.
#
compress_get_tar_opt() {
   compress_name=
   compress_tar_opt=
   local compress_exe decompress_args

   if [ -z "${1?}" ]; then
      return 0
   elif ! compress__detect_format "$@"; then
      return 1
   elif ! compress__set_tar_opt; then
      return 2
   else
      return 0
   fi
}

# @function_alias compress_get_taropt() renames compress_get_tar_opt()
#
compress_get_taropt() { compress_get_tar_opt "$@"; }

# void compress_detect_taropt ( compression_format|file, **v0! )
#
#  Guesses tar compression options and stores the result in %v0.
#
compress_detect_taropt() {
   local compress_name compress_tar_opt
   compress_get_tar_opt "$@"
   v0="${compress_tar_opt?}"
   return 0
}

# int compress_get_mksfs_opt (
#    compression_format|file, **compress_name!, **compress_mksfs_opt!
# )
#
#  Guesses the compression name and its mksquashfs option(s).
#
#  Returns 0 on success, 1 if the compression format could not be guessed,
#  and 2 if it is unsupported.
#
compress_get_mksfs_opt() {
   compress_name=
   compress_mksfs_opt=
   local compress_exe decompress_args

   if [ -z "${1?}" ]; then
      return 0
   elif ! compress__detect_format "$@"; then
      return 1
   elif ! compress__set_mksfs_opt; then
      return 2
   else
      return 0
   fi
}

# int do_uncompress ( compression_format|file, *argv )
#
#  Uncompresses to stdout. The first arg has to be a compression format
#  (e.g. 'gzip') or a file, in which case the compression format will
#  be autodetected using the file extension.
#
#  Calls <decompressor> ( [file], *argv ) afterwards and returns the result.
#
# Important:
#
#    You cannot uncompress a file whose name is one of the compression
#    formats (gzip,gz,bzip2,bz2,xz,lzo,lzop) using the 1-arg form.
#    do_uncompress ( "gz" ) will decompress stdin,
#    while do_uncompress ( "gz", "gz" ) will uncompress a file named "gz".
#
do_uncompress() {
   local compress_exe decompress_args compress_name

   if compress__detect_format "${1-}"; then
      if [ "${1##*.}" != "${1}" ] || shift; then
         ${compress_exe} ${decompress_args} "$@"
      else
         return 4
      fi
   else
      return 5
   fi
}

# int compress_supports ( compression_format|file )
#
#  Returns 0 if (de-)compression for the given format or file is supported
#  by do_uncompress(), else 1.
#
#  Also verifies that the binary used for (de-)compression actually exists.
#
compress_supports() {
   local compress_exe decompress_args compress_name
   compress__detect_format "${1-}" && qwhich "${compress_exe}"
}
