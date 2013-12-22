#@HEADER
# call any shlib function as script
#
# this as a few drawbacks, though:
# * obviously, you have to know the function's name
# * external variables/functions are unavailable unless you export them
#

#@section __main__

LOGGER=true readconfig_optional_search "shlib-call"

if [ "x${1-}" = "x${SHLIB_INSTROSPECTION_MAGIC_EXEC_WORD:?}" ]; then

   shift && "$@"

elif function_defined "${SCRIPT_NAME}"; then

   shlib_call_wrap_v0 ${SCRIPT_NAME} "$@"

elif [ -z "$*" ] || [ "${1}" = "-h" ] || [ "${1}" = "--help" ]; then

   {
      echo "Usage: ${SCRIPT_NAME} <shlib function> [<args>]"
      echo "       ${SCRIPT_NAME} list-functions|lf"
      echo "       ${SCRIPT_NAME} list-variables|lv"
      echo "       ${SCRIPT_NAME} --install|-i <dir>"
      echo "         install functions as applets into <dir>"
      echo "       ${SCRIPT_NAME} --exports|-e"
      echo "         list all function that could be installed"
      echo
      echo "The EXPORT_FUNCTIONS variable can be used to list the functions that should be installed."
   } | fold -s -w 60
   exit 0

elif function_defined "${1}"; then

   shlib_call_wrap_v0 "$@"

elif [ "${1}" = "list-functions" ] || [ "${1}" = "lf" ]; then
   shlib_list_functions

elif [ "${1}" = "list-variables" ] || [ "${1}" = "lv" ]; then
   shlib_list_variables

elif [ "${1}" = "--exports" ] || [ "${1}" = "-e" ]; then

   if [ -n "${EXPORT_FUNCTIONS-}" ]; then

      for f in ${__EXPORT_FUNCTIONS-}; do
         if [ -z "${f}" ]; then
            true
         elif list_has "${f}" ${EXPORT_FUNCTIONS}; then
            einfo "${f}"
         else
            ewarn "${f}" 2>&1
         fi
      done

   else

      for f in ${__EXPORT_FUNCTIONS-}; do
         [ -z "${f}" ] || einfo "${f}"
      done

   fi | LC_ALL=C sort -k 2,2 -d

elif [ "${1}" = "--install" ] || [ "${1}" = "-i" ]; then

   if [ -z "${2-}" ]; then
      die "Usage: ${SCRIPT_NAME} --install|-i <dir>"

   elif [ -e "${2}" ] && [ ! -d "${2}" ]; then
      eerror "${2} exists but is not a directory."
      die "Usage: ${SCRIPT_NAME} --install|-i <dir>"

   elif \
      [ -z "${__EXPORT_FUNCTIONS-}" ] # || \
#      [ "x${EXPORT_FUNCTIONS-A}" = "x${EXPORT_FUNCTIONS-B}" ]
   then
      die "nothing to install"

   else
      DESTDIR=$(readlink -f "${2}")
      SCRIPT_DIR_ABSOLUTE=$(readlink -f "${SCRIPT_DIR}")
      SCRIPT_FILE=$(readlink -f "${0}")

      if [ "${DESTDIR}" = "${SCRIPT_DIR_ABSOLUTE}" ]; then
         LINK_TARGET="${SCRIPT_FILENAME}"
      else
         dodir_clean "${DESTDIR}" || die "dodir failed"
         LINK_TARGET="${SCRIPT_FILE}"
      fi

      # void symlink_self (
      #    link_name, **DESTDIR, **SCRIPT_FILE, **LINK_TARGET
      # )
      #
      #  Sets up a symlink in DESTDIR.
      #
      symlink_self() {
         local link="${DESTDIR}/${1}"
         if [ -e "${link}" ]; then
            local dest=$(readlink -f "${link}")
            if [ "${dest}" = "${SCRIPT_FILE}" ]; then
               einfo "Skipping ${link} - already installed"
            else
               eerror "Skipping ${link} - is a file/dir"
            fi
         else
            if [ -h "${link}" ]; then
               ewarn "Removing dead symlink ${link}"
               rm "${link}" || die
            fi
            einfo "Adding ${link}"
            ln -s "${LINK_TARGET}" "${link}" 2>&1 || \
               eerror "Could not install ${link}"
         fi
      }

      if [ -n "${EXPORT_FUNCTIONS-}" ]; then
         for f in ${__EXPORT_FUNCTIONS}; do
            if list_has "${f}" ${EXPORT_FUNCTIONS}; then
               symlink_self "${f}"
            fi
         done

      else
         for f in ${__EXPORT_FUNCTIONS}; do
            symlink_self "${f}"
         done
      fi
   fi

else

   die "no such function: '${1}'"

fi
