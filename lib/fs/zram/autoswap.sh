#@section functions

# @zram_init_any <swap> zram_autoswap (
#    max_swap_space_spec := <default>,
#    min_swapdev_size    := **ZRAM_SWAP_DEFAULT_SIZE,
#    max_num_swaps       := <cpu core count>,
#    max_sys_mem         := <sys mem>,
#
#    **ZRAM_LOAD_MODULE, **ZRAM_!, **v0!
# )
#
#  Calculates the max. swap space and partitions it into up to %max_num_swaps
#  swap devices, each with at least %min_swapdev_size size (in megabytes).
#
#  %max_swap_space_spec can either be a number (-> swap space in megabytes)
#  or a fraction "/<NUMBER>" of %max_sys_mem.
#  The default is "/2" => "use half of the system memory as swap space".
#
#  Passes %v0, %ZRAM_* from zram_swap().
#
#  Autoloads the zram module depending on %ZRAM_LOAD_MODULE.
#
zram_autoswap() {
   v0=

   local zram_num_swaps zram_swap_size_m

   ${AUTODIE_NONFATAL-} zram_calculate_autoswap "${@}" && \
   ${AUTODIE_NONFATAL-} zram_autoload_module ${zram_num_swaps} && \
   zram_swap "${zram_num_swaps}" "${zram_swap_size_m}" "y"
}

# @private @stdout ~int zram_autoswap__print_cpu_core_count()
#
#  Prints the highest core id as reported by /proc/cpuinfo.
#  Note that core count := <max core id> + 1 (not handled by this function!).
#
zram_autoswap__print_cpu_core_count() {
   < /proc/cpuinfo sed -rn -e \
      's,^core\s+id\s*[:]\s*([0-9]+)$,\1,p' | sort -n | tail -n 1
}

# @private @stdout ~int zram_autoswap__print_sys_mem_size_m()
#
#  Prints the approx. amount of system memory in megabytes (lower bound)
#  as reported by /proc/meminfo.
#
zram_autoswap__print_sys_mem_size_m() {
   # cutting off the lower 3 digits
   < /proc/meminfo sed -nr \
      -e '/^MemTotal/{s,^MemTotal[:]\s+([0-9]+)[0-9]{3}\s+k[bB]$,\1,p;q}'
}

# int zram_calculate_autoswap (
#    max_swap_space_spec="/2",
#    min_swapdev_size=**ZRAM_SWAP_DEFAULT_SIZE,
#    max_num_swaps=<cpu core count>,
#    max_sys_mem=<sys mem>,
#
#    **zram_num_swaps!,
#    **zram_swap_size_m!,
# )
#
#  Helper function for zram_autoswap() that invokes the num_swaps/swap_size
#  calculation.
#
zram_calculate_autoswap() {
   zram_num_swaps=
   zram_swap_size_m=

   local \
      max_swap_space_spec max_swap_space_m \
      min_swapdev_size_m max_num_swaps max_sys_mem

   max_swap_space_m=
   max_swap_space_spec="${1:-/2}"
   min_swapdev_size_m="${2:-${ZRAM_SWAP_DEFAULT_SIZE:?}}"
   max_num_swaps="${3-}"
   max_sys_mem="${4-}"

   if [ -z "${max_num_swaps}" ]; then
      # sort -n  usually not necessary
      max_num_swaps="$(zram_autoswap__print_cpu_core_count)"
      if [ -z "${max_num_swaps}" ]; then
         max_num_swaps=1
      else
         max_num_swaps=$(( ${max_num_swaps} + 1 ))
      fi
   fi

   case "${max_swap_space_spec}" in
      /[0-9]*)
         # fraction of %max_sys_mem
         if [ -z "${max_sys_mem}" ]; then
            max_sys_mem="$(zram_autoswap__print_sys_mem_size_m)"
            [ -n "${max_sys_mem}" ] || return 5
         fi

         is_positive "${max_sys_mem}" || function_die "no system memory??"

         max_swap_space_m=$(( ${max_sys_mem} / ${max_swap_space_spec#/} ))

         is_positive "${max_swap_space_m}" || function_die "operational error"
      ;;

      [0-9]*)
         max_swap_space_m="${max_swap_space_spec%[mM]}"
      ;;

      *)
         return ${EX_USAGE}
      ;;
   esac

   # resolve by recursion
   zram_calculate_autoswap__recursive \
      "${max_swap_space_m}" "${min_swapdev_size_m}" "${max_num_swaps}"
}

# @private int zram_calculate_autoswap__recursive (
#    max_swap_space_m,
#    min_swapdev_size_m,
#    max_num_swaps,
#
#    **zram_num_swaps!,
#    **zram_swap_size_m!
# )
#
#  Function that recursively calculates the autoswap variables.
#  Should be called indirectly (zram_calculate_autoswap() or self).
#
zram_calculate_autoswap__recursive() {
   # localize parameters, for improved readability
   # (stripping "_m" suffix from varnames)
   local max_swap_space min_swapdev_size max_num_swaps swapdev_size

   max_swap_space="${1?}"
   min_swapdev_size="${2?}"
   max_num_swaps="${3?}"

   if [ ${max_num_swaps} -eq 1 ]; then
      zram_num_swaps=1
      if [ ${max_swap_space} -ge ${min_swapdev_size} ]; then
         # @ABORT-RECURSION: SUCCESS
         zram_swap_size_m=${max_swap_space}
         return 0
      else
         # @ABORT-RECURSION: FAILURE (partial)
         #  catches max_swap_space < min_swapdev_size
         zram_swap_size_m=${min_swapdev_size}
         return 10
      fi
   elif [ ${max_num_swaps} -le 0 ]; then
      zram_num_swaps=0
      zram_swap_size_m=0
      return 1
   fi

   # checking
   #   max_swap_space_m / max_num_swaps >= min_swapdev_size_m AND > 0
   # alternatively, could check for
   #    0 < min_swapdev_size_m * max_num_swaps <= max_swap_space_m
   #
   swapdev_size=$(( ${max_swap_space} / ${max_num_swaps} ))

   if [ ${swapdev_size} -lt 0 ]; then
      # @ABORT-RECURSION: EXIT
      function_die "overflow or logical error"
      # @on-die-continue
      return

   elif [ ${swapdev_size} -eq 0 ]; then
      # !!!  %max_num_swaps > %max_swap_space_m
      #  -> warn && reduce max_num_swaps
      zram_log_warn \
         "max_num_swaps too big (${max_num_swaps} > ${max_swap_space})"

      zram_calculate_autoswap__recursive "${max_swap_space}" \
         "${min_swapdev_size}" "$(( ${max_num_swaps} - 1 ))"

   elif [ ${swapdev_size} -lt ${min_swapdev_size} ]; then
      # need to reduce size and/or max_num_swaps
      #  -> reducing max_num_swaps
      zram_calculate_autoswap__recursive "${max_swap_space}" \
         "${min_swapdev_size}" "$(( ${max_num_swaps} - 1 ))"

   else
      # @ABORT-RECURSION: SUCCESS
      zram_swap_size_m="${swapdev_size}"
      zram_num_swaps="${max_num_swaps}"
   fi
}
