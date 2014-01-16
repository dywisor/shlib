#@section functions

# void configure_which_python ( version="", **PYTHON! )
#
#  Locates python and stores its path in %PYTHON.
#
configure_which_python() {
   local v0
   configure_which python${1-} && PYTHON="${v0}"
}

# void configure_which_python2 ( subversion="", **PYTHON!, **PYTHON2! )
#
#  Locates python2 and stores its path in both %PYTHON and %PYTHON2.
#
configure_which_python2() {
   local v0
   local subver=
   [ -z "${1-}" ] || subver=".${1#.}"
   configure_which python2${subver} && PYTHON="${v0}" && PYTHON2="${v0}"
}

# void configure_which_python3 ( subversion="", **PYTHON!, **PYTHON3! )
#
#  Locates python3 and stores its path in both %PYTHON and %PYTHON3.
#
configure_which_python3() {
   local v0
   local subver=
   [ -z "${1-}" ] || subver=".${1#.}"
   configure_which python3${subver} && PYTHON="${v0}" && PYTHON3="${v0}"
}


# int configure_python_has_module ( *modules, **PYTHON, **v0! )
#
#  Checks whether the given python modules can be imported.
#  Returns the number of missing modules or 255, whatever is lower.
#  Also stores the names of the missing modules in %v0.
#
#  %PYTHON has to be set before calling this function, which is automatically
#  done by configure_which_python*().
#
configure_python_has_module() {
   v0=
   local name
   local fail=0
   [ -n "${PYTHON-}" ] || configure_die "\$PYTHON is not set."
   for name; do
      configure_check_message_begin "${PYTHON} has the '${name}' module"
      if ${PYTHON} -c "import ${name}" 2>>${DEVNULL}; then
         configure_check_message_end "yes"
      else
         configure_check_message_end "no"
         v0="${v0} ${name}"
         fail=$(( ${fail} + 1 ))
      fi
   done
   v0="${v0# }"
   [ ${fail} -lt 256 ] || fail=255
   return ${fail}
}

# void configure_python_need_module ( *modules, **PYTHON )
#
#  Like configure_python_has_module(), but dies if any module could not
#  be imported (after trying to import all modules).
#
configure_python_need_module() {
   local v0
   configure_python_has_module "$@" || \
      configure_die "essential python modules are missing: ${v0}"
}

# @function_alias configure_python_check_import()
#  renames configure_python_need_module()
configure_python_check_import() { configure_python_need_module "$@"; }


# int configure_python_try_import_from ( module, *names, **PYTHON, **v0! )
#
#  Tries to import one or more names from the given python module.
#  Returns the number of names that couldn't be imported or 255, whatever
#  is lower. Also stores the "bad" names in %v0.
#
#  %PYTHON has to be set before calling this function, which is automatically
#  done by configure_which_python*().
#
configure_python_try_import_from() {
   v0=
   [ -n "${1-}" ] && [ -n "${2-}" ] || \
      configure_die "configure_python_try_import_from(): bad usage."
   [ -n "${PYTHON-}" ] || configure_die "\$PYTHON is not set."

   local mod="${1}"
   local fail=0
   shift
   for name; do
      configure_check_message_begin \
         "'${name}' can be imported from module '${mod}'"
      if ${PYTHON} -c "from ${mod} import ${name}" 2>>${DEVNULL}; then
         configure_check_message_end "yes"
      else
         configure_check_message_end "no"
         v0="${v0} ${name}"
         fail=$(( ${fail} + 1 ))
      fi
   done
   v0="${v0# }"
   [ ${fail} -lt 256 ] || fail=255
   return ${fail}
}

# void configure_python_check_import_from ( module, *names, **PYTHON )
#
#  Like configure_python_try_import_from(), but dies if any name could not
#  be imported (after trying to import all names).
#
configure_python_check_import_from() {
   local v0
   [ -n "${1-}" ] || \
      configure_die "configure_python_check_import_from(): bad usage."

   configure_python_need_module "${1}"
   configure_python_try_import_from "$@" || \
      configure_die "cannot import names from module '${1}': ${v0}"
}
