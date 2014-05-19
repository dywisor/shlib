#@section functions

# int zram_autoswap ( *calculate_args, **ZRAM_!, **v0! )
#
zram_autoswap() {
   v0=

   local zram_num_swaps zram_swap_size_m
   ${AUTODIE_NONFATAL-} zram_calculate_autoswap "${@}" || return

   zram_swap "${zram_num_swaps}" "${zram_swap_size_m}" "y"
}

# !!! core_count - 1
zram_autoswap__print_cpu_core_count() {
   < /proc/cpuinfo sed -rn -e \
      's,^core\s+id\s*[:]\s*([0-9]+)$,\1,p' | sort -n | tail -n 1
}

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
zram_calculate_autoswap__recursive() {
   # BROKEN
   if [ ${3} -eq 1 ]; then
      zram_num_swaps=1
      if [ ${1} -ge ${2} ]; then
         zram_swap_size_m=${1}
         return 0
      else
         zram_swap_size_m=${2}
         return 10
      fi
   elif [ ${3} -le 0 ]; then
      zram_num_swaps=0
      zram_swap_size_m=0
      return 1
   fi

   local swapdev_size

   # checking
   #   max_swap_space_m / max_num_swaps >= min_swapdev_size_m AND > 0
   # alternatively, could check for
   #    0 < min_swapdev_size_m * max_num_swaps <= max_swap_space_m
   #
   swapdev_size=$(( ${1} / ${3} ))

   if [ ${swapdev_size} -lt 0 ]; then
      function_die "overflow or logical error"

   elif [ ${swapdev_size} -eq 0 ]; then
      # !!!  %max_num_swaps > %max_swap_space_m
      #  -> warn && reducing max_num_swaps
      zram_log --level=WARN "max_num_swaps too big (${3} > ${1})"
      zram_calculate_autoswap__recursive "${1}" "${2}" "$(( ${3} - 1 ))"

   elif [ ${swapdev_size} -lt ${2} ]; then
      # need to reduce size and/or max_num_swaps
      #  -> reducing max_num_swaps
      zram_calculate_autoswap__recursive "${1}" "${2}" "$(( ${3} - 1 ))"

   else
      zram_swap_size_m="${swapdev_size}"
      zram_num_swaps="${3}"
   fi
}
