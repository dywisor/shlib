#!/bin/sh
#
#  "boostrap" script that creates a recipe build script in the build root dir
#  and runs it afterwards.
#
# Usage: <NAME> [-f|--force] <project_root> <build_root> [<recipe>...]
#
# * -f, --force is optional and enforces recreation of the build script
#   (has to be the first arg)
#
# * project_root is the path to the shlib root directory containing this script
#
# * build_root is the directory where all building occurs (build script as
#   well as recipe dest dirs)
#
# * recipe is a path to a recipe file (can be specified more than once)
#    all recipe args will be passed to the build script
#
#
# Extended recipe file syntax:
#
# * INHERIT(), INHERIT_LOCAL() -- run recipes within recipes
# * use_call_yesno()           -- call command with y or n as arg, depending
#                                 on whether a USE flag is enabled or not
#
#

set -u

LANG=C
LC_ALL=C

FORCE=n

die() {
   [ -z "${1-}" ] || echo "${1}" 1>&2
   exit ${2:-2}
}
run() { "$@" || die "'$*' returned ${?}." ${?}; }

keep_generated_file() {
   if [ -f "${1}" ]; then
      if [ "${FORCE}" = "y" ]; then
         run rm -v -- "${1}"
         return 2
      elif [ ! -s "${1}" ]; then
         run rm -- "${1}"
         return 3
      else
         return 0
      fi
   elif [ -e "${1}" ]; then
      die "not a file: ${1}"
   else
      return 1
   fi
}

# int make_dobuild__script ( file )
#
#  creates the build script
#
make_dobuild__script() {
cat > "${1:?}" << EOF
#!${DOBUILD_INTERPRETER:-/bin/sh}
#
# ${1##*/} - generated file
#
set -u

readonly PRJROOT="${PRJROOT}"
readonly BUILD_ROOT="${BUILD_ROOT}"
readonly RECIPE_ROOT="${RECIPE_ROOT}"

LANG=C
LC_ALL=C

: \${NO_COLOR:=${NO_COLOR:-n}}
: \${PRINTCMD_QUIET:=${PRINTCMD_QUIET:-n}}
: \${PRINTMSG_QUIET:=${PRINTMSG_QUIET:-n}}
: \${SCRIPT_OVERWRITE:=${SCRIPT_OVERWRITE:-n}}

. "${B_ENV:?}" || exit

set_use +nounset ${USE-}${USE:+ }\${USE-}

# int use_call_yesno ( flag, *cmdv )
#
#  Calls *cmdv y if flag is enabled, else *cmdv n
#
use_call_yesno() {
   local flag="\${1}"; shift || OUT_OF_BOUNDS

   if use "\${flag}"; then
      "\$@" y
   else
      "\$@" n
   fi
}

use_call_yesno bash    SET_BASH
use_call_yesno nounset SET_NOUNSET

# void run_recipe ( recipe ), raises exit()
#
run_recipe() {
   print_message "RECIPE" "\${1}" '1;001m' '1;104m';
   # run recipes in subshells so that they dont affect others
   local rc=0
   local RECIPE="\${1}"
   (
      set -e
      readonly RECIPE

      # void INHERIT ( recipe ), raises die()
      #
      #  Runs another recipe.
      #  Note: infinite recursion is possible. It's up to you to avoid that.
      #
      INHERIT() {
         local __INHERITED__="\${RECIPE}"
         print_command INHERIT "\$*"
         printcmd_indent
         find_and_run_recipe "\$@"
         printcmd_outdent
      }

      # void INHERIT_LOCAL ( **RECIPE ), raises die()
      #
      #  Calls INHERIT ( %RECIPE.local )
      #
      INHERIT_LOCAL() { INHERIT "\${RECIPE}.local"; }

      printcmd_indent
      . "\${1}"
      printcmd_outdent # just for completeness
   ) || rc=\$?
   if [ \${rc} -eq 0 ]; then
      print_message "RECIPE_END" "\${1}" '1;034' '1;104'
   else
      print_message "RECIPE_END" "\${1}" '1;031' '1;104'
      exit \${rc}
   fi
}

# int find_recipe ( name )
#
find_recipe() {
   recipe=
   if [ "\${1:?}" = "\${1#/}" ]; then
      if [ -n "\${RECIPE-}" ]; then
         recipe="\${RECIPE%/*}/\${1}"
      else
         recipe="\${RECIPE_ROOT}/\${1}"
      fi
   else
      recipe="\${1}"
   fi

   if [ -f "\${recipe}" ]; then
      true
   elif [ -f "\${recipe}.recipe" ]; then
      recipe="\${recipe}.recipe"
   else
      return 1
   fi
}

# void find_and_run_recipe ( name ), raises die()
#
find_and_run_recipe() {
   local recipe
   find_recipe "\${1:?}"     || die "no such recipe: \${1}."
   run_recipe "\${recipe:?}" || die "run_recipe() is not allowed to return \${?}."
}

# @implicit int main ( *recipe_name )
#
for N; do
   RECIPE=
   __INHERITED__=
   find_and_run_recipe "\${N}" || die
done
EOF
}

make_dobuild() {
   run make_dobuild__script "${1}"
}

if [ "x${1-}" = "x-f" ] || [ "x${1-}" = "x--force" ]; then
   FORCE=y; shift
fi

[ $# -gt 1 ] || \
   die "Usage: ${0##*/} [-f|--force] <project_root> <build_root> [<recipe>...]"

: ${1:?} ${2:?}

PRJROOT=$(readlink -e "${1}")
[ -d "${PRJROOT}" ] || die "project_root '${1}' does not exist."

[ -x "${PRJROOT}/CC" ] || die "${PRJROOT}/CC is missing."

BUILD_ROOT=$(readlink -f "${2}")
[ -d "${BUILD_ROOT:?}" ] || run mkdir -p -- "${BUILD_ROOT}"

RECIPE_ROOT=$(readlink -f "${PWD}")

shift 2 || die

# if any recipe given, verify that they exist
for recipe; do
   [ -f "${recipe}" ] || [ -f "${recipe}.recipe" ] || \
      die "recipe not found: '${recipe}'."
done
unset recipe

B_ENV="${BUILD_ROOT}/buildenv.sh"
B_SCRIPT="${BUILD_ROOT}/dobuild.sh"

[ "${USE_BASH:=n}" != "y" ] || DOBUILD_INTERPRETER="/bin/bash"


if ! keep_generated_file "${B_ENV}"; then
   CC_ARGS="--as-lib --stable-sort --short-header --strip-all --no-enclose-modules"
   [ "${USE_BASH}" != "y" ] || CC_ARGS="${CC_ARGS} --bash"
   run "${PRJROOT}/CC" ${CC_ARGS} devel/shlib/build -O "${B_ENV}"
fi

keep_generated_file "${B_SCRIPT}" || run make_dobuild "${B_SCRIPT}"
[ -x "${B_SCRIPT}" ] || run chmod u+x "${B_SCRIPT}"

# try to execute %B_SCRIPT even if no recipe given
# (results in a no-op with syntax checking)
#
if [ -n "${BASH_VERSION-}" ] || [ "x${SHELL-}" = "x/bin/bash" ]; then
   bash ${B_SCRIPT} "$@"
else
   ${B_SCRIPT} "$@"
fi
