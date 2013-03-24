## This module offers basic USE flag functionality, that is checking whether
## a flag is set or not (via use()) and enabling/disabling flags.

readonly __USE_BASE_FUNCTIONS="use use_call disable_use enable_use"

# void __use_get_prefix ( **USE_PREFIX= )
#
#  Sets the %prefix variable (depending on %USE_PREFIX).
#
__use_get_prefix() {
   prefix="${USE_PREFIX-}"
   if [ -n "${prefix%_}" ]; then
      prefix="${prefix%_}_"
   else
      prefix=""
   fi
}

# int use ( *flag, **USE_PREFIX= )
#
# DEFINES @use_function <USE_PREFIX> <function name>
#
#  Returns 0 if "we" are using all listed flags (i.e., they're set to 'y'),
#  else 1.
#  Non-existent flags are assumed to be set to 'n'.
#  USE flags starting with a '!' are also supported.
#
#  This is a "not false" function. The difference to an "all true" function is
#  that the return value for undefined input (empty argv) is 0.
#
use() {
   local val prefix
   __use_get_prefix

   while [ $# -gt 0 ]; do
      if [ -z "${1-}" ]; then
         true
      elif [ "${1#!}" = "${1}" ]; then
         eval "val=\${__USE_${prefix}${1}:-n}"
         [ "${val}" = "y" ] || return 1

      else
         eval "val=\${__USE_${prefix}${1#!}:-n}"
         [ "${val}" != "y" ] || return 1
      fi
      shift
   done
   return 0
}

# int use_call ( flag, *cmdv, **USE_PREFIX )
#
#  Executes cmdv if flag is enabled.
#
use_call() {
   if use "${1?}"; then
      shift && "$@"
   else
      return 0
   fi
}

# void __use_set_to ( value, *flag, **USE_PREFIX= )
#
#  Sets zero or more USE flags to value.
#
__use_set_to() {
   local val="${1?}" prefix
   __use_get_prefix

   while shift && [ $# -gt 0 ]; do
      [ -z "${1-}" ] || eval "__USE_${prefix}${1}=${val}"
   done
   return 0
}

# void enable_use ( *flag, **USE_PREFIX= )
#
#  Enables zero or more USE flags.
#
enable_use() { __use_set_to y "$@"; }

# void disable_use ( *flag, **USE_PREFIX= )
#
#  Disables zero or more USE flags.
#
disable_use() { __use_set_to n "$@"; }

# void eval_use_functions (
#    function_name_prefix,
#    use_prefix=<function_name_prefix>,
#    propagate_prefix=n,
#    **__USE_FUNCTIONS="",
# )
#
#  Generates use(), use_call(), enable_use() and disable_use()
#  wrapper functions that have a fixed USE prefix. Also generates wrapper
#  functions for each function listed in __USE_FUNCTIONS (private variable
#  for functions from sub modules).
#  These functions pass USE_PREFIX="<fixed prefix>_<USE_PREFIX>" if
#  propagate_prefix is set to 'y', else USE_PREFIX="<fixed_prefix>" will
#  be passed.
#  The behavior of these two variants differs only if USE_PREFIX is set when
#  calling a wrapper function.
#
eval_use_functions() {
   local func_prefix="${1:?}_" use_prefix="${2:-${1}}" fname

   if [ "${3:-n}" = "y" ]; then
      for fname in ${__USE_BASE_FUNCTIONS} ${__USE_FUNCTIONS-}; do
         eval "${func_prefix}${fname}() { USE_PREFIX=\"${use_prefix}_\${USE_PREFIX-}\" ${fname} \"\$@\"; }"
      done
   else
      for fname in ${__USE_BASE_FUNCTIONS} ${__USE_FUNCTIONS-}; do
         eval "${func_prefix}${fname}() { USE_PREFIX=\"${use_prefix}\" ${fname} \"\$@\"; }"
      done
   fi
}
