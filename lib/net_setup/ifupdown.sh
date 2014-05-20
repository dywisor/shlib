#@section funcdef

# @funcdef @net_ifup<type> int net_ifup__<type>     ( **iface, **iftype, **confdir, **ret! )
# @funcdef @net_ifdown<type> int net_ifdown__<type> ( **iface, **iftype, **confdir, **ret! )
#
#  ifup/ifdown helper functions.
#

#@section functions

# @private int net_setup__set_wol (
#    **iface, **iftype, **confdir, **X_ETHTOOL=ethtool
# )
#
net_setup__set_wol() {
   local v0
   if net_setup_config_read_entry wol; then
      if ! ${X_ETHTOOL:-ethtool} -s "${iface}" wol "${v0}"; then
         net_setup_log_error "${iface}: failed to set wol '${v0}'"
         return 1
      fi
   fi
   return 0
}


# int net_ifup_all()
#
net_ifup_all() {
   local v0
   net_setup_config_get_devices || return 0
   net_ifup ${v0}
}

# int net_ifdown_all()
#
net_ifdown_all() {
   local v0
   net_setup_config_get_devices || return 0
   net_ifdown ${v0}
}

# int net_ifup ( *iface )
#
net_ifup() {
   local failret=0
   while [ ${#} -gt 0 ]; do
      net_ifup__iface "${1}" || failret=${?}
      shift
   done
   return ${failret}
}

# int net_ifdown ( *iface )
#
net_ifdown() {
   local failret=0
   while [ ${#} -gt 0 ]; do
      net_ifdown__iface "${1}" || failret=${?}
      shift
   done
   return ${failret}
}


# int net_ifup__iface ( iface )
#
net_ifup__iface() {
   local ret=0
   local iface iftype confdir istate

   iface="${1}"

   if ! net_setup_get_config_dir "${iface}"; then
      if [ "${iface}" = "lo" ]; then
         if net_iface_up; then
            net_iface_flush_addr
            net_iface_add_ipv4_addr "127.0.0.1/8" || ret=2
         else
            net_setup_log_error "failed to bring up ${iface}"
            ret=1
         fi
      else
         net_setup_log_error "interface ${iface} is not configured."
         ret=3
      fi

   elif [ -f "${confdir}/ignore" ]; then
      net_setup_log --level=WARN "interface ${iface} is ignored."
      #ret=0

   elif ! read -r iftype < "${confdir}/type"; then
      net_setup_log_error "failed to get type for interface ${iface}."
      ret=5

   elif ! read -r istate < "${confdir}/initstate"; then
      net_setup_log_error "failed to get init state for interface ${iface}."
      ret=6

   elif ! [ ${istate} -ge 0 2>/dev/null ]; then
      net_setup_log_error "invalid init state for interface ${iface}."
      ret=7

   elif [ ${istate} -gt 0 ]; then
      net_setup_log_debug "interface ${iface} already configured."
      #ret=0

   elif ! function_defined net_ifup__${iftype}; then
      net_setup_log_error \
         "cannot set up interface ${iface}: unsupported type ${iftype}"
      ret=8

   elif net_ifup__${iftype}; then
      if ! echo 1 > "${confdir}/initstate"; then
         net_setup_log_error \
            "failed to write init state for interface ${iface}"
         ret=9
      fi
      #else ret=0

   else
      ret=${?}
      net_setup_log_error "failed to set up ${iftype}-interface ${iface}"
   fi

   return ${ret?}
}

# int net_ifdown__iface ( iface )
#
net_ifdown__iface() {
   local ret=0
   local iface iftype confdir

   iface="${1}"

   if ! net_setup_get_config_dir "${iface}"; then
      if [ "${iface}" = "lo" ]; then
         net_ifdown__common
      else
         net_setup_log_error "interface ${iface} is not configured, using generic code."
         net_ifdown__common
      fi

   elif [ -f "${confdir}/ignore" ]; then
      net_setup_log --level=WARN "interface ${iface} is ignored."
      #ret=0

   elif ! read -r iftype < "${confdir}/type"; then
      net_setup_log_error "failed to get type for interface ${iface}."
      ret=5

   elif ! function_defined net_ifdown__${iftype}; then
      net_setup_log_error \
         "cannot bring down interface ${iface}: unsupported type ${iftype}"
      ret=6

   elif net_ifdown__${iftype}; then
      true

   else
      ret=${?}
      net_setup_log_error "failed to bring down ${iftype}-interface ${iface}"
   fi

   return ${ret?}
}


## specific ifup/ifdown functions


# @net_ifup common net_ifup__common()
#
net_ifup__common() {
   local v0 line have_any

   net_iface_flush_addr

   if [ -f "${confdir}/ipv4_addr" ]; then
      have_any=n
      while read -r line; do
         net_iface_add_ipv4_addr ${line} && have_any=y || ret=2
      done < "${confdir}/ipv4_addr"

      if [ "${have_any}" = "y" ] && net_setup_config_read_entry ipv4_gw; then
         net_iface_set_ipv4_gw ${v0} || ret=2
      fi
   fi

   if [ -f "${confdir}/ipv6_addr" ]; then
      have_any=n
      while read -r line; do
         net_iface_add_ipv6_addr ${line} && have_any=y || ret=2
      done < "${confdir}/ipv6_addr"

      if [ "${have_any}" = "y" ] && net_setup_config_read_entry ipv6_gw; then
         net_iface_set_ipv6_gw ${v0} || ret=2
      fi
   fi

   if [ -f "${confdir}/dns" ]; then
      while read -r line; do
         net_setup_config_globals_append dns "${line}"
      done < "${confdir}/dns"
   fi
}

# @net_ifdown common net_ifdown__common()
#
net_ifdown__common() {
   net_iface_flush_addr
   net_iface_down
}

# @net_ifup eth net_ifup__eth ( **X_NAMEIF=nameif )
#
net_ifup__eth() {
   local v0

   if net_setup_config_read_entry nameif; then
      if [ -e "/sys/class/net/${iface}" ]; then
         net_setup_log_warn "interface ${iface} exists - skipping nameif"
      else
         net_setup_log_info "calling for interface ${iface} mac ${v0}"
         if ${X_NAMEIF:-nameif} "${iface}" "${v0}"; then
            net_setup_log_debug "nameif succeeded"
         else
            net_setup_log_error "failed to get interface ${iface} (nameif)"
            return 10
         fi
      fi
   fi

   net_iface_up       || return
   net_ifup__common   || ret=${?}
   net_setup__set_wol || true

   return 0
}



# @net_ifdown eth net_ifdown__eth()
#
net_ifdown__eth() {
   net_ifdown__common || ret=${?}
   net_setup__set_wol || true
}
