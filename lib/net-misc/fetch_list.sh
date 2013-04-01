# {int,void} fetch_item (
#    remote_uri,
#    [spacer],
#    distfile[name],
#    **FETCH_DISTFILE_PREFIX="",
#    **FETCH_DISTFILE_SUFFIX="",
#    **FETCH_URI_SUFFIX="",
#    **FETCH_URI_PREFIX="",
#    **DISTDIR,
#    **WGET=wget,
#    **WGET_QUIET=n,
#    **FETCH_UNCOMPRESS="",
#    **F_FETCH_ITEM="",
#    **F_FETCH_ON_SUCCESS="",
#    **F_FETCH_ON_FAIL="",
#    **FETCH_PASS_FAIL=n,
# )
#
#  Basic description:
#   Fetches a file from $remote_uri and saves it to $distfile.
#   Immediately returns 0 if $remote_uri is empty.
#
#  Arguments:
#  * remote_uri        -- uri that specifies how to download the file
#  * spacer            -- optional, this can be any string, e.g. "=>"
#  * distfile/distname -- optional, the base name of the distfile
#
#
# remote_uri (uses 2 keyword args):
#  will be set to
#  * <remote_uri><FETCH_URI_SUFFIX>
#     if remote uri matches ?*://?* (e.g. http://some.where.com/file)
#
#  * <FETCH_URI_PREFIX><remote_uri><FETCH_URI_SUFFIX>
#     otherwise
#
#  IOW, FETCH_URI_SUFFIX will always be appended and FETCH_URI_PREFIX only
#  if the given remote_uri does not start with a protocol specifier.
#
#
# distfile (uses 3 keywords args):
#
#  First, distfile will be set to
#  * arg 3 if set
#  * arg 2 if set and arg 3 empty
#  * the last path component of remote_uri, otherwise
#
#  Afterwards, FETCH_DISTFILE_PREFIX and FETCH_DISTFILE_SUFFIX will be
#  "added" properly.
#
#  Finally, distfile will be transformed into an absolute file path
#  (a) distfile will be left as-is if it starts with a slash char '/'
#  (b) "./" will be replaced with $PWD/
#  (c) otherwise, <distfile> will be set to <DISTDIR>/<distfile>
#
#  The order described here does not comply with the code below, but
#  the result should be the same.
#
#
# fetching distfile from remote_uri (uses 4 keyword args):
#
#  if F_FETCH_ITEM is set:
#    calls F_FETCH_ITEM ( remote_uri, distfile )
#
#  else:
#    uses WGET to download the file; passes -q to wget unless WGET_QUIET is
#    set to 'y'.
#
#    Writes distfile directly if FETCH_UNCOMPRESS is not set, else feeds
#    the ("hardcoded") decompressor programm via a pipe and writes the output
#    to distfile.
#
#    Accepted values for FETCH_UNCOMPRESS and
#    the decompressor that will be used):
#    * gz, gzip   => gzip
#    * bz2, bzip2 => bzip2
#    * xz         => xz
#    * lzo, lzop  => lzop
#
#    !!! This function will die if FETCH_UNCOMPRESS cannot be recognized.
#
# error handling (uses 3 keyword args):
#
#  Calls F_FETCH_ON_SUCCESS ( distfile, distfile_name ) on success (if set).
#
#  On error:
#  (a) calls F_FETCH_ON_ERROR ( distfile ) if set
#  (b) returns the return value of wget/F_FETCH_ITEM unless FETCH_PASS_FAIL
#      is set to 'y'
#  (c) removes distfile (rm -f) and returns 0
#  -> removes the distfile if it is an empty file
#
fetch_item() {
   local remote_uri distfile=""
   # set remote_uri / filter out empty uri
   case "${1-}" in
      '')
         return 0
      ;;
      ?*://?*)
         remote_uri="${1}${FETCH_URI_SUFFIX-}"
      ;;
      *)
         remote_uri="${FETCH_URI_PREFIX-}${1}${FETCH_URI_SUFFIX-}"
      ;;
   esac

   # set distfile
   if [ -n "${3-}" ]; then
      distfile="${3}"
   elif [ -n "${2-}" ] && [ "${2}" != '=>' ]; then
      distfile="${2}"
   else
      distfile="${1%/}"
      while [ "x${distfile%/}" != "x${distfile}" ]; do
         distfile="${distfile%/}"
      done
      distfile="${distfile##*/}"
   fi


   case "${distfile}" in
      /*)
         distfile="${distfile%%/*}/${FETCH_DISTFILE_PREFIX-}${distfile##*/}${FETCH_DISTFILE_SUFFIX-}"
      ;;
      ./*)
         distfile="${PWD}/${FETCH_DISTFILE_PREFIX-}${distfile#./}${FETCH_DISTFILE_SUFFIX-}"
      ;;
      *)
         distfile="${DISTDIR:?}/${FETCH_DISTFILE_PREFIX-}${distfile}${FETCH_DISTFILE_SUFFIX-}"
      ;;
   esac

   # finally: fetch

   local fetch_rc=0

   if [ -n "${F_FETCH_ITEM-}" ]; then
      ${F_FETCH_ITEM} "${remote_uri}" "${distfile}"
   else
      local WGET="${WGET:-wget}"
      [ "${WGET_QUIET:-y}" != "y" ] || WGET="${WGET} -q"

      if [ -z "${FETCH_UNCOMPRESS-}" ]; then

         ${WGET} -O "${distfile}" "${remote_uri}"

      elif compress_supports "${FETCH_UNCOMPRESS}"; then

         ${WGET} -O - "${remote_uri}" | \
            do_uncompress "${FETCH_UNCOMPRESS}" > "${distfile}"

      else
         function_die "FETCH_UNCOMPRESS '${FETCH_UNCOMPRESS}' is not supported."
      fi
   fi || fetch_rc=$?

   if [ ${fetch_rc} -eq 0 ]; then
      if [ -n "${F_FETCH_ON_SUCCESS-}" ]; then
         ${F_FETCH_ON_SUCCESS-} "${distfile}" "${distfile##*/}"
      fi
   else
      FETCH_FAIL=y
      if [ -n "${F_FETCH_ON_ERROR-}" ]; then
         ${F_FETCH_ON_ERROR} "${distfile}"
      elif [ "${FETCH_PASS_FAIL:-n}" = "y" ]; then
         return ${fetch_rc}
      else
         rm -f "${distfile}"
      fi
   fi
   return 0
}

# int __fetch_list_prepare ( **DISTDIR, **FETCH_FAIL )
#
#  Common "prepare" functionality for fetch_list()/fetch_list_from_*().
#  Returns 0 if successful, else != 0.
#
__fetch_list_prepare() {
   FETCH_FAIL=n
   case "${DISTDIR-}" in
      ''|'.'|'./')
         DISTDIR="${PWD}"
      ;;
      *)
         dodir "${DISTDIR}" || return
      ;;
   esac
}

# int fetch_list_from_file ( *uri_file, **DISTDIR, **<see fetch_item()> )
#
#  Reads uris from zero or more uri_files (one uri per line) and downloads
#  the corresponding files to DISTDIR.
#
fetch_list_from_file() {
   __fetch_list_prepare || return

   while [ $# -gt 0 ]; do
      if [ -n "${1-}" ]; then
         F_ITER=fetch_item ITER_UNPACK_ITEM=y file_iterator "${1}"
      fi
      shift
   done
   [ "${FETCH_FAIL:-n}" != "y" ]
}

# int fetch_list ( *linelist<uri>, **DISTDIR, **<see fetch_item()> )
#
#  Fetches zero or more files.
#
fetch_list() {
   __fetch_list_prepare || return

   while [ $# -gt 0 ]; do
      if [ -n "${1-}" ]; then
         F_ITER=fetch_item ITER_UNPACK_ITEM=y line_iterator "${1}"
      fi
   done
   [ "${FETCH_FAIL:-n}" != "y" ]
}
