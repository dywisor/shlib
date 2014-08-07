#@section const

SYSTEMD_NSPAWN_UTIL_RE_IP_NETIF='^default\s+via\s+.*\s+dev\s+(\S+)'

#@section functions

# int get_systemd_nspawn_exe ( **X_SYSTEMD_NSPAWN=! )
#
get_systemd_nspawn_exe() {
   local v0

   qwhich_single ${X_SYSTEMD_NSPAWN:-systemd-nspawn} && \
   X_SYSTEMD_NSPAWN="${v0}"
}

# int systemd_nspawn_get_default_network_interface ( **v0!, **X_IP=ip )
#
systemd_nspawn_get_default_network_interface() {
   v0="$(ip route show | \
      sed -nr -e "s,${SYSTEMD_NSPAWN_UTIL_RE_IP_NETIF},\1,p" | \
      tail -n 1)"
   [ -n "${v0}" ]
}
