#@section functions

# @private int readconfig__search ( name, **config_file! )
#
#  Searches for a config file with the given name at the following locations,
#  in that order:
#
#  * $HOME/.<name>, $HOME/.<name>.conf,
#     $HOME/.<name>/config, $HOME/.<name>/<name>.conf
#  * $HOME/.config/<name>, ...
#  * /etc/<name>, ...
#
#  Sets config_file on first match and returns 0.
#  Returns 1 if no config file found.
#
readconfig__search() {
   local k conf
   [ -n "${HOME-}" ] || local HOME=/dev/null
   for k in \
      "${HOME}/.${1}" "${HOME}/.config/${1}" "/etc/${1}" "/etc/shlib/${1}"
   do
      if [ -f "${k}" ]; then
         if [ "$(readlink -f ${0})" != "$(readlink -f ${k})" ]; then
            config_file="${k}"
            return 0
         fi

      elif [ -f "${k}.conf" ]; then
         config_file="${k}.conf"
         return 0

      elif [ -d "${k}" ]; then

         for conf in \
            "${k}/config" \
            "${k}/${1}.conf"
         do
            if [ -f "${conf}" ]; then
               config_file="${conf}"
               return 0
            fi
         done
      fi
   done
   return 1
}

# void readconfig__read ( config_file=**config_file ), raises die()
#
#  Reads a config file. Dies on errors.
#
readconfig__read() {
   if [ -n "${1}" ]; then
      ${LOGGER} -0 --level=DEBUG --facility=readconfig "reading file ${1}"
      . "${1}" -- || die "errors while reading config file '${1}'"
   else
      readconfig__read "${config_file:?}"
   fi
}

readconfig__die_not_found() {
   die "cannot read config file(s) '${*}'"
}


#@section functions

# int readconfig_optional ( *config_file, **READCONFIG_READ_ALL=n )
#
#  Loads an optional config file.
#  Stops after reading the first file unless READCONFIG_READ_ALL is set to y.
#
#  !!! Reading a file is not "optional" and has to succeed,
#      else this function calls die().
#
#  Returns 0 if a file has been read, else returns 1.
#
readconfig_optional() {
   local any=1
   while [ $# -gt 0 ]; do
      if [ -f "${1}" ]; then
         readconfig__read "${1}"
         if [ "${READCONFIG_READ_ALL:-n}" = "y" ]; then
            any=0
         else
            return 0
         fi
      fi
      shift
   done
   return ${any}
}

# int readconfig_optional_all ( *config_file )
#
#  Loads zero or more optional config files. Also see readconfig_optional().
#
#  Returns 0 if >= 1 files have been read, else returns 1.
#
readconfig_optional_all() {
   READCONFIG_READ_ALL=y readconfig_optional "$@"
}

# int readconfig_optional_search ( *config_name, **READCONFIG_READ_ALL=n )
#
#  Like readconfig_optional() but searches for each config file at the
#  default locations (see readconfig__search()).
#
readconfig_optional_search() {
   local config_file any=1
   while [ $# -gt 0 ]; do
      if readconfig__search "${1}"; then
         readconfig__read "${config_file}"
         if [ "${READCONFIG_READ_ALL:-n}" = "y" ]; then
            any=0
         else
            return 0
         fi
      fi
      shift
   done
   return ${any}
}

# int readconfig_optional_search_all ( *config_name )
#
#  Loads zero or more optional config files by name.
#  Also see readconfig_optional_search().
#
readconfig_optional_search_all() {
   READCONFIG_READ_ALL=y readconfig_optional_search "$@"
}

# The following functions behave like their readconfig_optional_* counterpart,
# but fail if no config file could be found or read.

# void readconfig ( *config_file, **READCONFIG_READ_ALL )
#
readconfig() {
   readconfig_optional "$@" || readconfig__die_not_found "$@"
}

# void readconfig_all ( *config_file )
#
readconfig_all() {
   READCONFIG_READ_ALL=y readconfig_optional "$@" || \
      readconfig__die_not_found "$@"
}

# void readconfig_search ( *config_name, **READCONFIG_READ_ALL )
#
readconfig_search() {
   readconfig_optional_search "$@" || readconfig__die_not_found "$@"
}

# void readconfig_search_all ( *config_name )
#
readconfig_search_all() {
   READCONFIG_READ_ALL=y readconfig_optional_search "$@" || \
      readconfig__die_not_found "$@"
}
