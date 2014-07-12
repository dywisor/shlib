#@section functions

net_setup_parser_debug() {
   dolog +net_setup +parser "$@" --level=DEBUG
}

net_setup_parser_warn() {
   dolog +net_setup +parser "$@" --level=WARN
}

net_setup_parser_error() {
   dolog +net_setup +parser "$@" --level=ERROR
}

net_setup_parser_dolog_need_val() {
   net_setup_parser_error "option '${1-X}' needs a value."
}


# @private int net_setup_parser__parse_common_opt (
#    opt, value=, **config_root, **confdir, **iface, **fail!
# )
net_setup_parser__parse_common_opt() {
   case "${1}" in
      ignore)
         net_setup_config_write ignore "${2:-y}"
      ;;

      dns)
         if [ -n "${2+SET}" ]; then
            case "${2}" in
               '')
                  net_setup_parser_debug "${iface}/dns: remove"
                  net_setup_config_write dns ""
               ;;
               *)
                  net_setup_parser_debug "${iface}/dns: add ${2}"
                  net_setup_config_append dns "${2}"
               ;;
            esac
         else
            net_setup_parser_dolog_need_val "${1}"
            fail=$(( ${fail} + 1 ))
         fi
      ;;

      dhcp)
         net_setup_parser_debug "${iface}/ipv4_dhcp: ${2:-y}"
         net_setup_config_write ipv4_dhcp "${2:-y}"
      ;;

      ip|addr)
         if [ -n "${2+SET}" ]; then
            case "${2}" in
               '')
                  net_setup_parser_debug "${iface}/ipv4_addr: remove"
                  net_setup_config_write ipv4_addr ""
               ;;
               'auto'|'dhcp')
                  net_setup_parser_debug "${iface}/ipv4_dhcp: y"
                  net_setup_config_write ipv4_dhcp y
               ;;
               [0-9]*.?*.?*.?*/?*)
                  net_setup_parser_debug "${iface}/ipv4_addr: add ${2}"
                  net_setup_config_append ipv4_addr "${2}"
               ;;
               [0-9]*.?*.?*.?*)
                  net_setup_parser_debug "${iface}/ipv4_addr: add ${2}/24"
                  net_setup_config_append ipv4_addr "${2}/24"
               ;;
               *)
                  net_setup_parser_error "${2} is not an ipv4 address"
                  fail=$(( ${fail} + 1 ))
               ;;
            esac
         else
            net_setup_parser_dolog_need_val "${1}"
            fail=$(( ${fail} + 1 ))
         fi
      ;;

      gw|gateway|via)
         if [ -n "${2+SET}" ]; then
            net_setup_parser_debug "${iface}/ipv4_gw: set ${2}"
            net_setup_config_write ipv4_gw "${2}"
         else
            net_setup_parser_dolog_need_val "${1}"
            fail=$(( ${fail} + 1 ))
         fi
      ;;


      dhcp6)
         net_setup_parser_debug "${iface}/ipv6_dhcp: ${2:-y}"
         net_setup_config_write ipv6_dhcp "${2:-y}"
      ;;

      ip6|addr6)
         if [ -n "${2+SET}" ]; then
            case "${2}" in
               '')
                  net_setup_parser_debug "${iface}/ipv6_addr: remove"
                  net_setup_config_write ipv6_addr ""
               ;;
               'auto'|'dhcp'|'dhcp6')
                  net_setup_parser_debug "${iface}/ipv6_dhcp: y"
                  net_setup_config_write ipv6_dhcp y
               ;;
               *)
                  net_setup_parser_debug "${iface}/ipv6_addr: add ${2}"
                  net_setup_config_append ipv6_addr "${2}"
               ;;
            esac
         else
            net_setup_parser_dolog_need_val "${1}"
            fail=$(( ${fail} + 1 ))
         fi
      ;;
      gw6|gateway6|via6)
         if [ -n "${2+SET}" ]; then
            net_setup_parser_debug "${iface}/ipv6_gw: set ${2}"
            net_setup_config_write ipv6_gw "${2}"
         else
            net_setup_parser_dolog_need_val "${1}"
            fail=$(( ${fail} + 1 ))
         fi
      ;;

      *)
         # default return
         net_setup_parser_error "cannot handle option ${1}${2+=}${2-}"
         fail=$(( ${fail} + 1 ))
         return 1
      ;;
   esac
}


# @private int net_setup_parser__parse_bridge_opt (
#    opt, value=, **config_root, **confdir, **iface, **fail!
# )
#
net_setup_parser__parse_bridge_opt() {
   local slave syml

   case "${1}" in
      all|use_all)
         # alias to slaves=@${1#use_}
         if [ -n "${2-}" ]; then
            net_setup_parser_warn "option ${1} ignores value '${2}'"
         fi

         ${AUTODIE_NONFATAL-} dodir_clean "${confdir}/slaves"
         syml="${confdir}/slaves/@${1#use_}"

         if [ ! -e "${syml}" ] || [ -h "${syml}" ]; then
            net_setup_parser_debug "${iface}/slaves: add @${1#use_}"

            ${AUTODIE_NONFATAL-} rm -f -- "${syml}"
            ${AUTODIE_NONFATAL-} touch -- "${syml}"

         else
            net_setup_parser_debug "${iface}/slaves: no-add ${1#use_}"
         fi
      ;;

      slaves)
         if [ -n "${2+SET}" ]; then
            shift
            ${AUTODIE_NONFATAL-} dodir_clean "${confdir}/slaves"
            IFS="+:"
            for slave in ${*}; do
               IFS="${IFS_DEFAULT}"
               syml="${confdir}/slaves/${slave}"

               if [ ! -e "${syml}" ] || [ -h "${syml}" ]; then
                  net_setup_parser_debug "${iface}/slaves: add ${slave}"

                  case "${slave}" in
                     '@'*)
                        ${AUTODIE_NONFATAL-} rm -f -- "${syml}"
                        ${AUTODIE_NONFATAL-} touch -- "${syml}"
                     ;;
                     *)
                        # this symlink is possibly broken, which is OK
                        ${AUTODIE_NONFATAL-} ln -fs -- ../../${slave} "${syml}"
                     ;;
                  esac

               else
                  net_setup_parser_debug "${iface}/slaves: no-add ${slave}"
               fi
            done
            IFS="${IFS_DEFAULT}"
         else
            net_setup_parser_dolog_need_val "${1}"
            fail=$(( ${fail} + 1 ))
         fi
      ;;
      *)
         net_setup_parser__parse_common_opt "$@"
      ;;
   esac
}


# @private int net_setup_parser__parse_eth_opt (
#    opt, value=, **config_root, **confdir, **iface, **fail!
# )
#
net_setup_parser__parse_eth_opt() {
   case "${1}" in
      wol)
         net_setup_parser_debug "${iface}/wol: set ${2-g}"
         net_setup_config_write wol "${2-g}"
      ;;
      nameif|mac)
         if [ -n "${2+SET}" ]; then
            net_setup_parser_debug "${iface}/nameif: set ${2}"
            case "${2}" in
               ''|??:??:??:??:??:??)
                  true
               ;;
               *)
                  net_setup_parser_warn "${2} does not seem to be a valid mac address"
               ;;
            esac
            net_setup_config_write nameif "${2}"
         else
            net_setup_parser_dolog_need_val "${1}"
            fail=$(( ${fail} + 1 ))
         fi
      ;;
      *)
         net_setup_parser__parse_common_opt "$@"
      ;;
   esac
}

# int net_setup_parser__parse_options ( func, *argv[_packed], **confdir, **iface )
#
net_setup_parser__parse_options() {
   local fail=0
   local func="${1:?}"
   shift

   # unpack args
   IFS=",|"
   set -- ${*}
   IFS="${IFS_DEFAULT?}"

   while [ ${#} -gt 0 ]; do
      case "${1}" in
         '')
            true
         ;;
         ?*=*)
            ${func:?} "${1%%=*}" "${1#*=}"
         ;;
         *)
            ${func:?} "${1}"
         ;;
      esac
      shift
   done
   [ ${fail} -lt 256 ] || fail=255
   return ${fail}
}

net_setup_parse_any() {
   local iftype iface confdir

   case "${1-}" in
      eth)
         iftype=eth
         iface=eth0
      ;;
      eth[._]?*)
         iftype=eth
         iface="${1#eth?}"
      ;;
      bridge[._]?*)
         iftype=bridge
         iface="${1#bridge?}"
      ;;
      *)
         net_setup_parser_error "cannot parse spec='${1-}' argv='${2-}'"
         return 2
      ;;
   esac

   shift && net_setup_init_config_dir "${iftype}" "${iface}" || return

   net_setup_parser__parse_options \
      net_setup_parser__parse_${iftype}_opt "$@"
}

# int net_setup_parse ( *args )
#
net_setup_parse() {
   local fail=0

   while [ ${#} -gt 0 ]; do
      case "${1}" in
         '')
            true
         ;;
         ?*=*)
            net_setup_parse_any "${1%%=*}" "${1#*=}" || fail=$(( ${fail} + 1 ))
         ;;
         *)
            fail=$(( ${fail} + 1 ))
         ;;
      esac
      shift
   done

   [ ${fail} -lt 256 ] || fail=255
   return ${fail}
}
