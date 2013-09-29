## misc wrappers
#
# TODO: support {SRC,DEST}_PREFIX
#

# void BUILD_API ( build_api )
#
#  Sets the build API.
#
#  no-op. Reserved for future usage.
#
BUILD_API() {
   BUILD_API="${1}"
   print_setvar BUILD_API
}

# int __FUTURE__ ( func_spec )
#
#  Loads a function from future build APIs.
#  Returns 0 on success, else non-zero (1).
#
#  func_spec ::= <function name>[:<api_spec>{,<api_spec>}]
#  api_spec  ::= ## to be figured out ##
#
#  Not Implemented. Reserved for future usage.
#
__FUTURE__() { return 1; }

SET_NOUNSET() {
   if [ "${1:-y}" = "y" ]; then
      SCRIPT_SET_U=y
   else
      SCRIPT_SET_U=n
   fi
   print_setvar NOUNSET "${SCRIPT_SET_U}"
}

SET_BASH() {
   if [ "${1:-y}" = "y" ]; then
      SCRIPT_USE_BASH=y
      print_setvar SCRIPT_USE_BASH
      SET_SCRIPT_INTERPRETER /bin/bash
   else
      SCRIPT_USE_BASH=n
      print_setvar SCRIPT_USE_BASH
      SET_SCRIPT_INTERPRETER "${2-}"
   fi
}

SET_BUSYBOX_ASH() { SET_BASH n "/bin/busybox ash"; }
SET_DASH()        { SET_BASH n "/bin/dash"; }

SET_SCRIPT_INTERPRETER() {
   SCRIPT_INTERPRETER="${1:-${DEFAULT_SCRIPT_INTERPRETER:-/bin/sh}}"
   print_setvar SCRIPT_INTERPRETER
}
SET_INTERPRETER() { SET_SCRIPT_INTERPRETER "$@"; }


BASH_ONCE() {
   print_command BASH_ONCE "$*"
   printcmd_indent
   local SCRIPT_USE_BASH=y
   local SCRIPT_INTERPRETER=y

   print_setvar SCRIPT_USE_BASH "y" "SETVAR [local]"
   print_setvar SCRIPT_INTERPRETER "/bin/bash" "SETVAR [local]"

   autodie "$@"
   printcmd_outdent
}

SET_OVERWRITE() {
   if [ "${1:-y}" = "y" ]; then
      local PRINTCMD_COLOR_CMD="1;33m"
      SCRIPT_OVERWRITE=y
      if [ "${2:-N}" = "--force" ]; then
         print_command "OVERWRITE" "enabled"
      elif [ -n "${2-}" ]; then
         print_command "OVERWRITE" "enabled (${2})"
      else
         print_command "OVERWRITE" "enabled -- fix your build script!"
      fi
   elif [ "${SCRIPT_OVERWRITE:-x}" != "n" ]; then
      SCRIPT_OVERWRITE=n
      print_command "OVERWRITE" "disabled"
   fi
}

ENABLE_OVERWRITE_IF() {
   local f
   for f; do
      if HAVE_FILE "${f}"; then
         SET_OVERWRITE y "'${f}' exists"
         break
      fi
   done
   return 0
}

TARGET_ROOT() {
   TARGET_SHLIB_ROOT="${1:-/sh}"
   print_setvar TARGET_SHLIB_ROOT
}
TARGET_SHLIB() {
   TARGET_SHLIB_NAME="${1:-shlib.sh}"
   print_setvar TARGET_SHLIB_NAME
}


SET_DEFAULTS() {
   SCRIPT_AUTO_CHMOD=y
   print_setvar SCRIPT_AUTO_CHMOD
   #SCRIPT_AUTO_CHOWN
   SCRIPT_AUTO_VERIFY=y
   print_setvar SCRIPT_AUTO_VERIFY

   SET_NOUNSET
   DOLIB_CHMOD 0755
}

__LOCATE() {
   local GET_SCRIPTVARS_DODIR=n
   local k="${1:?}"; shift
   print_command "LOCATE [${k}]" "$*"
   ${k}vars_leak get_${k}vars "$@" || true
}


LOCATE_LIB()      { __LOCATE lib     "$@"; }
LOCATE_SCRIPT()   { __LOCATE script  "$@"; }
LOCATE_SPLITLIB() { __LOCATE spltlib "$@"; }
LOCATE()          { __LOCATE script  "$@"; }

DOLIB_CHMOD() { DOLIB_CHMOD="${1-0644}"; print_setvar DOLIB_CHMOD; }


INTO()      { autodie set_build_dir "$@"; }
INTO_ROOT() { INTO "${TARGET_SHLIB_ROOT}"; }

CHDIR() {
   local into
   case "${1-}" in
      '')
         into="${PRJROOT}"
      ;;
      //*)
         into="${1#/}"
      ;;
      *)
         into="${PRJROOT}/${1#/}"
      ;;
   esac
   print_command CHDIR "${into}"
   cd "${into}" || die "cannot cd into ${into}."
}

CHMOD() {
   local mode="${1:-${DESTFILE_CHMOD:?}}"
   print_command CHMOD "${dest} (${mode})"
   autodie chmod -- ${mode} "${dest:?}"
}
CHOWN() {
   local owner="${1:-${DESTFILE_CHOWN:?}}"
   print_command CHOWN "${dest} (${owner})"
   autodie chown -h -- ${owner} "${dest:?}"
}

VARCHECK() {
   print_command VARCHECK "$*"
   varcheck "$@"
}

ASSERT_DIR() {
   print_command ASSERT_DIR "$*"
   local d
   for d; do [ -d "${d}" ] || die "no such directory: '${d}'"; done
}

ASSERT_FILE() {
   print_command ASSERT_FILE "$*"
   local f
   for f; do
      [ -f "${f}" ] && [ -s "${f}" ] || die "no such non-empty file: '${f}'"
   done
}

MAKELIB_SHLIB() {
   MAKELIB "${TARGET_SHLIB_NAME:?}" all
}
HAVELIB_SHLIB() {
   HAVE_FILE "lib/${TARGET_SHLIB_NAME:?}"
}

SYMSTORM() {
   [ -n "${1-}" ] || die "SYMSTORM needs >= 1 arg(s)."

   print_command "SYMSTORM" "${1}"
   printcmd_indent

   local target="${1}"; shift || OUT_OF_BOUNDS
   local dest_name dest

   for dest_name; do
      dest_name="${__DEST_PREFIX-}${dest_name}"
      dest=
      case "${dest_name}" in
         '')
            continue
         ;;
         //*)
            die "absolute dest paths are not supported in SYMSTORM()."
            #dest="${dest_name}"
         ;;
         ./*|../*)
            # ^ condition does not filter all bad relpaths
            die "relative dest paths not supported by SYMSTORM()."
         ;;
         *)
            dest="${BUILD_DIR}/${dest_name#/}"
         ;;
      esac

      if [ -n "${dest}" ]; then
         print_command "DOSYM" "${dest_name#/} => ${target}"
         remove_destfile
         autodie ln -s -T -- "${target}" "${dest}"
      fi
   done

   printcmd_outdent
}

CP() {
   local s="${__SRC_PREFIX-}${1-}"
   local d

   if [ -n "${2-}" ]; then
      d="${__DEST_PREFIX-}${2}"
      shift 2 || OUT_OF_BOUNDS
   else
      d="${__DEST_PREFIX-}${1-}"
      shift || OUT_OF_BOUNDS
   fi

   get_scriptvars "${s}" "${d}" "$@" || true
   #shift $(( ${?} - 2 )) || OUT_OF_BOUNDS

   print_command COPY_SCRIPT "${script}, ${dest_name}"
   printcmd_indent

   remove_destfile
   autodie cp -T -- "${script}" "${dest}"

   if [ "${SCRIPT_AUTO_VERIFY:-n}" = "y" ]; then
      local h=$( head -n 1 "${dest}" | sed -e 's,^\#\![[:blank:]]*,,' )

      case "${h#/bin/}" in
         "sh"|"ash"|"busybox ash"|"dash")
            VERIFY "${dest}"
         ;;
         "bash")
            BASH_ONCE VERIFY "${dest}"
         ;;
         *)
            print_command SKIP_VERIFY "${dest}"
         ;;
      esac
   fi

   local SCRIPT_AUTO_VERIFY=n
   destfile_done
   printcmd_outdent
}
COPY_SCRIPT() { scriptvars_noleak CP "$@"; }

COPY_SCRIPTS() {
   print_command COPY_SCRIPTS
   printcmd_indent
   local s
   for s; do COPY_SCRIPT "${s}" "${s}"; done
   printcmd_outdent
}


HAVE_FILE() {
   local f
   local fname
   for fname; do
      case "${fname}" in
         //*)
            f="${fname}"
         ;;
         *)
            f="${BUILD_DIR:?}/${__DEST_PREFIX-}${fname#/}"
         ;;
      esac
      [ -f "${f}" ] && [ -s "${f}" ] || return 1
   done
   return 0
}


SRC_PREFIX() {
   local __SRC_PREFIX="${1?}"; shift || OUT_OF_BOUNDS
   [ -z "${__SRC_PREFIX}" ] || __SRC_PREFIX="${__SRC_PREFIX%/}/"
   "$@"
}
DEST_PREFIX() {
   local __DEST_PREFIX="${1?}"; shift || OUT_OF_BOUNDS
   [ -z "${__DEST_PREFIX}" ] || __DEST_PREFIX="${__DEST_PREFIX%/}/"
   "$@"
}

DOLIB() {
   print_command DOLIB
   printcmd_indent
   local l
   for l; do
      LINK_SHARED_LIB "${__SRC_PREFIX-}${l}" "${__DEST_PREFIX-}${l}"
      [ -z "${DOLIB_CHMOD-}" ] || CHMOD ${DOLIB_CHMOD}
   done
   printcmd_outdent
}
DOLIB_ROOT() {
   DEST_PREFIX root DOLIB "$@"
}


COLOR() { [ "${NO_COLOR:-y}" != "y" ]; }

PRINT() {
   # $1 <-> $2
   print_message "${2-}" "${1-}" "${3:-1;033}" "${4:-1;035}"
}

LOADVAR() {
   eval "v0=\"\${${1}-}\""
   if [ -n "${v0}" ]; then
      return 0
   else
      local x
      eval "x=\"\${${1}+SET}\""
      if [ -n "${x}" ]; then
         return 0
      elif [ "${LOADVAR_DIE:-y}" = "y" ]; then
         die "${1} is not set."
      else
         return 1
      fi
   fi
}

PRINTVAR() {
   local v0
   local LOADVAR_DIE="${2:-${PRINTVAR_DIE:-y}}"
   LOADVAR "${1}" && PRINT "${v0}" "${1}"
}

__INHERITED__()     { [ -n "${__INHERITED__-}" ]; }
__NOT_INHERITED__() { [ -z "${__INHERITED__-}" ]; }
DENY_INHERIT() {
   __NOT_INHERITED__ || die "This recipe must not be inherited."
}

SHLIBCC_ARGS() { SHLIBCC_ARGS="$*"; print_setvar SHLIBCC_ARGS; }
SHLIBCC_ARGS_APPEND() {
   if [ -n "${SHLIBCC_ARGS-}" ]; then
      local arg;
      for arg; do
         list_has "${arg}" ${SHLIBCC_ARGS} || \
            SHLIBCC_ARGS="${SHLIBCC_ARGS} ${arg}"
      done
   else
      SHLIBCC_ARGS="$*"
   fi
   print_setvar SHLIBCC_ARGS
}


BUILD_NEEDS_BASH() {
   [ -n "${BASH_VERSION-}" ] || \
      die "This recipe needs to be run with bash as command interpreter."
}
BUILD_NEED_BASH() { BUILD_NEEDS_BASH "$@"; }


DIE() { die "$@"; }
END() {
   if [ ${3:-0} -eq 0 ]; then
      print_message "${2:-SUCCESS}" "${1-}" "1;032" ""
   else
      print_message "${2:-ERROR}" "${1-}" "1;031" ""
   fi
   exit ${3:-0}
}
