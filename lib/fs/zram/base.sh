#@section NULL

#@export all from fs/zram/defsym
#@export all from fs/zram/logging


#@section vars

# ZRAM_REINIT_DELAY, if set and not empty:
#  sleep for the given amount of time after resetting a zram device
#  before reinitializing it
#
: ${ZRAM_REINIT_DELAY=}


#@section module_init_vars

# ZRAM__NEXT_FREE_DEV
#  private variable that keeps track of the "next" free zram device
#  in /sys/block (zram*)
#
#  This helps to speed up zram_init_any(), which will try to initialize
#   /sys/block/zram{ZRAM__NEXT_FREE_DEV..(ZRAM__NEXT_FREE_DEV+2)}
#  before iterating over /sys/block/zram*.
#
#  Has to be an int>=0 or empty (empty := iterate over /sys/block/zram*)
#
ZRAM__NEXT_FREE_DEV=


#@section funcdef

# @funcdef int zram_init_any <type> zram_<type> ( *args, **ZRAM_! )
#
#  Initializes zero or more zram devices of type %type in accordance to %args.
#
#  The zram allocation is done automatically (i.e. pick any free device).
#
#  Returns true on success, else false.
#

# @funcdef int zram_type_init <type> zram_init__<type> ( *args, **ZRAM_ )
#
#  type-specific init code.
#
#  Returns true on success, else false.
#


#@section functions

# int zram_load_module (
#    num_devices, modprobe_args=, module_args=,
#    **ZRAM_NUM_STATIC_DEVICES:=0
# )
#
#  Loads the zram module with
#    num_devices=(%num_devices + %ZRAM_NUM_STATIC_DEVICES)
#  if not already loaded.
#
#  Returns 0 on success (= requested # of devices is now available),
#  1 of modprobe failed, 2 if not enough free devices available,
#  and 64 if num_devices was invalid.
#
zram_load_module() {
   local ZRAM_NAME=modprobe
   local v0 k

   k=$(( ${1:?} + ${ZRAM_NUM_STATIC_DEVICES:-0} ))
   shift || function_die

   if ! [ ${k} -gt 0 ]; then
      # also catches "not a number"
      zram_log_error "invalid number of devices: ${k}"
      return ${EX_USAGE}

   elif zram_get_free_device_count; then
      if [ ${k} -gt ${v0} ]; then
         zram_log_debug "zram module already loaded (or builtin)"
         return 0
      else
         zram_log_warn  "zram module already loaded (or builtin)"
         zram_log_error \
            "not enough free devices available: have ${v0}, need ${k}."
         return 2
      fi
   else
      zram_log_info "Loading the zram module, num_devices=${k}"
      if \
         ${AUTODIE_NONFATAL-} ${X_MODPROBE:?} ${2-} zram num_devices=${k} ${3-}
      then
         return 0
      else
         zram_log_error "Failed to load the zram module! (rc=${?})"
         return 1
      fi
   fi
}

# int zram_autoload_module (
#    num_devices, **ZRAM_NUM_STATIC_DEVICES:=0,
#    **ZRAM_LOAD_MODULE=
# )
#
#  A wrapper that "possibly" loads the zram module,
#  depending on %ZRAM_LOAD_MODULE.
#
zram_autoload_module() {
   : ${1?}

   case "${ZRAM_LOAD_MODULE-}" in
      ''|'n'|'false'|':')
         if [ -e /sys/block/zram0 ]; then
            return 0
         else
            local ZRAM_NAME=autoload_module
            zram_log_error \
               "zram is not available and auto-modprobe is disabled!"
            return 2
         fi
      ;;

      'y'|'true'|'modprobe')
         zram_load_module "${1}"
         # explicit return (not necessary)
         return ${?}
      ;;

      *)
         # unpacked function call
         ${ZRAM_LOAD_MODULE} "${1}"
         # explicit return (not necessary)
         return ${?}
      ;;
   esac
}


# @private::protected zram__write_sysfs (
#    filename, value, **ZRAM_NAME, **ZRAM_BLOCK, **v0!
# )
#
#  Writes %value to %ZRAM_BLOCK/%filename and logs failure.
#
#  Returns: success (true/false)
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
#  Returns true if %dev (%ZRAM_DEV) is mounted ("as disk", not swap etc),
#  else false.
#
zram_is_disk_mounted() {
   disk_mounted "${1:-${ZRAM_DEV:?}}"
}

# int zram_is_swap_mounted ( dev=**ZRAM_DEV )
#
#  Returns true if %dev (%ZRAM_DEV) is an activated swap device, else false.
#
zram_is_swap_mounted() {
   [ -e /proc/swaps ] && \
      grep -q -- "^${1:-${ZRAM_DEV}}[[:blank:]]" /proc/swaps
}

# int zram_is_in_use ( dev=**ZRAM_DEV )
#
#  Returns true if %dev (%ZRAM) is used as disk or swap.
#
zram_is_in_use() {
   zram_is_disk_mounted "${@}" || zram_is_swap_mounted "${@}"
}

# int zram_is_free ( dev=**ZRAM_DEV )
#
#  Returns true if %dev (%ZRAM) is free (i.e. "not in use").
#
#  Not to be confused with the init state (disksize != 0 etc.).
#
zram_is_free() {
   ! zram_is_in_use "${@}"
}

# int zram_init_vars (
#    ident,
#    **ZRAM_NAME!, **ZRAM_FS_NAME!, **ZRAM_DEV!, **ZRAM_BLOCK!, **ZRAM_SIZE_M!
# )
#
#  Initializes zram device related variables.
#
#  Ident must be an integer >= 0, optionally prefixed with "zram",
#  e.g. "0" or "zram1".
#  Other non-empty values are also accepted, but _probably_ won't work.
#
zram_init_vars() {
   #@varcheck 1

   zram_zap_vars
   ZRAM_NAME="zram${1#zram}"
   ZRAM_BLOCK="/sys/block/${ZRAM_NAME}"
   ZRAM_DEV="/dev/${ZRAM_NAME}"
   # by default, ZRAM_FS_NAME == ZRAM_NAME
   ZRAM_FS_NAME="${ZRAM_NAME}"

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
#  Unsets all zram device related variables (by assigning the empty str).
#
zram_zap_vars() {
   ZRAM_NAME=
   ZRAM_DEV=
   ZRAM_BLOCK=
   ZRAM_SIZE_M=
   ZRAM_FS_NAME=
}


# int zram_init (
#    ident, size_m=, type=, *type_init_args,
#    **ZRAM_NAME!, **ZRAM_FSNAME!, **ZRAM_DEV!, **ZRAM_BLOCK!, **ZRAM_SIZE_M!
# )
#
#  Initializes a zram device referenced by its identifier with the
#  requested size, which has to be an integer greater than 0 or empty.
#
#  Also accepts a %type parameter.
#  If set and not empty, the type-specific init function(1) will be called
#  after the generic initialization (with *type_init_args).
#
#  (1) zram_init__%type()
#
#  Note that this is a "low-level" function.
#  Most zram device "types" implement a zram_%type() function,
#  which usually involves zram_init_any(), which, in turn,
#  calls this function.
#
#  Another note: %types usually require a fully initialized device (disksize!)
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

# @private @need-globbing int zram__find_and_init_any (
#    *args, **ZRAM__NEXT_FREE_DEV!
# )
#
#  Helper function for zram_init_any().
#
#  Iterates over /sys/block/zram* until an uninialized zram dev is found,
#  or returns 2 if none available (and logs this as error).
#
#  Initializes the zram device with the given args (by calling zram_init())
#  and returns 0 on success, else 1.
#  -> Does not try to initialize more than one device.
#
zram__find_and_init_any() {
   local iter ident
   for iter in "/sys/block/zram"*; do
      [ -e "${iter}" ] || continue

      ident="${iter#/sys/block/zram}"

      if is_natural "${ident}" && zram_sysdev_is_free "${itter}"; then

         if zram_init "${ident}" "${@}"; then
            # update ZRAM__NEXT_FREE_DEV
            ZRAM__NEXT_FREE_DEV=$(( ${ident} + 1 ))
            return 0
         else
            # failed to init %ident - reset ZRAM__NEXT_FREE_DEV
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
#    **ZRAM_NAME!, **ZRAM_FSNAME!, **ZRAM_DEV!, **ZRAM_BLOCK!, **ZRAM_SIZE_M!,
#    **ZRAM__NEXT_FREE_DEV!
# )
#
#  Like zram_init(), but chooses any free zram disk.
#  The %size_m parameter is mandatory.
#
#  To achieve this, this function searches for a dev in /sys/block/zram*
#  whose initstate is 0.
#
#  %ZRAM__NEXT_FREE_DEV is used to speed up consecutive function calls
#  within one program execution.
#
#  Returns: success (true/false)
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
               # update ZRAM__NEXT_FREE_DEV
               ZRAM__NEXT_FREE_DEV=$(( ${k} + 1 ))
               return 0
            else
               # reset ZRAM__NEXT_FREE_DEV
               ZRAM__NEXT_FREE_DEV=
               return 1
            fi
         fi
         k=$(( ${k} + 1 ))
      done

      ZRAM__NEXT_FREE_DEV=
   fi

   # fall back to find_and_init_any
   with_globbing_do zram__find_and_init_any "${@}"
}

# int zram_ident_is_free ( ident )
#
#  Returns true if a zram device referenced by its identifier is not
#  initialized, else false.
#
zram_ident_is_free() {
   : ${1:?}
   zram_sysdev_is_free "/sys/block/zram${1#zram}"
}

# int zram_sysdev_is_free ( sysfs_path )
#
#  Returns true if the given zram device is not initialized, else false.
#
#  initialized <=> %sysfs_path/initstate == 0
#
zram_sysdev_is_free() {
   : ${1:?}
   local istate
   read -r istate < "${1:?}/initstate" 1>>${DEVNULL} 2>>${DEVNULL} && \
      [ ${istate:--1} -eq 0 ]
}

# int zram_get_free_device_count ( **v0! )
#
#  Determines the number of uninialized zram devices in /sys/block and
#  stores it in %v0.
#
#  Returns 0 if any zram device existed (whether initialized or not),
#  else 1.
#
zram_get_free_device_count() {
   v0=
   local iter glob_restore=

   if check_globbing_enabled; then
      glob_restore=false
   else
      set +f
      glob_restore=true
   fi

   for iter in "/sys/block/zram"?*; do
      if [ ! -e "${iter}/initstate" ]; then
         true

      elif zram_sysdev_is_free "${iter}"; then
         v0=$(( ${v0:-0} + 1 ))

      else
         : ${v0:=0}
      fi
   done

   ! ${glob_restore} || set -f

   [ -n "${v0}" ]
}


# int zram_destruct ( [ident], **ZRAM_!, **ZRAM__NEXT_FREE_DEV! )
#
#  Destroys a zram device, either %ZRAM_DEV or, if specified, %ident.
#
#  Handles unmounting/swap deactivation and updates %ZRAM__NEXT_FREE_DEV.
#
#  Returns: success (true/false)
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
#    **ZRAM_NAME!, **ZRAM_FSNAME!, **ZRAM_DEV!, **ZRAM_BLOCK!, **ZRAM_SIZE_M!,
#    **ZRAM_REINIT_DELAY
# )
#
#  Reinitializes a zram device.
#  Basically, this is zram_destruct() followed by zram_init(),
#  optionally with a sleep delay before initialization.
#
#  Does not update %ZRAM__NEXT_FREE_DEV.
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

# int zram_set_size (
#    size_m, **ZRAM_NAME, **ZRAM_BLOCK, **ZRAM_SIZE_M!
# )
#
#  Initializes the disk size of a zram device (%ZRAM_BLOCK).
#
#  %size_m has to be an integer >= 0.
#
#  Returns: success (true/false)

zram_set_size() {
   #@varcheck 1
   ZRAM_SIZE_M=

   local size_b v0

   if [ ${1} -eq 0 ]; then
      ${AUTODIE_NONFATAL-} zram__write_sysfs reset 1 && ZRAM_SIZE_M=0

   else
      size_b=$(( ${1} * ${ZRAM_BYTES_TO_MBYTES_FACTOR} ))

      if [ ${size_b} -gt 0 ]; then
         zram_log_info "Setting size to ${1} mbytes (${size_b})"
         ${AUTODIE_NONFATAL-} zram__write_sysfs disksize ${size_b} && \
         ZRAM_SIZE_M="${1}"

      elif is_negative ${1}; then
         function_die "bad usage."

      else
         # how much RAM you got?
         function_die \
            "overflow: ${1} * ${ZRAM_BYTES_TO_MBYTES_FACTOR} != ${size_b}"
      fi
   fi
}

# int zram_reset (
#    **ZRAM_NAME, **ZRAM_FSNAME, **ZRAM_BLOCK, **ZRAM_DEV, **ZRAM_SIZE_M!
# )
#
#  Unmounts/Deactivates %ZRAM_DEV and resetsd %ZRAM_BLOCK.
#
#  Returns: success (true/false)
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
