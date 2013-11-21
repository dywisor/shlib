#@section functions

# int yesno ( word )
#
#  Returns:
#  * YESNO_YES   (0) if word means yes
#  * YESNO_EMPTY (2) if word is empty
#  * YESNO_NO    (1) otherwise (word is not empty and does not mean yes)
#
yesno() {
   [[ "${1-}" ]] || return ${YESNO_EMPTY:-2}
   case "${1^^}" in
      YES|Y|TRUE|1|ENABLE?|ON)
         return ${YESNO_YES:-0}
      ;;
      *)
         return ${YESNO_NO:-1}
      ;;
   esac
}

# int yesno_strict ( word )
#
#  Returns:
#  * YESNO_YES   (0) if word means yes
#  * YESNO_NO    (1) if word means no
#  * YESNO_EMPTY (2) if word is empty
#  * YESNO_UNDEF (3) if word means neither yes nor no
#
yesno_strict() {
   [[ "${1-}" ]] || return ${YESNO_EMPTY:-2}
   case "${1^^}" in
      YES|Y|TRUE|1|ENABLE?|ON)
         return ${YESNO_YES:-0}
      ;;
      NO|N|FALSE|0|DISABLE?|OFF)
         return ${YESNO_NO:-1}
      ;;
      *)
         return ${YESNO_UNDEF:-3}
      ;;
   esac
}
