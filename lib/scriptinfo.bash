eval_scriptinfo() {
   local x="${BASH_SOURCE[0]}"

   SCRIPT_FILE="$( realpath -Ls "${x}" 2>>${DEVNULL} )"
   if [[ -z "${SCRIPT_FILE}" ]]; then
      SCRIPT_FILE="$(readlink -f "${x}" 2>>${DEVNULL} )"
      [[ -n "${SCRIPT_FILE}" ]] || SCRIPT_FILE="${x}"
   fi
   SCRIPT_FILENAME="${SCRIPT_FILE##*/}"
   SCRIPT_NAME="${SCRIPT_FILENAME%.*}"
   SCRIPT_DIR="${SCRIPT_FILE%/*}"
}

eval_scriptinfo
