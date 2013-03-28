SCRIPT_MODE="${SCRIPT_NAME#md_}"

F_MD_FOREACH_MEMBER_ONERROR=true

case "${SCRIPT_MODE}" in
   sleep|standby)
      md_foreach_member "${1-}" hdparm -Y
   ;;
   check)
      md_foreach_member "${1-}" hdparm -C
   ;;
   smart|smartcl)
      md_foreach_member "${1-}" smartctl -HAi -q noserial
   ;;
   each|foreach)
      md_foreach_member "$@"
   ;;
   *)
      die "unknown script mode '${SCRIPT_MODE}'."
   ;;
esac
