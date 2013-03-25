# @iterator <fstab> fstab_iterator (
#    fstab_file=/etc/fstab,
#    ...,
#    F_FSTAB_ITER=fstab_iterator_print_item
# )
#
#  Extracts the filesystem identificator, e.g. /dev/sda1 (fs),
#  the mountpoint (mp), the filesystem type (fstype) and the mount
#  options (opts) and calls F_FSTAB_ITER() for each valid read from the
#  the given fstab file.
#
#  Hint: Passing F_FSTAB_ITER=mount results in mounting all entries.
#
fstab_iterator() {
   F_ITER=__fstab_iterator_item \
      ITER_UNPACK_ITEM=y \
      ITER_SKIP_EMPTY=y \
      ITER_SKIP_COMMENT=n \
   file_iterator "${1:-/etc/fstab}"
}

# int __fstab_iterator_item ( <fstab line>, **F_FSTAB_ITER=<see above> )
#
#  See fstab_iterator().
#  Returns 0 if line is empty or a comment,
#  else passes F_FSTAB_ITER()'s return value.
#
__fstab_iterator_item() {
   local \
      fs="${1-}" mp="${2-}" fstype="${3-}" \
      opts="${4-}" dump="${5-}" pass="${6-}"

   if [ -z "${fs#\#}" ] || [ "x${fs#\#}" != "x${fs}" ]; then
      # either empty or comment
      true
   elif \
      [ -n "${fs}" ] && [ -n "${mp}" ] && \
      [ -n "${fstype}" ] && [ -n "${opts}" ]
   then
      ${F_FSTAB_ITER:-fstab_iterator_print_item} \
         -t "${fstype}" -o "${opts}" "${fs}" "${mp}"
   else
      true
   fi
}

# void fstab_iterator_print_item (...)
#
#  Prints an fstab entry to stdout.
#
fstab_iterator_print_item() {
   echo "fstab entry<fs='${fs}' mp='${mp}' fstype='${fstype}' opts='${opts}'>"
}
