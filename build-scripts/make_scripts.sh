#!/bin/sh
## (EXPERIMENTAL)
set -u

readonly GEN_SCRIPT="${SHLIB_PRJROOT:?}/generate_script.sh"
: ${SCRIPT_OUTFILE_REMOVE=y}

: ${MAKESCRIPT_STANDALONE=y}

call_genscript() {
   EXITCODE_HELP=64 ${GEN_SCRIPT} ${GEN_SCRIPT_ARGS-} "$@"
}

# void gargs ( *args, **GEN_SCRIPT_ARGS )
#
#  Adds args to GEN_SCRIPT_ARGS.
#
gargs() { GEN_SCRIPT_ARGS="${GEN_SCRIPT_ARGS-}${GEN_SCRIPT_ARGS:+ }$*"; }

list_scripts() { call_genscript --list; }

gen_script() {
   autodie call_genscript --chmod 0775 --verify "${1}" -O "${2}"
}

: ${MAKESCRIPT_SHLIB=/sh/lib/shlib.sh}

if yesno "${MAKESCRIPT_BASH=n}"; then
   gargs --bash
fi

if yesno "${MAKESCRIPT_STANDALONE=y}"; then
   gargs --standalone
else
   gargs --shlib "${MAKESCRIPT_SHLIB}"
fi

: ${MAKESCRIPT_DEST:=${SHLIB_PRJROOT:?}/build/scripts}
: ${MAKESCRIPT_FLAT=n}

: ${MAKESCRIPT_OVERWRITE=n}


if [ -z "$*" ]; then
   einfo "Building all scripts"
   set -- $(list_scripts)
   [ -n "$*" ] || die "nothing to build"
fi

for src; do
   if yesno "${MAKESCRIPT_FLAT}"; then
      dest="${src%.sh}"
      case "${dest}" in
         initramfs/*|lib/*|tmp/*|vdr/*|local/*)
            dest="${MAKESCRIPT_DEST}/${dest}"
         ;;
         *)
            dest="${MAKESCRIPT_DEST}/${dest##*/}"
         ;;
      esac
   else
      dest="${MAKESCRIPT_DEST}/${src%.sh}"
   fi

   einfo "Creating ${dest} (${src})"

   if [ ! -e "${dest}" ]; then
      gen_script "${src}" "${dest}"
   elif yesno "${MAKESCRIPT_OVERWRITE}"; then
      ewarn "Overwriting ${dest}"
      gen_script "${src}" "${dest}"
   else
      die "${dest} already exists."
   fi
done
