#@namespace iproute2
#@section functions

# int iproute2__cmd ( *argv, **X_IP=ip )
#
iproute2__cmd() {
   ${X_IP:-ip} "$@"
}

# int iproute2_is_admin_up ( iface=**iface, **X_IP=ip )
#
iproute2_is_admin_up() {
   ${X_IP:-ip} link show dev "${1:-iface}" 2>/dev/null | grep -q -- '[<,]UP[,>]'
}

# int iproute2_is_oper_up ( iface=**iface )
#
iproute2_is_oper_up() {
   local operstate
   read operstate < "/sys/class/net/${1:-${iface}}/operstate"
   [ "${operstate}" = "up" ]
}

# int iproute2_up ( **iface )
#
iproute2_up() {
   iproute2__cmd link set dev "${iface}" up
}

# int iproute2_down ( **iface )
#
iproute2_down() {
   iproute2__cmd link set dev "${iface}" down
}

# int iproute2_add_ipv4_addr ( addr/netmask, broadcast="+", ..., **iface )
#
iproute2_add_ipv4_addr() {
   local broadcast="${2-+}"
   iproute2__cmd -4 addr add \
      "${1:?}" ${broadcast:+broadcast} ${broadcast} dev "${iface}"
}

# int iproute2_set_ipv4_gw ( gw, **iface )
#
iproute2_set_ipv4_gw() {
   iproute2__cmd -4 route replace default via "${1:?}" dev "${iface}"
}


# int iproute2_add_ipv6_addr ( addr/netmask, ..., **iface )
#
iproute2_add_ipv6_addr() {
   iproute2__cmd -6 addr add "${1:?}" dev "${iface}"
}

# int iproute2_set_ipv6_gw ( gw, **iface )
#
iproute2_set_ipv6_gw() {
   iproute2__cmd -6 route replace default6 via "${1:?}" dev "${iface}"
}


# void iproute2_flush_addr ( **iface )
#
iproute2_flush_addr() {
   iproute2__cmd addr flush dev "${iface}" scope global
   iproute2__cmd addr flush dev "${iface}" scope site
   if [ "${iface}" != "lo" ]; then
      iproute2__cmd addr flush dev "${iface}" scope host
   fi
   return 0
}


#@section module_init_vars
NET_SETUP_IFACE_BACKENDS="${NET_SETUP_IFACE_BACKENDS-} iproute2"
