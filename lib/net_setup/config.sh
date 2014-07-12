#@section functions

net_setup_config_log() {
   dolog +net_setup +config --level="${1}" "${2}"
}

net_setup_config__wipe_dir() {
   net_setup_config_log DEBUG "removing ${1}${2:+ }${2}"

   if [ -z "${2}" ]; then
      net_setup_config_log DEBUG "${1} is not set."
      return 0

   elif [ -h "${2}" ]; then
      net_setup_config_log INFO "removing ${1} ${2} (symlink)"
      ${AUTODIE_NONFATAL-} rm -- "${2}"

   elif [ -d "${2}" ]; then
      net_setup_config_log INFO "removing ${1} ${2} (dir)"
      ${AUTODIE_NONFATAL-} rm -r -- "${2}"

   elif [ -e "${2}" ]; then
      net_setup_config_log INFO "removing ${1} ${2} (file?)"
      ${AUTODIE_NONFATAL-} rm -- "${2}"

   else
      net_setup_config_log DEBUG "${2} does not exist."
      return 0
   fi
}

net_setup_set_config_root() {
   NET_SETUP_CONFIG_ROOT="${1:?}"
}

net_setup_init_config_root() {
   if [ -z "${1-}" ]; then
      : ${NET_SETUP_CONFIG_ROOT:?}
   else
      NET_SETUP_CONFIG_ROOT="${1}"
   fi

   ${AUTODIE_NONFATAL-} dodir_clean "${NET_SETUP_CONFIG_ROOT}/globals"
}

net_setup_wipe_config_root() {
   net_setup_config__wipe_dir "config root" "${NET_SETUP_CONFIG_ROOT}"
}

# int net_setup_get_config_dir ( iface, **confdir! )
#
net_setup_get_config_dir() {
   : ${1:?}
   confdir="${NET_SETUP_CONFIG_ROOT:?}/net/${1}"
   [ -d "${confdir}" ]
}

# int net_setup_init_config_dir ( type, iface, **confdir! )
#
net_setup_init_config_dir() {
   : ${1:?} ${2:?}
   confdir="${NET_SETUP_CONFIG_ROOT:?}/net/${2}"

   # ?? COULDFIX: remove old dir

   if ! net_setup_config__wipe_dir "config dir" "${confdir}"; then
      return 4
   elif ${AUTODIE_NONFATAL-} dodir_clean "${confdir}"; then
      net_setup_config_write type     "${1}" && \
      net_setup_config_write initstate 0
   else
      net_setup_config_log ERROR "failed to create config dir ${confdir}"
      return 5
   fi
}



net_setup_config_globals_write() {
   echo "${2-}" > "${NET_SETUP_CONFIG_ROOT:?}/globals/${1:?}"
}

net_setup_config_globals_append() {
   echo "${2-}" >> "${NET_SETUP_CONFIG_ROOT:?}/globals/${1:?}"
}

net_setup_config_write() {
   echo "${2-}" > "${confdir:?}/${1:?}"
}

net_setup_config_append() {
   echo "${2-}" >> "${confdir:?}/${1:?}"
}

net_setup_config_foreach_device_path() {
   : ${NET_SETUP_CONFIG_ROOT:?}
   local func="${1:?}"
   local dev_path dev_type
   shift

   if [ ${#} -eq 0 ]; then
      for dev_path in "${NET_SETUP_CONFIG_ROOT}/net/"*; do
         if [ -d "${dev_path}" ]; then
            ${func:?} "${dev_path}" "${dev_path##*/}" || return
         fi
      done
   else
      for dev_path in "${NET_SETUP_CONFIG_ROOT}/net/"*; do
         if \
            [ -d "${dev_path}" ] && \
            read -r dev_type < "${dev_path}/type" &&
            list_has "${dev_type}" "$@"
         then
            ${func:?} "${dev_path}" "${dev_path##*/}" || return
         fi
      done
   fi
}


net_setup_config__add_device_name() { v0="${v0-} ${2}"; }
net_setup_config_get_devices() {
   v0=
   net_setup_config_foreach_device_path net_setup_config__add_device_name "$@"
   v0="${v0# }"
   [ -n "${v0}" ]
}

net_setup_config_read_entry_emptyok() {
   #@VARCHECK confdir 1
   v0=
   [ -f "${confdir}/${1}" ] && read -r v0 < "${confdir}/${1}" || return 1
}

net_setup_config_read_entry() {
   net_setup_config_read_entry_emptyok "${1:?}" && [ -n "${v0}" ]
}

net_setup_config_read_bool_entry() {
   local v0

   if ! net_setup_config_read_entry_emptyok "${1:?}"; then
      [ "${3:-n}" = "y" ] || return 1
      return 0

   elif [ "${v0:-${2:-y}}" = "y" ]; then
      return 0

   else
      return 1
   fi
}

net_setup_config_read_global_entry() {
   #@VARCHECK NET_SETUP_CONFIG_ROOT 1
   v0=
   [ -f "${NET_SETUP_CONFIG_ROOT}/globals/${1}" ] && \
      read -r v0 < "${NET_SETUP_CONFIG_ROOT}/globals/${1}" || return 1
   [ -n "${v0}" ]
}
