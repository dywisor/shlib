# void fspath_remove_trailing_slashes ( fspath, **v0! )
#
fspath_remove_trailing_slashes() {
   v0=
   case "${1?}" in
      /)
         v0="${1}"
      ;;
      /*)
         str_remove_trailing_chars "${1}" "/"
         v0="/${v0#/}"
      ;;
      */)
         str_remove_trailing_chars "${1}" "/"
      ;;
      *)
         v0="${1}"
      ;;
   esac
}

# void fspath_remove_leading_slashes ( fspath, **v0! )
#
fspath_remove_leading_slashes() {
   v0=
   case "${1?}" in
      /)
         v0="${1}"
      ;;
      /*)
         str_remove_leading_chars "${1}" "/"
         v0="/${v0}"
      ;;
      */)
         str_remove_leading_chars "${1}" "/"
      ;;
      *)
         v0="${1}"
      ;;
   esac
}

# void fspath_strip ( fspath, **v0! )
#
#  fspath_remove_leading_slashes() and fspath_remove_trailing_slashes()
#  in one function call.
#
fspath_strip() {
   v0=
   case "${1?}" in
      /)
         v0="${1}"
      ;;
      /*)
         str_remove_leading_chars "${1}" "/"
         str_remove_trailing_chars "${v0}" "/"
         v0="/${v0}"
      ;;
      */)
         str_remove_leading_chars "${1}" "/"
         str_remove_trailing_chars "${v0}" "/"
      ;;
      *)
         v0="${1}"
      ;;
   esac
}

# void fspath_trim ( fspath, **v0! )
#
#  Identical to fspath_strip(), but uses sed instead of builtin code.
#
fspath_trim() {
   : ${1?}
   v0="$( echo "${1}" | sed -r -e 's,[/]+,/,g' -e 's,[/]$,,' )"
}


# @private @stdout ~int readlink__abspath ( fspath )
#
#  abspath() function using readlink.
#  No path components need to exist.
#
#  Note that this resolves symlinks. Use realpath__abspath() if possible.
#
#  Linux with GNU coreutils only!
#
readlink__abspath() {
   readlink -m -- "${1?}"
}

# @private @stdout readlink__realpath ( fspath )
#
#  realpath() function using readlink.
#  All path components except the last one must exist.
#
#  Linux with GNU coreutils or busybox only!
#
readlink__realpath() {
   readlink -f -- "${1?}"
}

# @private @stdout ~int readlink__realpath_safe ( fspath )
#
#  realpath_safe() function using readlink.
#  All path components must exist.
#
#  Linux with GNU coreutils only!
#
readlink__realpath_safe() {
   readlink -e -- "${1?}"
}


# @private @stdout ~int realpath__abspath ( fspath )
#
#  abspath() function using realpath.
#
#  Linux with GNU coreutils only!
#
realpath__abspath() {
   realpath -Lsmq -- "${1?}"
}

# @private @stdout ~int realpath__realpath ( fspath )
#
#  realpath() using realpath.
#  All path components except the last one must exist.
#
#  Linux with GNU coreutils only!
#
realpath__realpath() {
   realpath -Lq -- "${1?}"
}

# @private @stdout ~int realpath__realpath_safe ( fspath )
#
#  realpath_safe() function using realpath.
#  All path components must exist.
#
#  Linux with GNU coreutils only!
#
realpath__realpath_safe() {
   realpath -Leq -- "${1?}"
}

# void fspath_bind_implementation (
#    impl, **HAVE_FSPATH_FUNCTIONS!
# ), raises function_die()
#
#  Binds the print_abspath, print_realpath, print_realpath_safe,
#  get_abspath, get_realpath and get_realpath_safe functions according
#  to the given implementation.
#
#  Available implementations:
#  * realpath
#  * readlink
#
fspath_bind_implementation() {
   HAVE_FSPATH_FUNCTIONS=n
   unset -f print_abspath print_realpath print_realpath_safe
   unset -f get_abspath get_realpath get_realpath_safe

   case "${1:?}" in
      realpath)
         print_abspath()       { realpath__abspath "$@"; }
         print_realpath()      { realpath__realpath "$@"; }
         print_realpath_safe() { realpath__realpath_safe "$@"; }

         get_abspath()         { v0="$(realpath__abspath "$@")"; }
         get_realpath()        { v0="$(realpath__realpath "$@")"; }
         get_realpath_safe()   { v0="$(realpath__realpath_safe "$@")"; }
      ;;
      readlink)
         print_abspath()       { readlink__abspath "$@"; }
         print_realpath()      { readlink__realpath "$@"; }
         print_realpath_safe() { readlink__realpath_safe "$@"; }

         get_abspath()         { v0="$(readlink__abspath "$@")"; }
         get_realpath()        { v0="$(readlink__realpath "$@")"; }
         get_realpath_safe()   { v0="$(readlink__realpath_safe "$@")"; }
      ;;
      *)
         function_die "unknown fspath implementation '${1}'" \
            fspath_bind_implementation
      ;;
   esac
   HAVE_FSPATH_FUNCTIONS=y
}

# void get_fspath ( fspath, **v0! )
#
#  Stores the realpath of %fspath in %v0 if it is non-empty,
#  and the abspath otherwise.
#
get_fspath() {
   v0=
   get_realpath "${1?}"
   [ -n "${v0}" ] || get_abspath "${1?}"
   return 0
}

# void fspath_bind_functions ( **HAVE_FSPATH_FUNCTIONS! )
#
#  Binds the print_abspath, print_realpath, print_realpath_safe,
#  get_abspath, get_realpath and get_realpath_safe functions according
#  to what's available. realpath is preferred.
#
#  Note that it is *not* checked whether the functions can actually be used
#  (i.e. running a Linux-based system with GNU coreutils etc.).
#  You may want to run fspath_bind_implementation(<name>) to choose a
#  specific implementation.
#
fspath_bind_functions() {
   if qwhich realpath; then
      fspath_bind_implementation realpath
   else
      fspath_bind_implementation readlink
   fi
}

# void fspath_bind_functions_if_required ( **HAVE_FSPATH_FUNCTIONS! )
#
fspath_bind_functions_if_required() {
   [ "${HAVE_FSPATH_FUNCTIONS:-n}" = "y" ] || fspath_bind_functions
}


if [ $$ -ne 0 ] && [ "${FSPATH_BIND_FUNCTIONS:-y}" = "y" ]; then
   fspath_bind_functions
fi
