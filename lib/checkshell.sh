#@section functions

# int checkshell__get_exe ( **exe!, **exe_name! )
#
checkshell__get_exe() {
   exe=
   exe_name=

   local procexe
   procexe="/proc/$$/exe"

   exe="$(readlink -f "${procexe}")"
   if [ -z "${exe}" ]; then
      return 1
   else
      exe_name="${exe##*/}"
   fi
   return 0
}

shell_is_busybox() {
   # %ASH_VERSION not set in vanilla busybox
   #  (needs custom 'patch')
   #
   [ -z "${ASH_VERSION-}" ] || return 0

   local exe exe_name
   checkshell__get_exe

   case "${exe_name}" in
      busybox|busybox_*|ash|ash_*)
         return 0
      ;;
   esac

   return 1
}
