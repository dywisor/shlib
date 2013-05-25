# non-essential helper functions

# path relative to NEWROOT
: ${LIRAM_ENV_FILE:=LIRAM_ENV}

# void liram_zap_env_file ( **NEWROOT, **LIRAM_ENV_FILE )
#
#  Deletes the env file (if it exists).
#
liram_zap_env_file() {
   rm -f "${NEWROOT:?}/${LIRAM_ENV_FILE#/}"
}

# @private int liram__write_env ( line, **NEWROOT, **LIRAM_ENV_FILE )
#
#  Adds a text line to the env file.
#
liram__write_env() {
   echo "$*" > "${NEWROOT:?}/${LIRAM_ENV_FILE#/}"
}

# int liram_write_env_var ( varname, [value] )
#
#  Adds a variable declaration varname=value to the env file.
#
liram_write_env_var() {
   if [ -n "${2+SET}" ]; then
      echo "${1:?}=\"${2}\"" > "${NEWROOT:?}/${LIRAM_ENV_FILE#/}"
   else
      local v
      eval "v=\"\${${1:?}-}\""
      echo "${1:?}=\"${v}\"" > "${NEWROOT:?}/${LIRAM_ENV_FILE#/}"
   fi
}

# int liram_write_env()
#
#  Creates the default env file.
#
liram_write_env() {
   liram_zap_env_file && \
   liram_write_env_var "LIRAM_DISK" "${LIRAM_DISK}" && \
   liram_write_env_var "LIRAM_DISK_FSTYPE" "${LIRAM_DISK_FSTYPE}" && \
   liram_write_env_var "LIRAM_SLOT" "${LIRAM_SLOT}" && \
   liram_write_env_var "LIRAM_LAYOUT" "${LIRAM_LAYOUT}" && \
   liram_write_env_var "NEWROOT_HOME_DIR" "${NEWROOT_HOME_DIR-}"
}
