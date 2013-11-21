#@section functions

# void chmod_normalize_mode ( mode, **v0! )
#
chmod_normalize_mode() {
   v0=""
   case "${1-}" in
      +x)
         v0="+rx"
      ;;
      =x)
         v0="=rx"
      ;;
      +=*)
         v0="+${1#+=}"; chmod_normalize_mode "${v0}"
      ;;
      -=*)
         v0="-${1#-=}"; chmod_normalize_mode "${v0}"
      ;;
      *)
         v0="${1-}"
      ;;
   esac
}
