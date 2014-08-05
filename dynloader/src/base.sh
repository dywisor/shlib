if [ -z "${__HAVE_SHLIB_DYNLOADER_CORE__-}" ]; then
set -u

readonly __HAVE_SHLIB_DYNLOADER_CORE__=y

unset -v SHLIB_DYNLOADER__IS_SET_UP

readonly SHLIB_DYNLOADER__DEFAULT_IFS="${IFS}"

SHLIB_DYNLOADER_MSG_PREFIX="shlib_dynloader: "

# void shlib_dynloader__print ( message )
#
shlib_dynloader__print() {
   printf "%s%s\n" "${SHLIB_DYNLOADER_MSG_PREFIX-}" "${1-}" 1>&2
}

# shlib_dynloader__error ( *message, exit_code=2, **SHLIB_DYNLOADER_ON_ERROR )
#
shlib_dynloader__error() {
   while [ ${#} -gt 1 ]; do
      shlib_dynloader__print "${1}"
      shift
   done

   case "${1-}" in
      [0-9]*)
         true
      ;;
      *)
         if [ -n "${1+SET}" ]; then
            shlib_dynloader__print "${1}"
            shift
         fi
      ;;
   esac

   case "${SHLIB_DYNLOADER_ON_ERROR-}" in
      'return')
         return ${1:-2}
      ;;
      ''|'exit')
         exit ${1:-2}
      ;;
      *)
         shlib_dynloader__print \
            "illegal SHLIB_DYNLOADER_ON_ERROR=${SHLIB_DYNLOADER_ON_ERROR-}"
         shlib_dynloader__print "Exiting."
         exit 250
      ;;
   esac
}

# shlib_dynloader__realpath ( fspath, **v0! )
#
shlib_dynloader__realpath() {
   : ${1:?}
   v0="$(readlink -f "${1}")"

   [ -z "${v0}" ] || return 0

   shlib_dynloader__error "readlink failed to resolve${2:+ ${2}} ${1}"
   return ${?}
}

# @VARIANT<SHLIB_DYNLOADER_DEBUG=y|n>
# @private void shlib_dynloader__debug_print ( message )
#
if [ "${SHLIB_DYNLOADER_DEBUG:-n}" = "y" ]; then
shlib_dynloader__debug_print() {
   shlib_dynloader__print "${1-%UNSET%}"
}
else
shlib_dynloader__debug_print() { return 0; }
fi

# int shlib_dynloader__setup (...)
#
shlib_dynloader__setup() {
   local v0
   : ${SHLIB_DYNLOADER_PATH=}

   if [ -z "${USE_BASH+SET}" ]; then
      [ -n "${BASH_VERSION-}" ] && USE_BASH=y || USE_BASH=n
   fi

   if [ -n "${SHLIB_ROOT-}" ]; then
      for v0 in "${SHLIB_ROOT}/include" "${SHLIB_ROOT}/lib" _; do
         if [ "${v0}" = "_" ]; then
            shlib_dynloader__error \
               "SHLIB_ROOT '${SHLIB_ROOT}' has no lib or include directory!"
            return ${?}

         elif [ -d "${v0}" ]; then
            # @BREAK_FOR_LOOP
            break
         fi
      done

      case ":${SHLIB_DYNLOADER_PATH-}:" in
         '::')
            SHLIB_DYNLOADER_PATH="${v0}"
         ;;
         *":${v0}:"*)
            true
         ;;
         *)
            SHLIB_DYNLOADER_PATH="${SHLIB_DYNLOADER_PATH}:${v0}"
         ;;
      esac

   fi

   if [ -z "${SHLIB_DYNLOADER_PATH}" ]; then
      shlib_dynloader__debug_print "SHLIB_DYNLOADER_PATH is empty!"
   fi

   # %SHLIB_DYNLOADER_PATH should not be modified after loading modules
   #readonly SHLIB_DYNLOADER_PATH

   if [ -n "${SHLIB_DYNLOADER_DEPTRACE-}" ]; then
      shlib_dynloader__realpath \
         "${SHLIB_DYNLOADER_DEPTRACE}" "deptrace file path" || return ${?}
      SHLIB_DYNLOADER_DEPTRACE="${v0}"

      if \
         ! mkdir -p -- "${SHLIB_DYNLOADER_DEPTRACE%/*}" || \
         ! : >  "${SHLIB_DYNLOADER_DEPTRACE}"
      then
         shlib_dynloader__error \
            "failed to initialize deptrace file ${SHLIB_DYNLOADER_DEPTRACE}"
         return ${?}
      fi
   fi


   SHLIB_DYNLOADER__IS_SET_UP=true
}


shlib_dynloader_setup_if_required() {
   [ -n "${SHLIB_DYNLOADER__IS_SET_UP-}" ] || \
      shlib_dynloader__setup
}



fi # __HAVE_SHLIB_DYNLOADER_CORE__
