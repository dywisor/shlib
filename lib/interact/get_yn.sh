# int get_yn ( prompt, char_y, char_n )
#
#  Asks the user a yes/no question and expects a single char as response.
#  Returns true if the response was char_y and false if char_n.
#
#  Repeats asking until a valid answer has been typed in.
#
get_yn() {
   set -- "${1-}${1:+ }" "${2:-y}" "${3:-n}"

   local prompt="${1}(${2}/${3}) " yn=
   while [ "${yn}" != "${2}" ] && [ "${yn}" != "${3}" ]; do
      echo -n "${prompt}"
      if [ -n "${BASH_VERSION-}" ]; then
         read -n1 yn
      else
         read yn
      fi
      echo
   done
   [ "${yn}" = "${2}" ]
}
