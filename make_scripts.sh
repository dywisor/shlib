#!/bin/sh
## (EXPERIMENTAL)
set -u

. "${0%/*}/loader.sh" "${0%/*}/lib" && \
   loader_load core strutil/yesno fs/dodir_minimal || exit

readonly GEN_SCRIPT="${SCRIPT_DIR}/generate_script.sh"

: ${MAKESCRIPT_STANDALONE=y}

__gen_script_call() {
   EXITCODE_HELP=64 ${GEN_SCRIPT} ${GEN_SCRIPT_ARGS-} "$@"
}

# __gen_script_create ( src, dest )
__gen_script_create() {
   if __gen_script_call "${1}" > "${2}" && chmod 0755 "${2}"; then
		[ -s "${2}" ] || ewarn "${2} is empty!"
		return 0
	else
		rm -f "${2}"
		return 1
	fi
}

list_scripts() {
   __gen_script_call --list
}

gen_script() {
   autodie dodir_clean "${2%/*}" && \
   autodie __gen_script_create "${1}" "${2}"
}

: ${MAKESCRIPT_SHLIB=/sh/lib/shlib.sh}

if yesno "${MAKESCRIPT_BASH=n}"; then
   GEN_SCRIPT_ARGS="${GEN_SCRIPT_ARGS-} --bash"
fi
if yesno "${MAKESCRIPT_STANDALONE=y}"; then
   GEN_SCRIPT_ARGS="${GEN_SCRIPT_ARGS-} --standalone"
else
   GEN_SCRIPT_ARGS="${GEN_SCRIPT_ARGS-} --shlib ${MAKESCRIPT_SHLIB}"
fi

: ${MAKESCRIPT_DEST:=${SCRIPT_DIR}/build/scripts}

: ${MAKESCRIPT_FLAT=n}

: ${MAKESCRIPT_OVERWRITE=n}


if [ -z "$*" ]; then
   einfo "Building all scripts"
   set -- `list_scripts`
   [ -n "$*" ] || die "nothing to build"
fi

for src; do
   if yesno "${MAKESCRIPT_FLAT}"; then
      dest="${src%.sh}"
      case "${dest}" in
         initramfs/*|lib/*)
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
