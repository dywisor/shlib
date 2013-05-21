# SCRIPT_DIR_ABS, PRJROOT
SCRIPT_DIR_ABS=$(readlink -e "${SCRIPT_DIR}")
if [ -z "${SCRIPT_DIR_ABS}" ]; then
   if [ -z "${PRJROOT-}" ]; then
      die "SCRIPT_DIR_ABS is empty - cannot set PRJROOT."
   else
      unset SCRIPT_DIR_ABS
   fi
else
   readonly SCRIPT_DIR_ABS
   [ -n "${PRJROOT-}" ] || PRJROOT="${SCRIPT_DIR_ABS}"
fi

case "${PRJROOT-}" in
   /*)
      [ -d "${PRJROOT}" ] || die "PRJROOT (${PRJROOT}) does not exist."
   ;;
   *)
      _PRJROOT=$( readlink -e "${PRJROOT}" )
      [ -n "${_PRJROOT}" ] && [ -d "${_PRJROOT}" ] && \
         PRJROOT="${_PRJROOT}" || die "readlink: ${PRJROOT} does not exist."

      unset _PRJROOT
   ;;
esac
readonly PRJROOT

# SHLIB_ROOT
SHLIB_ROOT="${PRJROOT}/lib"
[ -d "${SHLIB_ROOT}" ] || die "/lib not found."
readonly SHLIB_ROOT

# SCRIPT_ROOT
SCRIPT_ROOT="${PRJROOT}/scripts"
[ -d "${SCRIPT_ROOT}" ] || die "/scripts not found."
readonly SCRIPT_ROOT

# BUILD_ROOT, BUILD_DIR
[ -n "${BUILD_ROOT-}" ] || BUILD_ROOT="${PRJROOT}/build"
readonly BUILD_ROOT
BUILD_DIR="${BUILD_ROOT}/default"

# SHLIBCC
if [ "${SYSTEM_SHLIBCC:-y}" = "y" ] && qwhich shlibcc; then
   SHLIBCC=shlibcc
elif [ -x ../shlibcc/shlibcc.py ]; then
   SYSTEM_SHLIBCC=n
   SHLIBCC=../shlibcc/shlibcc.py
else
   die "shlibcc not found."
fi
readonly SHLIBCC

# SHLIBCC_ARGS
: ${SHLIBCC_ARGS=--stable-sort --strip-virtual}
: ${SHLIBCC_ARGS_SCRIPT=}
: ${SHLIBCC_ARGS_LIB=}

# TARGET_*
: ${TARGET_SHLIB_NAME:=shlib.sh}
: ${TARGET_SHLIB_ROOT=/sh}

# misc SCRIPT_* vars for script generation
: ${SCRIPT_INTERPRETER=/bin/sh}
: ${SCRIPT_SET_U=y}
# SCRIPT_USE_BASH=y does not enforce SCRIPT_INTERPRETER=/bin/bash
: ${SCRIPT_USE_BASH:=n}
: ${SCRIPT_OVERWRITE:=n}
: ${SCRIPT_AUTO_VERIFY:=y}
: ${SCRIPT_AUTO_CHMOD:=n}
: ${SCRIPT_AUTO_CHOWN:=n}

# PRINTCMD_*
: ${PRINTCMD_CMD_LEN=16}
: ${PRINTCMD_INDENT=}
# PRINTCMD_QUIET has to be set before including devel/message

# PRINT_FUNCTRACE
: ${PRINT_FUNCTRACE=y}

# colors are topic to change
: ${PRINTCMD_COLOR_CMD='1;032m'}
: ${PRINTCMD_COLOR_ARGV=}
: ${PRINTCMD_COLOR_PWD='1;033m'}
: ${PRINTCMD_COLOR_SETVAR='1;034m'}
: ${PRINTCMD_INDENT_BY=  }
: ${PRINTCMD_OUTDENT_NEWLINE:=n}
