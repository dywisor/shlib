#@section functions

# int var_is_set ( varname )
#
#  Returns 0 if the variable with the given name is set, else 1.
#
var_is_set() {
   #@varcheck 1
   local is_set
   eval is_set="\${${1}+X}"
   [ -n "${is_set}" ]
}

# int var_is_set_nonempty ( varname )
#
#  Returns 0 if the variable with the given name is set and not empty, else 1.
#
var_is_set_nonempty() {
   #@varcheck 1
   local is_set
   eval is_set="\${${1}:+X}"
   [ -n "${is_set}" ]
}

# int loadvar ( varname, dest_varname="v0", **$dest_varname! )
#
#  Loads the variable with the given name into %dest_varname, if it is set,
#  and returns 0. Returns 1 otherwise.
#
loadvar() {
   #@varcheck 1
   eval ${2:-v0}=
   if var_is_set "${1}"; then
      eval ${2:-v0}="\${${1}?}"
      return 0
   else
      return 1
   fi
}

# void loadvar_lazy ( varname, dest_varname="v0", **$dest_varname! )
#
#  Loads the variable with the given name into %dest_varname,
#  whether it exists or not (which loads the empty str).
#
loadvar_lazy() {
   #@varcheck 1
   eval ${2:-v0}=
   eval ${2:-v0}="\${${1}-}"
}

# void setvar ( varname, value )
#
#  Assigns a value to a variable.
#
setvar() {
   #@varcheck 1
   eval ${1}="${2}"
}

# void swapvars ( varname0, varname1 )
#
#  Swaps the values of two variables referenced by name.
#
#  Neither of these variables must be "__swapvars_tmp_value".
#
swapvars() {
   #@safety_check eval : \${${1:?}?} \${${2:?}?}
   #@debug case "__swapvars_tmp_value" in
   #@debug    "${1}"|"${2}")
   #@debug       echo "swapvars(): invalid varname __swapvars_tmp_value" 1>&2
   #@debug       return 2
   #@debug    ;;
   #@debug esac
   local __swapvars_tmp_value
   eval "__swapvars_tmp_value=\"\${${1:?}?}\""
   eval "${1:?}=\"\${${2:?}?}\""
   eval "${2:?}=\"\${${__swapvars_tmp_value:?}?}\""
}
