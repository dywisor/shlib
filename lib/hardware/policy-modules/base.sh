#@section functions

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
