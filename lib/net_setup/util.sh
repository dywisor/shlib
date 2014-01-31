#@section functions

# int get_eth_devices ( **v0! )
#
#  Scans /sys/class/net for wired network interfaces and stores their names
#  in %v0.
#
#  Returns 0 if one or more eth devices have been found, else 1.
#
get_eth_devices() {
   v0=
   local netcls sysif
   for netcls in /sys/class/net/?*/device/class; do
      if \
         [ "0x020000" = "$(cat ${netcls} 2>/dev/null)" ] && \
         [ ! -d "${netcls%/class}/ieee80211" ]
      then
         sysif="${netcls%/device/class}"
         v0="${v0} ${sysif##*/}"
      fi
   done
   v0="${v0# }"

   [ -n "${v0}" ]
}
