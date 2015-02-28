#@section functions

_set_locale_to() {
   local v0

   while [ $# -gt 0 ]; do
      if v0="$(locale -a | grep -xEi -- "${1}")"; then
         LANG="${v0}"
         export LANG
         return 0
      fi
      shift
   done
   return 1
}

set_comparable_locale() {
   unset -v LC_COLLATE LC_MESSAGES

   if ! _set_locale_to 'en_US[.]utf[-]?8' 'en_US'; then
      LC_MESSAGES=C
      LC_COLLATE=C
      export LC_MESSAGES
      export LC_COLLATE
   fi
}

with_lang_c_do() {
   (
      LANG=C
      LC_ALL=C
      export LANG
      export LC_ALL
      "${@}"
   )
}

with_comparable_locale_do() {
   (
      set_comparable_locale
      "${@}"
   )
}
