#@section NULL

#@export all from fs/zram/defsym
#@export all from fs/zram/logging

#@section vars
: ${ZRAM_REINIT_DELAY=}

#@section module_init_vars

ZRAM__NEXT_FREE_DEV=

#@section functions

# @private::protected zram__write_sysfs (
#    filename, value, **ZRAM_NAME, **ZRAM_BLOCK, **v0!
# )
#
zram__write_sysfs() {
   v0="${ZRAM_BLOCK:?}/${1:?}"
   if printf "${2?}" > "${v0}"; then
      return 0
   else
      zram_log_error "failed to write ${1}=${2%% *}"
      return 2
   fi
}

# int zram_is_disk_mounted ( dev=**ZRAM_DEV )
#
zram_is_disk_mounted() {
   disk_mounted "${1:-${ZRAM_DEV:?}}"
}

# int zram_is_swap_mounted ( dev=**ZRAM_DEV )
#
zram_is_swap_mounted() {
   [ -e /proc/swaps ] && \
      grep -q -- "^${1:-${ZRAM_DEV}}[[:blank:]]" /proc/swaps
}

# int zram_is_in_use ( dev=**ZRAM_DEV )
#
zram_is_in_use() {
   zram_is_disk_mounted "${@}" || zram_is_swap_mounted "${@}"
}

# int zram_is_free ( dev=**ZRAM_DEV )
#
zram_is_free() {
   ! zram_is_in_use "${@}"
}

# int zram_init_vars (
#    ident,
#    **ZRAM_NAME!, **ZRAM_DEV!, **ZRAM_BLOCK!, **ZRAM_SIZE_M!
# )
#
zram_init_vars() {
   #@varcheck 1

   ZRAM_NAME="zram${1#zram}"
   ZRAM_BLOCK="/sys/block/${ZRAM_NAME}"
   ZRAM_DEV="/dev/${ZRAM_NAME}"
   ZRAM_SIZE_M=

   if [ ! -e "${ZRAM_BLOCK}" ]; then
      zram_log_error "${ZRAM_BLOCK} does not exist."
      return 1

   elif [ ! -b "${ZRAM_DEV}" ]; then
      #mknod ZRAM_DEV
      if [ -e "${ZRAM_DEV}" ]; then
         zram_log_error "${ZRAM_DEV} is not a block device."
         return 2
      else
         zram_log_error "${ZRAM_DEV} does not exist."
         return 3
      fi

   else
      return 0
   fi
}

# void zram_zap_vars ( **ZRAM_*! )
#
zram_zap_vars() {
   ZRAM_NAME=
   ZRAM_DEV=
   ZRAM_BLOCK=
   ZRAM_SIZE_M=
}


# int zram_init (
#    ident, size_m=, type=, *type_init_args,
#    **ZRAM_NAME!, **ZRAM_DEV!, **ZRAM_BLOCK!, **ZRAM_SIZE_M!
# )
#
zram_init() {
   ZRAM_SIZE_M=
   local init_func=

   if [ -n "${3-}" ]; then
      init_func="zram_init__${3}"

      if ! function_defined "${init_func}"; then
         function_die "setup function ${init_func}() is missing."
         # @on-die-continue
         return 127
      fi
   fi


   ${AUTODIE_NONFATAL-} zram_init_vars "${1?}" || return
   [ -z "${2-}" ] || ${AUTODIE_NONFATAL-} zram_set_size "${2}"

   if [ -n "${init_func}" ]; then
      shift 3 || function_die "logical error"
      "${init_func}" "${@}"
   fi
}

# @private @need-globbing zram__find_and_init_any ( *args )
#
#  Helper function for zram_init_any().
#
zram__find_and_init_any() {
   local iter ident
   for iter in "/sys/block/zram"*; do
      [ -e "${iter}" ] || continue

      ident="${iter#/sys/block/zram}"

      if is_natural "${ident}" && zram_ident_is_free "${ident}"; then

         if zram_init "${ident}" "${@}"; then
            ZRAM__NEXT_FREE_DEV=$(( ${ident} + 1 ))
            return 0
         else
            ZRAM__NEXT_FREE_DEV=
            return 1
         fi
      fi
   done

   zram_log_error "could not find any free zram dev"
   return 2
}

# int zram_init_any (
#    size_m, *args,
#    **ZRAM_NAME!, **ZRAM_DEV!, **ZRAM_BLOCK!, **ZRAM_SIZE_M!,
#    **ZRAM__NEXT_FREE_DEV!
# )
#
#  Like zram_init(), but chooses any free zram disk.
#  The %size_m parameter is mandatory.
#
zram_init_any() {
   local k kmax

   [ -n "${1-}" ] || function_die "bad usage (missing size_m arg)."

   if [ -n "${ZRAM__NEXT_FREE_DEV-}" ]; then
      k="${ZRAM__NEXT_FREE_DEV}"
      kmax=$(( ${k} + 3 ))
      #@safety_check is_natural "${k}" && is_positive "${k}" || function_die

      while [ ${k} -lt ${kmax} ]; do
         if zram_ident_is_free "${k}"; then
            if zram_init "${k}" "${@}"; then
               ZRAM__NEXT_FREE_DEV=$(( ${k} + 1 ))
               return 0
            else
               ZRAM__NEXT_FREE_DEV=
               return 1
            fi
         fi
         k=$(( ${k} + 1 ))
      done

      ZRAM__NEXT_FREE_DEV=
   fi

   with_globbing_do zram__find_and_init_any "${@}"
}

# int zram_ident_is_free ( ident )
#
zram_ident_is_free() {
   local istate=
   {
      read -r istate < "/sys/block/zram${1:?}/initstate" && \
      [ ${istate:--1} -eq 0 ]
   } 1>>${DEVNULL} 2>>${DEVNULL}
}




# int zram_destruct ( [ident], **ZRAM_! )
#
zram_destruct() {
   #@unchecked-int ZRAM__NEXT_FREE_DEV
   local next_free=

   case "${ZRAM_NAME#zram}" in
      [0-9]*)
         next_free="${ZRAM_NAME#zram}"
      ;;
   esac

   if \
      ${AUTODIE_NONFATAL-} zram_reinit "${1-}" "" && \
      ${AUTODIE_NONFATAL-} zram_zap_vars
   then
      [ -z "${next_free}" ] || ZRAM__NEXT_FREE_DEV="${next_free}"
   else
      zram_log_error "failed to release device."
      return 1
   fi
}

# int zram_reinit (
#    ident=, size_m=, type=, *type_init_args,
#    **ZRAM_NAME!, **ZRAM_DEV!, **ZRAM_BLOCK!, **ZRAM_SIZE_M!
# )
#
zram_reinit() {
   if [ ${#} -gt 0 ]; then
      [ "${1:-}" = "_" ] || \
         ${AUTODIE_NONFATAL-} zram_init_vars "${1}" || return
      shift || function_die
   fi

   ${AUTODIE_NONFATAL-} zram_reset

   if [ -n "${2-}" ] || [ -n "${3-}" ]; then
      [ -n "${ZRAM_REINIT_DELAY-}" ] || \
         sleep ${ZRAM_REINIT_DELAY} || function_die
      zram_init "${ZRAM_NAME}" "${@}"
   fi
}


# int zram_set_size ( size_m, **ZRAM_NAME, **ZRAM_BLOCK, **ZRAM_SIZE_M! )
#
zram_set_size() {
   #@varcheck 2
   ZRAM_SIZE_M=

   local size_b v0

   if [ ${2} -eq 0 ]; then
      ${AUTODIE_NONFATAL-} zram__write_sysfs reset 1 && ZRAM_SIZE_M=0

   else
      size_b=$(( ${2} * ${ZRAM_BYTES_TO_MBYTES_FACTOR} ))

      if [ ${size_b} -gt 0 ]; then
         zram_log_info "Setting size to ${2} mbytes (${size_b})"
         ${AUTODIE_NONFATAL-} zram__write_sysfs disksize ${size_b} && \
         ZRAM_SIZE_M="${2}"

      elif is_negative ${2}; then
         function_die "bad usage."

      else
         # how much RAM you got?
         function_die \
            "overflow: ${2} * ${ZRAM_BYTES_TO_MBYTES_FACTOR} != ${size_b}"
      fi
   fi
}

# int zram_reset ( **ZRAM_NAME, **ZRAM_BLOCK, **ZRAM_DEV, **ZRAM_SIZE_M! )
#
zram_reset() {
   local v0

   if zram_is_disk_mounted; then
      zram_log_info "Unmounting disk ${ZRAM_DEV}"
      ${AUTODIE_NONFATAL-} do_unmount "${ZRAM_DEV}" || return

   elif zram_is_swap_mounted; then
      zram_log_info "Deactivating swap space ${ZRAM_DEV}"
      ${AUTODIE_NONFATAL-} ${X_SWAPOFF:?} "${ZRAM_DEV}" || return
   fi

   #zram_set_size 0
   ${AUTODIE_NONFATAL-} zram__write_sysfs reset 1 && ZRAM_SIZE_M=0
}
