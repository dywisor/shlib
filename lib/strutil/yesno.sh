#@section functions

# int word_is_yes ( word )
#
#  Returns 0 if %word means "yes", else 1.
#
word_is_yes() {
   case "${1-}" in
      # yes | y | true | 1 | enable(d) | on
      [yY][eE][sS]|\
      [yY]|\
      [tT][rR][uU][eE]|\
      1|\
      [eE][nN][aA][bB][lL][eE]?|\
      [oO][nN]\
      )
         return 0
      ;;
   esac
   return 1
}

# int word_is_no ( word )
#
#  Returns 0 if %word means "no", else 1.
#
word_is_no() {
   case "${1-}" in
      # no | n | false | 0 | disable(d) | off
      [nN][oO]|\
      [nN]|\
      [fF][aA][lL][sS][eE]|\
      0|\
      [dD][iI][sS][aA][bB][lL][eE]?|\
      [oO][fF][fF]\
      )
         return 0
      ;;
   esac
   return 1
}

# int yesno ( word )
#
#  Returns:
#  * YESNO_YES   (0) if word means yes
#  * YESNO_EMPTY (2) if word is empty
#  * YESNO_NO    (1) otherwise (word is not empty and does not mean yes)
#
yesno() {
   if [ -z "${1-}" ]; then
      return ${YESNO_EMPTY:-2}
   elif word_is_yes "${1}"; then
      return ${YESNO_YES:-0}
   else
      return ${YESNO_NO:-1}
   fi
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
   if [ -z "${1-}" ]; then
      return ${YESNO_EMPTY:-2}
   elif word_is_yes "${1}"; then
      return ${YESNO_YES:-0}
   elif word_is_no "${1}"; then
      return ${YESNO_NO:-1}
   else
      return ${YESNO_UNDEF:-3}
   fi
}
