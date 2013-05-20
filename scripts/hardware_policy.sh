#readconfig /etc/${SCRIPT_NAME}.conf
readconfig /etc/hardware-policy.conf

case "${1-}" in
   '--dry-run'|'-n')
      FAKE_MODE=y
   ;;
esac

# void hwpol_flag_rename ( **flag )
#
hwpol_flag_rename() {
   case "${flag?}" in
      'sata_linkpower')
         flag=sata
      ;;
      'pcie_aspm')
         flag=pcie
      ;;
      'sound')
         flag=snd
      ;;
   esac
}

# ~int run_policy ( policy, *argv )
#
run_policy() {
   if use "${1:?}"; then
      hardware_policy "$@" && ANY_POLICY="${1}"
   fi
}

USE_PREFIX=hwpol
F_USE_RENAME_FLAG=hwpol_flag_rename

set_use ${POLICIES-}

hardware_policy_depcheck

run_policy disk  "${DISK_POLICY-}"
run_policy sata  "${SATA_LINKPWR-}"
run_policy usb   "${USB_POLICY-}" "${USB_TIMEOUT_MS-}" "${USB_TIMEOUT-}"
run_policy pcie  "${PCIE_ASPM-}"
run_policy hacks "${HARDWARE_HACKS-}"
run_policy snd   "${SND_POWERSAVE-}" "${SND_POWERSAVE_CONTROLLER-}"
run_policy cpu

[ -n "${ANY_POLICY-}" ] || ewarn "This script did nothing!"
