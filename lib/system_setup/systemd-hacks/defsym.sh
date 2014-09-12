#@section const
readonly SYSTEMD_HACKS_HLINE="\
------------------------------------------------------------------------------"

readonly __SYSTEMD_HACKS_DEFAULT_TARGET="multi-user"

readonly EX_NO_SUCH_UNIT=128

#@section vars
: ${SYSTEMD_LIBDIR:=/usr/lib/systemd}
: ${SYSTEMD_CONFDIR:=/etc/systemd}
: ${SYSTEMD_HACKS_DEFAULT_TARGET:=${__SYSTEMD_HACKS_DEFAULT_TARGET:?}}


#@section functions
__systemd_hacks_set_default_target() {
   : ${SYSTEMD_HACKS_DEFAULT_TARGET:=${__SYSTEMD_HACKS_DEFAULT_TARGET:?}}
}

systemd_hacks_set_default_target() {
   case "${1-}" in
      '')
         __systemd_hacks_set_default_target
      ;;
      ?*.target)
         SYSTEMD_HACKS_DEFAULT_TARGET="${1%.target}"
      ;;
      .target)
         return 5
      ;;
      *)
         SYSTEMD_HACKS_DEFAULT_TARGET="${1}"
      ;;
   esac
}
