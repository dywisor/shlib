# @section functions
eval_scriptinfo() {
   local x
   if [ ${#} -gt 0 ]; then
      x="${1}"
   else
      x="${0}"
   fi

   if [ -n "${x}" ]; then
      SCRIPT_FILE="$( realpath -Ls "${x}" 2>>${DEVNULL} )"
      if [ -z "${SCRIPT_FILE}" ]; then
         SCRIPT_FILE="$(readlink -f "${x}" 2>>${DEVNULL} )"
         [ -n "${SCRIPT_FILE}" ] || SCRIPT_FILE="${x}"
      fi
      SCRIPT_DIR="${SCRIPT_FILE%/*}"

   else
      SCRIPT_FILE="UNDEF"
      SCRIPT_DIR="${PWD}"
   fi

   SCRIPT_FILENAME="${SCRIPT_FILE##*/}"
   SCRIPT_NAME="${SCRIPT_FILENAME%.*}"
}

# @section module_init
eval_scriptinfo
