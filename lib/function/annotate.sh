OVERRIDE_FUNCTION() {
   if function_defined "${1:?}"; then
      unset -f "${1}"
      return 0
   else
      die "@override: function ${1} is not defined and thus cannot be overridden."
   fi
}
FOVERWRITE() { OVERRIDE_FUNCTION "$@"; }

DONT_OVERRIDE_FUNCTION() {
   if function_defined "${1:?}"; then
      die "@dont-override: function ${1} is already defined."
   else
      return 0
   fi
}
NOT_OVERRIDING() { DONT_OVERRIDE_FUNCTION "$@"; }
