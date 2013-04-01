MULTICALL_ERROR_MSG="You have set up symlinks to this script rather than executing it directly."

if [ "${SCRIPT_NAME}" != "chmod" ]; then
   chmod_normalize_mode "${SCRIPT_NAME}" && \
   chmod --preserve-root ${v0} "$@"
elif [ "${HAVE_SHLIB_ALL:-n}" = "y" ]; then
   die "${MULTICALL_ERROR_MSG}" 5
else
   echo "${MULTICALL_ERROR_MSG}" 1>&2
   exit 5
fi
