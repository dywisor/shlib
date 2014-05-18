#@section NULL

#@export all from fs/zram/defsym
#@export all from fs/zram/logging

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

   ZRAM_NAME="zram${1%% *}"
   ZRAM_DEV="/sys/block/${ZRAM_NAME}"
   ZRAM_BLOCK="/dev/${ZRAM_NAME}"
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
#    ident, size_m=, **ZRAM_NAME!, **ZRAM_DEV!, **ZRAM_BLOCK!, **ZRAM_SIZE_M!
# )
#
zram_init() {
   ZRAM_SIZE_M=


   ${AUTODIE_NONFATAL-} zram_init_vars "${1?}" || return
   [ -z "${2-}" ] || ${AUTODIE_NONFATAL-} zram_set_size "${2}"
}

# int zram_destruct ( [ident], **ZRAM_! )
#
zram_destruct() {
   ${AUTODIE_NONFATAL-} zram_reinit "${1-}" "" && \
   ${AUTODIE_NONFATAL-} zram_zap_vars
}

# int zram_reinit (
#    [ident], size_m=,
#    **ZRAM_NAME[!], **ZRAM_DEV[!], **ZRAM_BLOCK[!], **ZRAM_SIZE_M!
# )
#
zram_reinit() {
   if [ ${#} -gt 1 ]; then
      [ -z "${1}" ] || ${AUTODIE_NONFATAL-} zram_init_vars "${1}" || return
      shift || die
   fi

   ${AUTODIE_NONFATAL-} zram_reset
   [ -z "${1-}" ] || ${AUTODIE_NONFATAL} zram_set_set "${1}"
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
         die "bad usage."

      else
         # how much RAM you got?
         die "overflow: ${2} * ${ZRAM_BYTES_TO_MBYTES_FACTOR} != ${size_b}"
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
