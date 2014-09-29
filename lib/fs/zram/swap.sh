#@section functions

# @zram_init_any zram_swap (
#    num_swaps=1, size_m=**ZRAM_SWAP_DEFAULT_SIZE, swapon="y",
#    **ZRAM_!, **v0!
# )
#
#  Sets up the requested number of swap devices, each with the given size.
#  The swap space is usually activated after setting it up,
#  pass any value != 'y' as third parameter to skip swapon.
#
#  Immediately returns on error.
#  Stores a list of activated (or allocated if %swapon != 'y') zram names
#  in %v0. Hides ZRAM_* vars if num_swaps is != 1.
#
zram_swap() {
   v0=
   local num_swaps size_m iter

   num_swaps="${1:-1}"
   size_m="${2:-${ZRAM_SWAP_DEFAULT_SIZE:?}}"

   if [ ${num_swaps} -eq 0 ]; then
      return 0
   elif [ ${num_swaps} -eq 1 ]; then
      zram_zap_vars
   else
      local ZRAM_NAME= ZRAM_DEV= ZRAM_BLOCK= ZRAM_SIZE_M=
   fi

   iter=0
   while [ ${iter} -lt ${num_swaps} ]; do
      iter=$(( ${iter} + 1 ))

      if ! zram_init_any "${size_m}" swap; then
         zram_log_error "failed to allocate zram swap dev (swapno=${iter})."
         return 5

      elif [ "${3:-X}" != "y" ] || zram_swapon; then
         v0="${v0-} ${ZRAM_NAME}"

      else
         zram_destruct || \
            zram_log_error -0 "zram_destruct(${ZRAM_NAME:-%UNSET%})=${?} !!!"

         return 6
      fi

   done

   v0="${v0# }"
}


# @zram_type_init zram_init__swap ( **ZRAM_NAME, **ZRAM_DEV )
#
#  Runs mkswap %ZRAM_DEV.
#
zram_init__swap() {
   ${AUTODIE_NONFATAL-} ${X_MKSWAP:?} \
      -L "${ZRAM_FS_NAME}" "${ZRAM_DEV:?}" 1>>${DEVNULL}
}

# int zram_swapon ( priority=default, **ZRAM_DEV )
#
#  Activates a zram swap device.
#
zram_swapon() {
   local prio

   if [ -z "${1+SET}" ]; then
      prio="${ZRAM_SWAP_BASE_PRIORITY}"
   elif [ -z "${1}" ]; then
      prio=
   else
      prio="${1}"
   fi

   zram_log_info \
      "Activating swap space ${ZRAM_DEV} with priority=${prio:-<default>}"

   if \
      ${AUTODIE_NONFATAL-} ${X_SWAPON:?} ${prio:+-p ${prio}} "${ZRAM_DEV:?}"
   then
      return 0
   else
      zram_log_error -0 "swapon failed! (rc=${?})"
      return 4
   fi
}

# int zram_swapoff ( **ZRAM_DEV )
#
#  Deactivates a zram swap device.
#
zram_swapoff() {
   ${AUTODIE_NONFATAL-} ${X_SWAPOFF:?} "${ZRAM_DEV:?}"
}
