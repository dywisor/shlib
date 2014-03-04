#@section vars
: ${X_HDPARM:=hdparm}

#@section functions

# @extern shbool get_disk_status ( dev, **v0! )
# @extern shbool disk_is_active ( dev, **v0! )

# int hardware_policy_run_hdparm ( *argv )
#
hardware_policy_run_hdparm() {
   ${X_HDPARM} "$@" 1>/dev/null 2>/dev/null
}

# int hardware_policy_disk_set_apm ( value, **dev )
#
hardware_policy_disk_set_apm() {
   hardware_policy_dont_keep "${1}" || return 0
   hardware_policy_run_hdparm -B "${1}" "${dev}"
}

# int hardware_policy_disk_set_spindown ( value, **dev )
#
hardware_policy_disk_set_spindown() {
   hardware_policy_dont_keep "${1}" || return 0
   hardware_policy_run_hdparm -S "${1}" "${dev}"
}

# int hardware_policy_disk_set_scheduler ( value, **dev )
#
hardware_policy_disk_set_scheduler() {
   hardware_policy_dont_keep "${1}" || return 0
   dofile_if "/sys/block/${dev##*/}/queue/scheduler" "${1}"
}

# int hardware_policy_disk_set_ncq ( value, **dev )
#
hardware_policy_disk_set_ncq() {
   hardware_policy_dont_keep "${1}" || return 0
   local val

   if [ "${1}" -gt 0 2>/dev/null ]; then
      val="${1}"
   elif [ "${1}" = "0" ] || ! yesno "${1}"; then
      val="1"
   else
      val="31"
   fi

   dofile_if "/sys/block/${dev##*/}/device/queue_depth" "${val}"
}

# int hardware_policy_disk_do_apply (
#    **dev, **apm, **spindown, **scheduler, **ncq, **no_wakeup,
#    **skip_pwr_if_ssd=n
# )
#
hardware_policy_disk_do_apply() {
   if yesno "${no_wakeup:-n}"; then
      case "${dev##*/}" in
         [sh]d*)
            disk_is_active "${dev}" || return 0
         ;;
      esac
   fi

   if \
      ! yesno "${skip_pwr_if_ssd:-n}" || \
      [ "x$(cat /sys/block/${dev##*/}/queue/rotational 2>/dev/null)" != "x0" ]
   then
      hardware_policy_disk_set_apm      "${apm-}"
      hardware_policy_disk_set_spindown "${spindown-}"
   fi
   hardware_policy_disk_set_scheduler "${scheduler-}"
   hardware_policy_disk_set_ncq       "${ncq-}"
}

# int hardware_policy_disk_set_from_file ( config_file, dev, *disk_id )
#
hardware_policy_disk_set_from_file() {
   local cfile="${1:?}"
   local dev="${2:?}"
   shift 2 || return
   if [ ! -b "${dev}" ]; then
      ewarn "disk device ${dev} does not exist."
      return 5
   fi

   local disk_id apm spindown scheduler ncq no_wakeup DONT_CARE
   local skip_pwr_if_ssd

   while read -r disk_id apm spindown scheduler ncq no_wakeup DONT_CARE; do
      case "${disk_id-}" in
         ''|'@'|'#'*|'!'*)
            true
         ;;
         '@any'|'@ANY')
            # setting apm causes a significant loss of performance
            # for some ssds (e.g. Crucial M4)

            #last_resort="..."
            skip_pwr_if_ssd=y
            hardware_policy_disk_do_apply
            #no break;
         ;;
         *)
            # accept wildcards in %disk_id
            if fnmatch_any "${disk_id}" "$@"; then
               skip_pwr_if_ssd=n
               hardware_policy_disk_do_apply
               break
            fi
         ;;
      esac
   done < "${cfile}"

   return 0
}
