# This module is heavily inspired by linrunner's TLP [0]. It does not,
# however, try to reimplement TLP nor provide its entire feature set.
# Instead, this module is targeted at use for home servers (and other
# "static" machines).
#
# It currently offers the following functionality:
#
# * cpu   : TODO
# * disk  : set apm / spindown / scheduler / ncq
# * hacks : apply "hardware hacks",
#            e.g. disable polling in drm_kms_helper (useful for i915)
# * pcie  : set pcie aspm
# * sata  : set sata link power
# * sound : set power_save / power_save_controller
# * usb   : set autosuspend / timeout for non-HID devices
#
# [0] https://github.com/linrunner/TLP
#
#
# Note:
#  The 'disk' policy expects a linelist of disk entries (one entry per line),
#   where disk_entry := disk_id [apm [spindown [scheduler [ncq [no_wakeup]]]]]
#   -> disk_id: disk id taken from /dev/disk/by-id/
#   -> apm / spindown / scheduler / ncq:
#       optional, either a value or "keep" (= dont change)
#   -> no_wakeup: optional (defaults to "n"),
#       don't apply settings to a disk if it is in standby/sleep mode
#
#     Technical note:
#       disk in standby/sleep mode <=> disk is not active/idle and not faking,
#        so disks with unknown status will be skipped, too
#


# void hardware_policy_depcheck(), raises die()
#
#  Verifies that required programs are available.
#
hardware_policy_depcheck() {
   depcheck hdparm readlink
}

# void hardware_policy__die ( [message], [code] )
#
#  die() wrapper.
#
hardware_policy__die() {
   if [ -n "${1-}" ]; then
      die "hardware policy '${policy?}': ${1}" "${2:-20}"
   else
      die "hardware policy '${policy?}'." "${2:-21}"
   fi
}

# int hardware_policy__writeval ( file, **val )
#
hardware_policy__writeval() {
   runcmd dofile_if "${1}" "${val?}"
}

# int hardware_policy__dofiles ( val, *file )
#
#  Write val into files.
#
hardware_policy__dofiles() {
   local val="${1}"; shift
   fs_foreach_file_do hardware_policy__writeval "$@"
}

# int hardware_policy_dont_keep ( word )
#
#  Returns 1 if word is "keep" (case-insensitive), 2 if word is empty and
#  0 otherwise.
#
hardware_policy_dont_keep() {
   case "$*" in
      [kK][eE][eE][pP])
         return 1
      ;;
      '')
         return 2
      ;;
      *)
         return 0
      ;;
   esac
}

# void hardware_policy__cpu ( cpu_dir, **??? )
#
hardware_policy__cpu() {
   case "${1##*/}" in
      *[0-9])
         cpucount=$(( ${cpucount?} + 1 ))
      ;;
   esac
   #eerror "hardware_policy_cpu_policy(): not implemented."
}

# void hardware_policy_cpu_policy ( ??? )
#
hardware_policy_cpu_policy() {
   local cpucount=0
   fs_foreach_dir_do hardware_policy__cpu /sys/devices/system/cpu/cpu?*
   if [ ${cpucount} -gt 7 ]; then
      ewarn "(cpu policy is TODO)" "\"EIGHT CORES?\" - \"OF CORES!\""
   else
      ewarn "hardware_policy_cpu_policy(): not implemented."
   fi
}

# void hardware_policy_usb_policy ( policy=auto, timeout_ms=3000, timeout_s=3 )
#
#  Sets USB autosuspend and timeout.
#
hardware_policy_usb_policy() {
   set -- "${1:-auto}" "${2:-3000}" "${3:-3}"
   local dev p subdev control

   for dev in /sys/bus/usb/devices/*; do
      p="${dev}/power"

      if [ "x${dev##*:}" != "x${dev}" ]; then
         true
      elif \
         [ -e "${p}/autosuspend" ] || [ -e "${p}/autosuspend_delay_ms" ]
      then
         control="${1}"
         for subdev in "${dev}/"*:*; do
            if \
               [ -e "${subdev}" ] && \
               [ "$(cat ${subdev}/bInterfaceClass)" = "03" ]
            then
               # don't mess around with HID devices
               control=on
               break 1
            fi
         done

         runcmd dofile_if "${p}/control" "${control}"
         ## checking each autosuspend file twice here...
         if [ -e "${p}/autosuspend_delay_ms" ]; then
            runcmd dofile_if "${p}/autosuspend_delay_ms" "${2}"
         elif [ -e "${p}/autosuspend" ]; then
            runcmd dofile_if "${p}/autosuspend" "${3}"
         fi
      fi
   done
   return 0
}

# void hardware_policy__disk (
#    id=, apm=, spindown=, iosched=, ncq=, no_wakeup=n
# )
#
hardware_policy__disk() {
   local id="${1-}"
   [ -n "${id}" ] || return 0

   local v0

   local disk="/dev/disk/by-id/${id}"
   if [ -e "${disk}" ]; then
      local dev=$(readlink -f "${disk}")
   else
      local dev=
   fi
   local sysblock="/sys/block/${dev##*/}"

   if [ -z "${dev}" ]; then
      ewarn "disk '${id}' not found."

   elif \
      [ ! -e "${disk}" ] || [ ! -b "${dev}" ] || [ ! -e "${sysblock}" ]
   then
      ewarn "disk '${id}' not found. (dev='${dev}'?)"

   elif \
      YESNO_YES=1 YESNO_NO=0 yesno "${6:-n}" || \
      __faking__ || disk_is_active "${dev}"
   then
      ## %no_wakeup is "no" or faking or %dev active
      local hdparm="runcmd_nostdout hdparm"

      # apm
      if hardware_policy_dont_keep ${2-}; then
         ${hdparm} -B "${2}" "${dev}"
      fi

      # spindown
      if hardware_policy_dont_keep ${3-}; then
         ${hdparm} -S "${3}" "${dev}"
      fi

      # scheduler
      if hardware_policy_dont_keep ${4-}; then
         runcmd dofile_if "${sysblock}/queue/scheduler" "${4}"
      fi

      # ncq
      if hardware_policy_dont_keep ${5-}; then
         local q="${sysblock}/device/queue_depth"

         if [ "${5}" -gt 0 2>/dev/null ]; then
            runcmd dofile_if "${q}" "${ncq}"
         elif [ "${5}" = "0" ] || ! yesno "${ncq}"; then
            runcmd dofile_if "${q}" "1"
         else
            runcmd dofile_if "${q}" "31"
         fi
      fi

   else
      ## some settings could be applied when the disk is not active
      einfo "skipping disk '${id}', dev '${dev}': not active."
   fi
   return 0
}

# int hardware_policy ( policy, *argv )
#
#  main function that applies the requested policy (using the given args).
#
hardware_policy() {
   local policy="${1:?}"; shift
   local f=hardware_policy_${policy}_policy

   local \
      DOFILE_WARN_MISSING=y \
      F_ITER_ON_ERROR=hardware_policy__die \
      ITER_SKIP_EMPTY=y \
      ITER_UNPACK_ITEM=y

   if function_defined "${f}"; then
      ${f} "$@"
   else
      case "${policy}" in
         'disk')
            # argv := *disk_policy
            F_ITER=hardware_policy__disk line_iterator "$@"
         ;;
         'sata'|'sata_linkpower')
            # argv := link_power
            if hardware_policy_dont_keep "${1-}"; then
               hardware_policy__dofiles "${1}" \
                  /sys/class/scsi_host/host?*/link_power_management_policy
            fi
         ;;
         'pcie'|'pcie_aspm')
            # argv := pcie_aspm
            if hardware_policy_dont_keep "${1-}"; then
               runcmd_nostderr dofile_if \
                  /sys/module/pcie_aspm/parameters/policy "${1}" || \
                  ewarn "cannot set pcie aspm policy!"
            fi
         ;;
         'sound'|'snd')
            # argv := power_save, power_save_controller
            if hardware_policy_dont_keep "${1-}"; then
               hardware_policy__dofiles "${1}" \
                  /sys/module/snd_*/parameters/power_save
            fi

            if hardware_policy_dont_keep "${2-}"; then
               if yesno "${2}"; then
                  hardware_policy__dofiles "Y" \
                     /sys/module/snd_*/parameters/power_save_controller
               else
                  hardware_policy__dofiles "N" \
                     /sys/module/snd_*/parameters/power_save_controller
               fi
            fi
         ;;
         'hacks')
            # argv := *hacks:=auto
            [ -n "$*" ] || set -- auto

            local hack
            for hack in $*; do
               [ "x${hack}" = "xnone" ] || hardware_hacks_${hack}
            done
         ;;
         *)
            die "no such policy: ${1}"
         ;;
      esac
   fi || hardware_policy__die
}
