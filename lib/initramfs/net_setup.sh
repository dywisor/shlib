#@section functions

# int initramfs_net_setup (
#    command, **CMDLINE_NET_CONFIG=**INITRAMFS_NET_CONFIG,
#    **INITRAMFS_HAVE_NET?!, **v0!
# )
#
initramfs_net_setup() {
   local conf

   case "${1-}" in
      up)
         if [ "${INITRAMFS_HAVE_NET:-n}" = "y" ]; then
            dolog_warn "networking is already configured."
            return 0
         else
            conf="${CMDLINE_NET_CONFIG:-${INITRAMFS_NET_CONFIG-}}"
            if [ -n "${conf}" ] && [ "${conf}" != "null" ]; then
               net_setup /tmp/initramfs_netconfig.$$ "${conf}" && \
                  INITRAMFS_HAVE_NET=y
            else
               initramfs_die "no network config available."
            fi
         fi
      ;;
      down)
         if [ "${INITRAMFS_HAVE_NET:-n}" = "y" ]; then
            net_ifdown_all && INITRAMFS_HAVE_NET=n
         else
            dolog_warn "networking has already been brought down."
            return 0
         fi
      ;;
      *)
         initramfs_die "initramfs_net_setup: unknown command ${1-}"
      ;;
   esac
}
