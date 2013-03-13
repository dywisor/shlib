# int dosym ( target, link )
#
#  Creates a link to the given target if it (the link) does not exist.
#
dosym() {
   if [ -l "${2:?}" ] || [ -e "${2}" ]; then
      return 0
   else
      ln -T -s -- "${1:?}" "${2}"
   fi
}
