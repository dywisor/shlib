# int scriptvars_leak (
#    *cmdv, **script!, **script_name!, **dest!, **dest_name!
# ), raises die()
#
#  Runs cmdv and ensures that the variables listed above are set.
#
scriptvars_leak() {
   local rc=0
   "$@" || rc=${?}
   varcheck_forbid_empty script script_name dest dest_name
   return ${rc}
}

# int scriptvars_noleak ( *cmdv )
#
#  Runs cmdv and ensures that the variables listed in scriptvars_leak()
#  are kept private.
#
scriptvars_noleak() {
   local script= script_name= dest= dest_name=
   "$@"
}

# @function_alias splitlibvars_leak() renames scriptvars_leak()
splitlibvars_leak()   { scriptvars_leak "$@"; }

# @function_alias splitlibvars_noleak() renames scriptvars_noleak()
splitlibvars_noleak() { scriptvars_noleak "$@"; }

# int libvars_leak ( *cmdv, **dest!, **dest_name! ), raises die()
#
libvars_leak() {
   local rc=0
   "$@" || rc=${?}
   varcheck_forbid_empty dest dest_name
   return ${rc}
}
libvars_noleak() {
   local dest= dest_name=
   "$@"
}

# int get_lib_dest ( lib_name, lib_root=, **v0! ), raises die()
#
get_lib_dest() {
   case "${1-}" in
      '')
         v0=
         return 1
      ;;
      ./*|../*)
         v0=
         die "relative dest not supported for lib files: ${1}"
      ;;
      /*)
         v0="${1}"
      ;;
      */*)
         v0="${2-}${2:+/}${1%/*}/lib/${1##*/}"
      ;;
      *)
         v0="${2-}${2:+/}lib/${1-}"
      ;;
   esac
   [ -n "${v0}" ]
}

get_splitlib_dest() {
   get_lib_dest "$@" && v0="${v0%.sh}.sh"
}

# @private void get_scriptvars__script (
#    script_name, **script!, **script_name!, **SCRIPT_ROOT
# ), raises die()
#
get_scriptvars_script() {
   case "${1-}" in
      '')
         die "script_name is not set."
      ;;
      /*|./*|../*)
         if [ -f "${1}" ]; then
            if [ "${1#.}" != "${1}" ]; then
               script=$( readlink -f "${script_name}" )
               [ -n "${script}" ] || "script is not set."
            else
               script="${1}"
            fi
            script_name="${script##*/}"
            script_name="${script%.*}"
         else
            die "no such script: ${1}."
         fi
      ;;
      *)
         script="${SCRIPT_ROOT}/${1}"

         if [ -f "${script}" ]; then
            script_name="${1%.*}"
         elif [ -f "${script}.sh" ]; then
            script_name="${1}"
            script="${script}.sh"
         else
            die "no such script: ${1} in ${SCRIPT_ROOT}."
         fi
      ;;
   esac
}


# int get_scriptvars (
#    script_name, dest_name=<script_name>,
#    **script!, **script_name!, **dest!, **dest_name!
#    **SCRIPT_ROOT, **BUILD_DIR,
#    **GET_SCRIPTVARS_DODIR=y
# ), raises die()
#
#  return value is number of processed args (1 or 2)
#
get_scriptvars() {
   DESTFILE_CHMOD='0755'
   get_scriptvars_script "${1-}"

   case "${2-}" in
      '')
         [ -n "${BUILD_DIR}" ] || die "BUILD_DIR is not set."
         dest_name="${script_name?}"
         dest="${BUILD_DIR}/${dest_name}"
      ;;
      /*)
         dest="${2}"
         #dest_name="${2##*/}" -- not accurate enough
         dest_name="${2}"
      ;;
      ./*|../*)
         dest=$( readlink -f "${2}" )
         dest_name="${2}"
      ;;
      *)
         [ -n "${BUILD_DIR}" ] || die "BUILD_DIR is not set."
         dest_name="${2}"
         dest="${BUILD_DIR}/${dest_name}"
      ;;
   esac

   [ "${GET_SCRIPTVARS_DODIR:-y}" != "y" ] || DODIR "${dest%/*}"
   [ -n "${2+SET}" ] && return 2 || return 1
}

# int get_libvars (
#    dest_name,
#    **dest!, **dest_name!, **BUILD_DIR, **GET_SCRIPTVARS_DODIR=y
# )
#
get_libvars() {
   DESTFILE_CHMOD='0644'
   local v0
   autodie get_lib_dest "${1-}" "${BUILD_DIR:?}"
   dest="${v0}"
   dest_name="${1}"

   [ "${GET_SCRIPTVARS_DODIR:-y}" != "y" ] || DODIR "${dest%/*}"
   return 1
}

# int get_splitlibvars (
#    script_name, dest_name=<script_name>,
#    **script!, **script_name!, **dest!, **dest_name!
#    **SCRIPT_ROOT, **BUILD_DIR,
#    **GET_SCRIPTVARS_DODIR=y
# ), raises die()
#
get_splitlibvars() {
   DESTFILE_CHMOD='0644'
   get_scriptvars_script "${1-}"

   local v0
   autodie get_splitlib_dest "${2-${script_name?}}" "${BUILD_DIR:?}"
   dest="${v0}"
   dest_name="${1}"

   [ "${GET_SCRIPTVARS_DODIR:-y}" != "y" ] || DODIR "${dest%/*}"
   [ -n "${2+SET}" ] && return 2 || return 1
}
