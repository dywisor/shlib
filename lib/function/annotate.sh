#@section funcdef

# @funcdef <return type> @override <function name> ( *args )
#
#  A function that overrides (redefines) an already defined function.
#

# @funcdef <return type> @dont-override <function name> ( *args )
#
#  A function that must not redefined an existing one.
#

# @funcdef <return type> @can-override <function name> ( *args )
#
#  A function that is expected to be overridden in order to be useful.
#  @can-override functions usually do nothing.
#


#@section functions

# void OVERRIDE_FUNCTION ( function_name ), raises die()
#
#  Helper function for @override.
#  Dies if %function_name is not defined and unsets the function otherwise.
#
#  Has to be called _before_ redefining the function.
#
OVERRIDE_FUNCTION() {
   if function_defined "${1:?}"; then
      unset -f "${1}"
      return 0
   else
      die "@override: function ${1} is not defined and thus cannot be overridden."
   fi
}

# @function_alias FOVERWRITE() renames OVERRIDE_FUNCTION()
#
FOVERWRITE() { OVERRIDE_FUNCTION "$@"; }


# void DONT_OVERRIDE_FUNCTION ( function_name ), raises die()
#
#  Helper function for @dont-override.
#  Dies if %function_name is defined, else does nothing.
#
#  Has to be called _before_ defining the function.
#
DONT_OVERRIDE_FUNCTION() {
   if function_defined "${1:?}"; then
      die "@dont-override: function ${1} is already defined."
   else
      return 0
   fi
}

# @function_alias NOT_OVERRIDING() renames DONT_OVERRIDE_FUNCTION()
#
NOT_OVERRIDING() { DONT_OVERRIDE_FUNCTION "$@"; }
