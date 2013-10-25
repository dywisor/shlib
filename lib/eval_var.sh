# int var_is_set ( varname )
#
#  Returns 0 if the variable with the given name is set, else 1.
#
var_is_set() {
   local is_set
   eval is_set="\${${1}+X}"
   [ -n "${is_set}" ]
}

# int var_is_set_nonempty ( varname )
#
#  Returns 0 if the variable with the given name is set and not empty, else 1.
#
var_is_set_nonempty() {
   local is_set
   eval is_set="\${${1}:+X}"
   [ -n "${is_set}" ]
}

# int loadvar ( varname, **v0! )
#
#  Loads the variable with the given name into %v0, if it is set,
#  and returns 0. Returns 1 otherwise.
#
loadvar() {
   v0=
   if var_is_set "${1}"; then
      eval v0="\${${1}?}"
      return 0
   else
      return 1
   fi
}

# void loadvar_lazy ( varname, **v0! )
#
#  Loads the variable with the given name into %v0,
#  whether it exists or not (which loads the empty str).
#
loadvar_lazy() {
   v0=
   eval v0="\${${1}-}"
}

# void setvar ( varname, value )
#
#  Assigns a value to a variable.
#
setvar() {
   eval ${1}="${2}"
}
