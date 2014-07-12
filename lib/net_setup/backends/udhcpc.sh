#@namespace udhcpc

#@section vars

: ${UDHCPC_RETRY_COUNT:=3}
: ${UDHCPC_TIMEOUT:=3}
: ${UDHCPC_RETRY_DELAY:=1}
: ${UDHCPC_SCRIPT=}

#@section functions

udhcpc__cmd() {
   ${X_UDHCPC:-busybox udhcpc} "${@}"
}

# udhcpc__add_opts ( **opts! )
#
udhcpc__add_opts() {
   : ${opts=}
   [ -z "${UDHCPC_RETRY_COUNT-}" ] || opts="${opts} -t ${UDHCPC_RETRY_COUNT}"
   [ -z "${UDHCPC_TIMEOUT-}"     ] || opts="${opts} -T ${UDHCPC_TIMEOUT}"
   [ -z "${UDHCPC_RETRY_DELAY-}" ] || opts="${opts} -A ${UDHCPC_RETRY_DELAY}"

   if [ -n "${UDHCPC_SCRIPT-}" ]; then
      opts="${opts} -S ${UDHCPC_SCRIPT}"
   fi

   opts="${opts# }"
}

udhcpc_dodhcp() {
   local opts=
   udhcpc__add_opts
   udhcpc__cmd -f -q -i ${iface} ${opts}
}


#@section module_init_vars
NET_SETUP_DHCP_BACKENDS="${NET_SETUP_DHCP_BACKENDS-} udhcpc"
