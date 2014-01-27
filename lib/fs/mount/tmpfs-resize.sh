#@section functions

# int tmpfs_resize ( mp, size )
#
#  Resizes the tmpfs mounted at mp to size (str).
#
tmpfs_resize() {
   ${LOGGER} --level=INFO "resizing ${1}, new size will be ${2}."
   do_mount -o remount,size=${2:?} "${1:?}"
}

# int tmpfs_resize_m ( mp, size_m )
#
#  Resizes the tmpfs mounted at mp to size_m (int).
#  Immediately returns 12 if size_m is <= 0.
#
tmpfs_resize_m() {
   if [ ${2:?} -gt 0 ]; then
      tmpfs_resize "${1:?}" "${2}m"
   else
      return 12
   fi
}

# @private int tmpfs__resize_m_delta_minmax (
#    mp,
#    current_size_m=<detect>,
#    delta_m=0,
#    min_size_m=0,
#    max_size_m=0
# )
#
#  Resizes the tmpfs mounted at mp to <current_size_m> + <delta_m> while
#  keeping lower/upper size thresholds.
#
#  Stores the new size in %v0.
#
tmpfs__resize_m_delta_minmax() {
   v0=""

   local mp="${1:?}" current_size_m="${2-}" \
      delta_m="${3:-0}" min_size_m="${4:-0}" max_size_m="${5:-0}"

   # current_size_m = <detect> if not valid
   if [ -z "${current_size_m}" ] || [ ${current_size_m} -le 0 ]; then
      local FILESIZE
      autodie get_filesize "${mp}"
      current_size_m="${FILESIZE}"
   fi

   # max_size_m = <current_size_m> if < 0
   [ ${max_size_m} -ge 0 ] || max_size_m=${current_size_m}
   # min_size_m = 0 if < 0
   [ ${min_size_m} -ge 0 ] || min_size_m=0

   # calculate the new size
   # -> apply delta_m
   local new_size_m=$(( ${current_size_m} + ${delta_m} ))

   # -> apply min_size_m
   [ ${new_size_m} -gt ${min_size_m} ] || new_size_m="${min_size_m}"

   # -> apply max_size_m
   if [ ${max_size_m} -gt 0 ] && [ ${new_size_m} -gt ${max_size_m} ]; then
      new_size_m="${max_size_m}"
   fi

   # finally, new_size_m has to be > 0
   if [ ${new_size_m} -eq ${current_size_m} ]; then
      ${LOGGER} -0 --level=INFO "not resizing ${mp}, new == current == ${current_size_m}"
   elif [ ${new_size_m} -gt 0 ]; then
      ${LOGGER} -0 --level=INFO "resizing ${mp}, new size = ${new_size_m}, old size = ${current_size_m}"
      tmpfs_resize_m "${mp}" "${new_size_m}" && v0="${new_size_m}"
   else
      ${LOGGER} -0 --level=INFO "not resizing ${mp}, new size would be ${new_size_m}."
   fi
}
# tmpfs__resize_m_delta_minmax ( "mp" "now" "delta" "min" "max" )
# --- end of tmpfs__resize_m_delta_minmax (...) ---

# int tmpfs_grow ( mp, current_size_m, new_size_m )
#
#  Resizes the tmpfs mounted at mp if new_size_m > current_size_m.
#
tmpfs_grow() {
   tmpfs__resize_m_delta_minmax "$1" "$2" "0" "$3" "0"
}

# int tmpfs_shrink ( mp, current_size_m, new_size_m )
#
#  Resizes the tmpfs mounted at mp if new_size_m < current_size_m.
#
tmpfs_shrink() {
   tmpfs__resize_m_delta_minmax "$1" "$2" "0" "0" "$3"
}

# int tmpfs_increase ( mp, current_size_m, pos_delta_m )
#
#  Increases the size of a tmpfs by pos_delta_m.
#
tmpfs_increase() {
   tmpfs__resize_m_delta_minmax "$1" "$2" "$3"
}

# int tmpfs_decrease ( mp, current_size_m, neg_delta_m )
#
#  Decreases the size of a tmpfs by -1 * neg_delta_m.
#
tmpfs_decrease() {
   tmpfs__resize_m_delta_minmax "$1" "$2" "-${3}"
}

# int tmpfs_downsize ( mp, current_size_m=<undef>, spare_size_m=30, **v0! )
#
#  Resizes a tmpfs to its actual size + some spare space.
#  Does not resize if the new size would be bigger than the old one,
#  provided you have passed the current_size_m parameter.
#
#  Stores the new size in %v0.
#
tmpfs_downsize() {
   v0=
   local FILESIZE new_size_m

   autodie get_filesize "${1:?}"
   new_size_m=$(( ${FILESIZE} + ${3:-30} ))

   if [ -z "${2-}" ] || [ ${new_size_m} -lt ${2} ]; then
      v0="${new_size_m}"
      tmpfs_resize_m "${1}" "${new_size_m}"
   else
      v0="${2}"
      ${LOGGER} -0 --level=DEBUG \
         "not resizing ${1}, new size would be bigger or equal (${new_size_m} >= ${2-})."
   fi
}
