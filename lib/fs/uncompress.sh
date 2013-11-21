#@section functions_private

# @private int compress__detect_format (
#    compression_format|file,
#    **decompress_args!, **compress_exe!
# )
#
#  Sets the compress_exe/decompress_args variables.
#
#  Returns 0 on success, 2 if the first arg is empty, else 1.
#
compress__detect_format() {
   decompress_args='-d -c'
   compress_exe=
   case "${1##*.}" in
      '')
         return 2
      ;;
      gzip|gz|tgz)
         compress_exe=gzip
      ;;
      bzip2|bz2|tbz2)
         compress_exe=bzip2
      ;;
      xz|txz)
         compress_exe=xz
      ;;
      lzo|lzop)
         compress_exe=lzop
      ;;
      *)
         decompress_args=
         return 1
      ;;
   esac
   return 0
}


#@section functions_public

# void compress_detect_taropt ( compression_format|file )
#
#  Guesses tar compression options and stores the result in %v0.
#
compress_detect_taropt() {
   v0=
   local decompress_args compress_exe

   if compress__detect_format "${1?}"; then
      v0="--${compress_exe}"
   fi
   return 0
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
   local compress_exe decompress_args
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
   local compress_exe decompress_args
   compress__detect_format "${1-}" && qwhich "${compress_exe}"
}
