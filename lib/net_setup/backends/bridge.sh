#@namespace bridge
#@section functions

# int brctl__cmd ( *argv, **X_BRCTL=brctl )
#
brctl__cmd() {
   ${X_BRCTL:-brctl} "$@"
}

check_is_bridge() {
   [ -d "/sys/class/net/${1:-${iface}}/bridge" ]
}


# int bridge_add_slaves ( *slaves, **iface )
#
bridge_add_slaves() {
   local v0 dev slaves=

   check_is_bridge || return 2

   for dev; do
      case "${dev}" in
         '')
            true
         ;;
         '@all')
            get_eth_devices
            slaves="${v0}"
            break
         ;;
         '@'*)
            net_setup_log_error "bridge_add_slaves: unknown reference ${1}"
            return 20
         ;;
         *)
            slaves="${slaves-} ${dev}"
         ;;
      esac
   done

   net_setup_log_info "${iface}: adding bridge interfaces ${slaves}"
   for dev in ${slaves}; do
      brctl__cmd addif "${iface}" "${dev}" || return 1
   done
}

# int bridge_get_slaves ( **iface, **v0! )
#
bridge_get_slaves() {
   v0=
   check_is_bridge || return 2
   local k

   for k in "/sys/class/net/${iface}/brif/"*; do
      [ ! -s "${k}" ] || v0="${v0} ${k##*/}"
   done

   v0="${v0# }"
   [ -n "${v0}" ]
}


# int bridge_del_slaves ( ifdown_slaves=y, **iface )
#
bridge_del_slaves() {
   local v0 k
   bridge_get_slaves || return

   for k in ${v0}; do
      if brctl__cmd delif "${iface}" "${k}"; then
         [ "${1:-y}" != "y" ] || net_ifdown "${k}"
      else
         ret=3
      fi
   done

   return ${ret}
}


net_ifup__bridge() {
   local dev slaves
   check_is_bridge || brctl__cmd addbr "${iface}" || return 1

   for dev in "${confdir}/slaves/"*; do
      if [ -e "${dev}" ] || [ -h "${dev}" ]; then
         slaves="${slaves-} ${dev##*/}"
      fi
   done

   bridge_add_slaves ${slaves} && net_ifup__common
}

net_ifdown__bridge() {
   check_is_bridge || return 2
   bridge_del_slaves y
   brctl__cmd delbr "${iface}"
}
