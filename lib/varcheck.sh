# void|int varcheck (
#    *varname,
#    **VARCHECK_ALLOW_EMPTY=n, **VARCHECK_PREFIX=, **VARCHECK_DIE=y
# ), raises die()
#
#  Ensures that zero or more variables are set.
#  Prefixes each variable with VARCHECK_PREFIX if set.
#
#  Returns a non-zero value if any var is unset or has an empty value (and
#  VARCHECK_ALLOW_EMPTY != y).
#
#  Calls die() with a rather meaningful message instead of returning if
#  VARCHECK_DIE is set to 'y'.
#
#  Note:
#     Variables whose name start with VARCHECK_ or varcheck_ cannot be
#     checked properly for technical reasons (private namespace).
#
#  Note:
#     This function is meant for checking many variables at once,
#     e.g. config keys. Functions should use "${<varname>:?}" etc.
#
varcheck() {
   local varcheck_unset \
      varcheck_varname varcheck_val0 varcheck_val1

   for varcheck_varname; do
      varcheck_varname="${VARCHECK_PREFIX-}${varcheck_varname}"

      eval "varcheck_val0=\${${varcheck_varname}-}"
      if [ -z "${varcheck_val0}" ]; then
         if [ "${VARCHECK_ALLOW_EMPTY:-n}" = "y" ]; then
            eval "varcheck_val1=\${${varcheck_varname}-UNDEF}"
            if [ "x${varcheck_val1}" != "x${varcheck_val0}" ]; then
               # UNDEF, "" => not set
               varcheck_unset="${varcheck_unset-} ${varcheck_varname}"
            fi
            # else "", "" empty => allowed
         else
            # empty or unset
            varcheck_unset="${varcheck_unset-} ${varcheck_varname}"
         fi
      fi
   done

   if [ -n "${varcheck_unset-}" ]; then

      if [ "${VARCHECK_DIE:-y}" != "y" ]; then
         return 1
      else
         local varcheck_msg

         if [ "${VARCHECK_ALLOW_EMPTY:-n}" = "y" ]; then
            varcheck_msg="the following variables are not set:"
         else
            varcheck_msg="the following variables are either empty or not set:"
         fi

         for varcheck_varname in ${varcheck_unset}; do
            varcheck_msg="${varcheck_msg}\n ${varcheck_varname}"
         done

         die "${varcheck_msg}"

      fi

   else
      return 0
   fi
}

# @function_alias varcheck_allow_empty(...)
#  is varcheck (..., **VARCHECK_ALLOW_EMPTY=y )
#
varcheck_allow_empty() {
   VARCHECK_ALLOW_EMPTY=y varcheck "$@"
}

# @function_alias varcheck_allow_empty(...)
#  is varcheck (..., **VARCHECK_ALLOW_EMPTY=n )
#
varcheck_forbid_empty() {
   VARCHECK_ALLOW_EMPTY=n varcheck "$@"
}
