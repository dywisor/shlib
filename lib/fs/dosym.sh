# int dosym ( target, link )
#
#  Creates a link to the given target if it (the link) does not exist.
#
dosym() {
   if [ -h "${2:?}" ] || [ -e "${2}" ]; then
      return 0
   else
      ln -s -n -T -- "${1:?}" "${2}"
   fi
}
