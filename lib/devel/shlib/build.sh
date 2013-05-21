## misc wrappers
#
# TODO: support {SRC,DEST}_PREFIX
#

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
      SCRIPT_INTERPRETER=/bin/bash
   else
      SCRIPT_USE_BASH=n
      # FIXME: /bin/busybox ash, anyone?
      SCRIPT_INTERPRETER=/bin/sh
   fi
   print_setvar SCRIPT_USE_BASH
   print_setvar SCRIPT_INTERPRETER
}

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
      print_command "OVERWRITE" "enabled -- fix your build script!"
   elif [ "${SCRIPT_OVERWRITE:-x}" != "n" ]; then
      SCRIPT_OVERWRITE=n
      print_command "OVERWRITE" "disabled"
   fi
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

DOLIB_CHMOD() { DOLIB_CHMOD="${1-0644}"; }


INTO() { autodie set_build_dir "$@"; }

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
   local SCRIPT_AUTO_VERIFY=n
   get_scriptvars "$@" || shift ${?} || OUT_OF_BOUNDS
   print_command COPY_SCRIPT "${script}, ${dest_name}"
   printcmd_indent

   remove_destfile
   autodie cp -T -- "${script}" "${dest}"

   destfile_done
   printcmd_outdent
}
COPY_SCRIPT() { CP "$@"; }

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

COPY_SCRIPTS() {
   print_command COPY_SCRIPTS
   printcmd_indent
   local s
   for s; do
      CP "${__SRC_PREFIX-}${s}" "${__DEST_PREFIX-}${s}"

      if [ "${SCRIPT_AUTO_VERIFY:-n}" != "y" ]; then
         true
      elif head -n 1 "${dest}" | \
         grep -q -- ^'#![[:blank:]]*/bin/sh' "${script}"
      then
         VERIFY "${dest}"
      elif head -n 1 "${dest}" | \
         grep -q -- ^'#![[:blank:]]*/bin/bash' "${script}"
      then
         BASH_ONCE VERIFY "${dest}"
      else
         print_command SKIP_VERIFY "${dest}"
      fi
   done
   printcmd_outdent
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

__INHERITED__() { [ -n "${__INHERITED__-}" ]; }

DIE() { die "$@"; }
END() {
   if [ ${3:-0} -eq 0 ]; then
      print_message "${2:-SUCCESS}" "${1-}" "1;032" ""
   else
      print_message "${2:-ERROR}" "${1-}" "1;031" ""
   fi
   exit ${3:-0}
}
