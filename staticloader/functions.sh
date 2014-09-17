#!/bin/sh

SHLIB_STATICLOADER_PRELINKED_ROOT="/tmp/XXX"
SHLIB_STATICLOADER_MODULES_ROOT="${PWD}/lib"
SHLIB_STATICLOADER_PRELINK_SUFFIX=".prelink.sh"


shlib_staticloader_die() {
   echo "${1:+staticloader died: }${1:-staticloader died.}" 1>&2
   exit ${2:-240}
}

shlib_staticloader_load_module() {
   : ${SHLIB_STATICLOADER_PRELINKED_ROOT:?}
   : ${SHLIB_STATICLOADER_PRELINK_SUFFIX:?}

   local module modfile
   module="${1%.sh}"
   module="${SHLIB_STATICLOADER_PRELINKED_ROOT%/}/${module#/}"

   set --

   for modfile in \
      "${module}${SHLIB_STATICLOADER_PRELINK_SUFFIX}" \
      "${module}/__all__${SHLIB_STATICLOADER_PRELINK_SUFFIX}"
   do
      if [ -f "${modfile}" ]; then
         . "${modfile}" || return ${?}
         return 0
      fi
   done

   return 22
}

shlib_staticloader_load_modules() {
   while [ $# -gt 0 ]; do
      [ -z "${1}" ] || shlib_staticloader_load_module "${1}" || return
      shift
   done
}

shlib_staticloader_load_deps_for_file() {
   __script_file=
   local depfile script_file dep

   if [ -h "${1}" ]; then
      script_file="$(readlink -f "${1}")"
      if [ -z "${script_file}" ] || [ ! -f "${script_file}" ]; then
         shlib_staticloader_die \
            "failed to resolve path of symlinked script: ${1} (${script_file}?)"
      fi
   else
      script_file="${1}"
   fi

   for depfile in \
      "${script_file}.depend" "${script_file%.sh}.depend"
   do
      if [ -f "${depfile}" ]; then
         while read -r dep; do
            case "${dep}" in
               ''|[\#\!]*)
                  true
               ;;
               *)
                  shlib_staticloader_load_module "${dep}" || \
                     shlib_staticloader_die "failed to load module: ${dep}"
               ;;
            esac
         done < "${depfile}"

         break
      fi
   done

   __script_file="${script_file}"
   return 0

}

shlib_staticloader_main() {
   local __nodeps __mode __script_file

   shlib_staticloader_load_module scriptinfo || \
      shlib_staticloader_die "failed to load module: scriptinfo"

   __nodeps=false
   while [ $# -gt 0 ]; do
      case "${1-}" in
         -m|--module)
            if [ -z "${2-}" ]; then
               echo "ERR: staticloader: ${1} option needs a <module> arg." 1>&2
               return 240
            else
               shlib_staticloader_load_module "${2}" || \
                  shlib_staticloader_die "failed to load module: ${2}"
            fi
            shift 2
         ;;
         --)
            shift
            break
         ;;
         --nodeps)
            __nodeps=true
            shift
         ;;
         --exec|--eval|--file)
            __mode="${1#--}"
            shift
         ;;
         -*)
            set "$1" || return
            shift
         ;;
         *)
            break
         ;;
      esac
   done

   case "${__mode-}" in
      "exec")
         "$@"
      ;;
      "eval")
         eval "$@"
      ;;
      ""|"file")
         [ -n "${1-}" ] && [ -f "${1}" ] || \
            shlib_staticloader_die "not a file: ${1}" 241

         if ! ${__nodeps}; then
            shlib_staticloader_load_deps_for_file "${1}" || \
               shlib_staticloader_die "failed to load deps"
         fi

         eval_scriptinfo "${__script_file:?}" || \
            shlib_staticloader_die "eval_scriptinfo() returned $?"

         shift && . "${SCRIPT_FILE:?}" "$@"
      ;;
      *)
         shlib_staticloader_die "unknown mode: ${__mode-%UNSET%}"
      ;;
   esac
}
