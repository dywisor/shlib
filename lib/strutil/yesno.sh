#@section functions

# int yesno ( word )
#
#  Returns:
#  * YESNO_YES   (0) if word means yes
#  * YESNO_EMPTY (2) if word is empty
#  * YESNO_NO    (1) otherwise (word is not empty and does not mean yes)
#
yesno() {
   case "${1-}" in
      '')
         return ${YESNO_EMPTY:-2}
      ;;
      # yes | y | true | 1 | enable(d) | on
      [yY][eE][sS]|\
      [yY]|\
      [tT][rR][uU][eE]|\
      1|\
      [eE][nN][aA][bB][lL][eE]?|\
      [oO][nN]\
      )
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
   local rc=0
   yesno "$@" || rc=$?

   [ ${rc} -eq ${YESNO_NO:-1} ] || return ${rc}

   case "${1-}" in
      # no | n | false | 0 | disable(d) | off
      [nN][oO]|\
      [nN]|\
      [fF][aA][lL][sS][eE]|\
      0|\
      [dD][iI][sS][aA][bB][lL][eE]?|\
      [oO][fF][fF]\
      )
         return ${YESNO_NO:-1}
      ;;
      *)
         return ${YESNO_UNDEF:-3}
      ;;
   esac
}
