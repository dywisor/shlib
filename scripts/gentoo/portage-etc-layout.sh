# portage etc layout
#
#  creates directories in /etc/portage and converts existing files
#  into directories (required by crossdev, for example)
#

# void make_portage_subdir ( file ), raises die()
#
#  Replaces portage files with directories.
#
make_portage_subdir() {
   if [ -s "${1}" ]; then
      local bak="${1}.tmp_$$"
      autodie mv -T -- "${1}" "${bak}"
      if mkdir -- "${1}" && mv -T -- "${bak}" "${1}/default"; then
         einfo "${1} => ${1}/default"
      elif { [ ! -d "${1}" ] || rmdir "${1}"; } && mv -T -- "${bak}" "${1}"; then
         die "could not create directory ${1} (file has been restored)"
      else
         die "could not create directory ${1} and failed to restore file from '${bak}'."
      fi
   elif rm -- "${1}" && mkdir -- "${1}"; then
      einfo "replaced empty file ${1}"
   else
      die "could not create directory ${1}"
   fi
}

F_DODIR_EXISTED_FILE=make_portage_subdir \
DODIR_PREFIX="${PORTAGE_CONFIGROOT-}/etc/portage" \
autodie dodir \
   package.accept_keywords \
   package.maks package.unmask package.use \
   package.env env
