#@section functions

# int zram_setup_swap ( *args, **ZRAM_! )
#
zram_setup_swap() {
   zram_init_swap "${@}" && zram_swapon
}

# int zram_init_swap ( ident, size_m=**ZRAM_SWAP_DEFAULT_SIZE, **ZRAM_! )
#
zram_init_swap() {
   zram_init "${1?}" "${2:-${ZRAM_SWAP_DEFAULT_SIZE:?}}" && \
   zram_mkswap
}

# int zram_mkswap ( **ZRAM_DEV )
#
zram_mkswap() {
   ${AUTODIE_NONFATAL-} ${X_MKSWAP:?} "${ZRAM_DEV:?}" 1>>${DEVNULL}
}

# int zram_swapon ( priority=default, **ZRAM_DEV )
#
zram_swapon() {
   local prio

   if [ -z "${1+SET}" ]; then
      prio="${ZRAM_SWAP_BASE_PRIORITY}"
   elif [ -z "${1}" ]; then
      prio=
   else
      prio="-p ${1}"
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
zram_swapoff() {
   ${AUTODIE_NONFATAL-} ${X_SWAPOFF:?} "${ZRAM_DEV:?}"
}
