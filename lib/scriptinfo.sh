eval_scriptinfo() {
   SCRIPT_FILE="$( realpath -Ls "${0}" 2>>${DEVNULL} )"
   if [ -z "${SCRIPT_FILE}" ]; then
      SCRIPT_FILE="$(readlink -f "${0}" 2>>${DEVNULL} )"
      [ -n "${SCRIPT_FILE}" ] || SCRIPT_FILE="${0}"
   fi
   SCRIPT_FILENAME="${SCRIPT_FILE##*/}"
   SCRIPT_NAME="${SCRIPT_FILENAME%.*}"
   SCRIPT_DIR="${SCRIPT_FILE%/*}"
}

eval_scriptinfo
