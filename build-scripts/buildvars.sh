#!/bin/sh
#
# Initializes build variables and runs a build script afterwards.
#
# Usage: buildvars [-f|--force] <project_root> <build_root> [<next> [*argv]]#
#  where next is a build script or "-x|--chainload script".
#
# * -f, --force is optional and sets FORCE=y (has to be the first arg)
#
# * project_root is the path to the shlib root directory containing this script
#
# * build_root is the directory where all building occurs (build script as
#   well as recipe dest dirs)
#
# * build_script is the name of a build script found in BUILD_WORKDIR (see below)
#
#
# Note that "you" (the caller of this script) has to clean up the build_root
# directory manually.
#
# The following variables will be written to %BUILDENV:
#
# * PRJROOT          -- absolute path to the project root directory
# * BUILD_ROOT       -- absolute path to the build root dir
# * BUILD_WORKDIR    -- %BUILD_ROOT/work
# * BUILDSCRIPTS     -- %BUILD_WORKDIR/scripts
# * BUILDENV         -- %BUILD_WORKDIR/stdvars.sh (not affected by --force)
# * BUILDFUNC        -- %BUILD_WORKDIR/stdfunc.sh
# * BUILDSCRIPTS_SRC -- %PRJROOT/build-scripts/shlib
# * FORCE            -- "y" or "n", depending on --force
#
#  ^INCOMPLETE
#
#
BUILDENV_VARS="FORCE QUIET VERBOSE MAKEOPTS \
PRJROOT PRJROOT_RECIPE FILESROOT \
BUILDVARS_EXE SHLIBCC SYSTEM_SHLIBCC BUILDSCRIPTS_SRC \
BUILD_ROOT \
BUILD_WORKDIR BUILDSCRIPTS BUILDENV BUILDFUNC"
#
# %BUILDENV also provides one function, "with_stdfunc()", which loads
# the following functions (from %BUILDFUNC):
#
# * die()                 -- minimal die() function (if not already defined)
# * keep_generated_file() -- removes a file if FORCE is set to y
#                             Also checks whether the given arg can be a file
# * prepare_dobuild()     -- prepares the dobuild recipe builder and sets %DOBUILD
# * make_buildscript()    -- creates a standalone script from %BUILDSCRIPTS_SRC/shlib
# * run_buildscript()     -- runs a script created by make_buildscript(),
#                             creates it if necessary.
#                             Passes %BUILDENV as first arg.
#
# This script enables the "nounset" shell option.
#
set -u

# void die ( message, exit_code ), raises exit()
#
die() {
   [ -z "${1-}" ] || echo "${1}" 1>&2
   exit ${2:-2}
}
HAVE_DIE=y


# void dodir ( dir ), raises exit()
#
dodir() { [ -d "${1-}" ] || mkdir -p "${1}" || die "mkdir returned ${?}." ${?}; }

buildenv_writevar() {
   local val
   eval "val=\"\${${1:?}?}\""
   echo "${1}=\"${val}\"" >> "${BUILDENV}" || die "writevar #${1}"
}

buildvars_writeheader() {
   echo '#!/bin/sh' > "${BUILDENV:?}" || die "writevars"
   echo "# --- begin initial buildenv ---" >> "${BUILDENV}" || die "writevars"

   writevars ${BUILDENV_VARS?}

   echo >> "${BUILDENV:?}" || die "writevars"
   echo 'with_stdfunc() { . "${BUILDFUNC:?}" -- || die || exit; }' >> "${BUILDENV}" || die "writevars"
   #echo >> "${BUILDENV}" || die "writevars"
   echo "# --- end initial buildenv ---" >> "${BUILDENV}" || die "writevars"
}

writevars() {
   local varname
   for varname; do buildenv_writevar "${varname}"; done
}

OUT_OF_BOUNDS() { die "shift returned ${?}." 12; }


# --- vars ---

: ${SYSTEM_SHLIBCC:=y}
: ${QUIET:=n}
: ${VERBOSE:=n}
: ${MAKEOPTS=-j8}

# FORCE
if [ "x${1-}" = "x-f" ] || [ "x${1-}" = "x--force" ]; then
   readonly FORCE=y; shift
else
   readonly FORCE=n
fi

if [ $# -lt 2 ] || [ -z "${1}" ] || [ -z "${2}" ]; then
   die "Usage: ${0##*/} [-f|--force] <project_root> <build_root> []"
fi

# PRJROOT
readonly PRJROOT=$(readlink -f "${1}")
[ -d "${PRJROOT}" ] || die "project_root '${1}' does not exist."

readonly BUILDVARS_EXE="${PRJROOT}/build-scripts/buildvars.sh"
readonly FILESROOT="${PRJROOT}/files"

# PRJROOT_RECIPE
PRJROOT_RECIPE="${PRJROOT?}/files/recipe"

# SHLIBCC
readonly SHLIBCC="${PRJROOT}/CC"
[ -x "${SHLIBCC}" ] || die "${SHLIBCC} is missing."

# BUILDSCRIPTS_SRC
readonly BUILDSCRIPTS_SRC="${PRJROOT}/build-scripts/shlib"
#[ -d "${BUILDSCRIPTS_SRC}" ] || die "${BUILDSCRIPTS_SRC} is missing."
[ -d "${BUILDSCRIPTS_SRC}" ] || echo "WARN: ${BUILDSCRIPTS_SRC} is missing." 1>&2

# BUILD_ROOT
readonly BUILD_ROOT=$(readlink -m "${2}" 2>/dev/null || readlink -f "${2}")
dodir "${BUILD_ROOT}"

shift 2 || OUT_OF_BOUNDS

# BUILD_WORKDIR
# BUILDSCRIPTS
readonly BUILD_WORKDIR="${BUILD_ROOT}/work"
readonly BUILDSCRIPTS="${BUILD_WORKDIR}/scripts"
dodir "${BUILDSCRIPTS}"

# BUILDENV
readonly BUILDENV="${BUILD_WORKDIR}/stdvars.sh"
# BUILDFUNC
readonly BUILDFUNC="${BUILD_WORKDIR}/stdfunc.sh"

# --- end of vars ---

# load stdfunc
#  FIXME: src path
STDFUNC_SRC="${BUILDSCRIPTS_SRC%/shlib}/lib/stdfunc.sh"
. "${STDFUNC_SRC}" || die "cannot load stdfunc"

buildvars_writeheader
cp -LfT -- "${STDFUNC_SRC}" "${BUILDFUNC}" || "die failed to copy stdfunc."


case "${1-}" in
   '')
      true
   ;;
   '--cat')
      cat "${BUILDENV:?}"
   ;;
   '-x'|'--chainload')
      shift || OUT_OF_BOUNDS

      if [ -z "${1-}" ]; then
         die "-x,--chainload needs a script as arg."
      elif [ -f "${1}" ]; then
         XLOAD="${1}"
      elif [ -f "${BUILDSCRIPTS_SRC%/shlib}/${1}" ]; then
         # FIXME: src path
         XLOAD="${BUILDSCRIPTS_SRC%/shlib}/${1}"
      elif [ -f "${BUILDSCRIPTS_SRC%/shlib}/${1}.sh" ]; then
         # FIXME: src path
         XLOAD="${BUILDSCRIPTS_SRC%/shlib}/${1}.sh"
      else
         die "cannot locate chainload script ${1}"
      fi

      shift || OUT_OF_BOUNDS

      ( . "${XLOAD}"; ) || die "${XLOAD} returned $?" ${?}
   ;;
   *)
      run_create_buildscript "$@" || die "run_buildscript returned ${?}." ${?}
   ;;
esac
