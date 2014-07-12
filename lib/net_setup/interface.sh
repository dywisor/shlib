#@section functions

# int net_setup__check_backend_supported ( backend_type, name, backends )
#
net_setup__check_backend_supported() {
   if list_has "${2:?}" ${3?}; then
      return 0
   else
      net_setup_log_error \
         "unknown/unsupported net ${1:-%UNDEF%} backend '${2-}'"
      return 1
   fi
}


net_setup_set_iface_backend() {
   net_setup__check_backend_supported iface \
      "${1:?}" "${NET_SETUP_IFACE_BACKENDS?}" && \
   __NET_SETUP_IFACE_BACKEND="${1}"
}

net_setup_set_dhcp_backend() {
   net_setup__check_backend_supported dhcp \
      "${1:?}" "${NET_SETUP_DHCP_BACKENDS?}" && \
   __NET_SETUP_DHCP_BACKEND="${1}"
}

net_setup_set_dhcp6_backend() {
   net_setup__check_backend_supported dhcp \
      "${1:?}" "${NET_SETUP_DHCP6_BACKENDS?}" && \
   __NET_SETUP_DHCP_BACKEND="${1}"
}

net_setup_set_default_iface_backend() {
   net_setup_set_iface_backend iproute2
}

net_setup_set_default_dhcp_backend() {
   net_setup_set_dhcp_backend udhcpc
}

net_setup_set_default_dhcp6_backend() {
   net_setup_set_dhcp_backend udhcpc6
}

# int net_iface_dodhcp ( **iface )
#
net_iface_dodhcp() {
   net_setup_log_info "Running dhcp for interface ${iface}"

   if ${__NET_SETUP_DHCP_BACKEND:?}_dodhcp "$@"; then
      return 0
   else
      net_setup_log_error \
         "failed to get an address via dhcp for interface ${iface}"
      return 1
   fi
}

# int net_iface_dodhcp6 ( **iface )
#
net_iface_dodhcp6() {
   net_setup_log_info "Running dhcp6 for interface ${iface}"

   net_setup_log_error "dhcp6 is not implemented."
   return 1
}


# int net_iface_up ( **iface )
#
net_iface_up() {
   net_setup_log_info "Bringing up interface ${iface}"

   if ${__NET_SETUP_IFACE_BACKEND:?}_up "$@"; then
      return 0
   else
      net_setup_log_error "failed to bring up interface ${iface}"
      return 1
   fi
}

# int net_iface_down ( **iface )
#
net_iface_down() {
   net_setup_log_info "Bringind down interface ${iface}"

   if ${__NET_SETUP_IFACE_BACKEND:?}_down "$@"; then
      return 0
   else
      net_setup_log_error "failed to bring down interface ${iface}"
      return 1
   fi
}

# int net_iface_flush_addr ( **iface )
#
net_iface_flush_addr() {
   net_setup_log_debug "${iface}: flushing addresses"

   if ${__NET_SETUP_IFACE_BACKEND:?}_flush_addr "$@"; then
      return 0
   else
      net_setup_log_error "${iface} failed to flush addresses"
      return 1
   fi
}

# int net_iface_add_ipv4_addr ( addr/netmask, broadcast=, ..., **iface )
#
net_iface_add_ipv4_addr() {
   net_setup_log_info "${iface}: adding ipv4 address ${*}"

   if ${__NET_SETUP_IFACE_BACKEND:?}_add_ipv4_addr "$@"; then
      return 0
   else
      net_setup_log_error "${iface}: failed to add ipv4 address ${*}"
      return 1
   fi
}

# int net_iface_set_ipv4_gw ( gw, **iface )
#
net_iface_set_ipv4_gw() {
   net_setup_log_info "${iface}: setting default ipv4 route via ${*}"

   if ${__NET_SETUP_IFACE_BACKEND:?}_set_ipv4_gw "$@"; then
      return 0
   else
      net_setup_log_error "${iface}: failed to set ipv4 gatewa ${*}"
      return 1
   fi
}

# int net_iface_add_ipv6_addr ( addr/netmask, ..., **iface )
#
net_iface_add_ipv6_addr() {
   net_setup_log_info "${iface}: adding ipv6 address ${*}"

   if ${__NET_SETUP_IFACE_BACKEND:?}_add_ipv6_addr "$@"; then
      return 0
   else
      net_setup_log_error "${iface}: failed to add ipv6 address ${*}"
      return 1
   fi
}

# int net_iface_set_ipv6_gw ( gw, **iface )
#
net_iface_set_ipv6_gw() {
   net_setup_log_info "${iface}: setting default ipv6 route via ${*}"

   if ${__NET_SETUP_IFACE_BACKEND:?}_set_ipv6_gw "$@"; then
      return 0
   else
      net_setup_log_error "${iface}: failed to set ipv6 gateway ${*}"
      return 1
   fi
}

# int net_iface_is_admin_up ( iface=**iface )
#
net_iface_is_admin_up() {
   ${__NET_SETUP_IFACE_BACKEND:?}_is_admin_up "$@"
}

# int net_iface_is_oper_up ( iface=**iface )
#
net_iface_is_oper_up() {
   ${__NET_SETUP_IFACE_BACKEND:?}_is_oper_up "$@"
}
