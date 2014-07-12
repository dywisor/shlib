#@HEADER
#
# network configuration for basic setups (e.g. for initramfs)
#
# Is able to set up wired and bridged networking (addr/gw/dns).
#

# @section module_init_vars
: ${__NET_SETUP_IFACE_BACKEND:=iproute2}
: ${__NET_SETUP_DHCP_BACKEND:=udhcpc}
: ${__NET_SETUP_DHCP6_BACKEND:=}

#@section functions

net_setup_print_gateway_addresses() {
   local f
   local addr DONT_CARE

   for f in \
      "${confdir}/ipv4_gw" "${confdir}/ipv6_gw"
   do
      if \
         [ -s "${f}" ] && read -r addr DONT_CARE < "${f}" && [ -n "${addr}" ]
      then
         echo "${addr}"
      fi
   done
}

net_setup_fixup__dns() {
   [ -f "${confdir}/dns" ] || return 0
   local entry do_replace have_entries

   do_replace=n
   have_entries=n

   : > "${confdir}/dns.next" || return

   while read -r entry; do
      case "${entry}" in
         '')
            true
         ;;

         '@none'|'@nil'|'@nop'|'@null'|'@')
            have_entries=y
            do_replace=y
         ;;

         '@gw')
            net_setup_print_gateway_addresses > "${confdir}/dns.next"
            have_entries=y
            do_replace=y
         ;;

         '@'*)
            net_setup_log_error "unknown dns entry ref '${entry}'"
            do_replace=y
         ;;

         *)
            have_entries=y
            echo "${entry}" > "${confdir}/dns.next"
         ;;
      esac
   done < "${confdir}/dns"

   # let dns default to the gateway's address(es)
   if [ "${have_entries}" != "y" ]; then
      net_setup_print_gateway_addresses > "${confdir}/dns.next"
      do_replace=y
   fi

   if [ "${do_replace}" = "y" ]; then
      mv -f -- "${confdir}/dns.next" "${confdir}/dns"
   fi
}

net_setup_fixup__confdir() {
   local confdir iface
   confdir="${1?}"
   iface="${2?}"

   net_setup_fixup__dns
}

net_setup_fixup() {
   net_setup_config_foreach_device_path net_setup_fixup__confdir
}

net_setup_dns() {
   local dnsf="${NET_SETUP_CONFIG_ROOT:?}/globals/dns"

   if [ -f "${dnsf}" ]; then
      net_setup_log_info "Setting dns config"
      # -s $dnsf is always true,
      # empty entries are discarded when creating this file
      #[ -s "${dnsf}" ] || net_setup_log_warn "dns config file is empty"
      if [ -e "/etc/resolv.conf" ] || [ -h "/etc/resolv.conf" ]; then
         mv -f -- /etc/resolv.conf /etc/resolv.conf.bak
      else
         ${AUTODIE_NONFATAL-} dodir_clean /etc || return
      fi
      cp -f -- "${dnsf}" /etc/resolv.conf
   else
      net_setup_log_warn "no dns servers configured."
      return 0
   fi
}


net_setup() {
   if [ -n "${1+SET}" ]; then
      if [ -n "${1}" ]; then
         net_setup_set_config_root "${1}" && \
         net_setup_wipe_config_root && \
         net_setup_init_config_root || return
      fi
      shift
   fi
   : ${NET_SETUP_CONFIG_ROOT:?}

   net_setup_parse "$@" || return
   net_setup_fixup

   rm -f -- "${NET_SETUP_CONFIG_ROOT:?}/globals/dns"
   net_ifup_all && net_setup_dns
}
