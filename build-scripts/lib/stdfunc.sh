if [ -z "${HAVE_DIE+SET}" ]; then

die() {
   [ -z "${1-}" ] || echo "${1}" 1>&2
   exit ${2:-2}
}

fi

keep_generated_file() {
   if [ -f "${1}" ]; then
      if [ "${FORCE}" = "y" ]; then
         rm -v -- "${1}" || die "keep_generated_file()"
         return 2
      elif [ ! -s "${1}" ]; then
         rm -- "${1}" || die "keep_generated_file()"
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

make_buildscript() {
   : ${1:?}
   local s="${BUILDSCRIPTS_SRC}/${1%.sh}.sh"
   v0="${BUILDSCRIPTS}/${1%.sh}.sh"

   if [ "${2:-X}" = "--no-recreate" ] && [ -f "${v0}" ]; then
      return 0
   elif keep_generated_file "${v0}"; then
      true
   elif [ -f "${s}" ]; then
      if [ -n "${F_BUILDSCRIPT_PRE_CREATE-}" ]; then
         ${F_BUILDSCRIPT_PRE_CREATE} "${v0}" || die "F_BUILDSCRIPT_PRE_CREATE"
      fi

      ${SHLIBCC:?} \
         --stable-sort --allow-empty --bash \
         --strip-all --no-enclose-modules --short-header \
         --defsym "${BUILDENV:?}" \
         --depfile --main "${s}" -O "${v0}" || \
         die "failed to create build script ${v0##*/}"

      if [ -n "${F_BUILDSCRIPT_CREATED-}" ]; then
         ${F_BUILDSCRIPT_CREATED} "${v0}" || die "F_BUILDSCRIPT_CREATED"
      fi
   else
      die "build script source file ${s} does not exist."
   fi

   [ -x "${v0}" ] || chmod u+x "${v0}" || die "chmod ${v0}"
}

prepare_dobuild() {
   "${BUILDVARS_EXE:?}" \
      --force "${PRJROOT:?}" "${BUILD_ROOT:?}" -x dobuild-ng || \
      die "cannot create dobuild() script."
   DOBUILD="${BUILDSCRIPTS}/dobuild.sh"
}

run_buildscript() {
   local v0
   make_buildscript "${1}" --no-recreate; shift || die "shift"

   "${v0}" "$@" || \
      die "build script ${v0##*/} returned ${?}." ${?}
}

run_create_buildscript() {
   local v0
   make_buildscript "${1}"; shift || die "shift"

   "${v0}" "$@" || \
      die "build script ${v0##*/} returned ${?}." ${?}
}
