if [ -n "${USE}" ] && [ "${USE_REDUX}" = "y" ]; then
   list_redux ${USE}
   readonly USE="${v0}"
   unset v0
fi

set_use +nounset ${USE}

# int use_call_yesno ( flag, *cmdv )
#
#  Calls *cmdv y if flag is enabled, else *cmdv n
#
use_call_yesno() {
   local flag="${1}"; shift || OUT_OF_BOUNDS

   if use "${flag}"; then
      "$@" y
   else
      "$@" n
   fi
}

use_call_yesno bash    SET_BASH
use_call_yesno nounset SET_NOUNSET

# void run_recipe ( recipe ), raises exit()
#
run_recipe() {
   print_message "RECIPE" "${1}" '1;001m' '1;104m';
   # run recipes in subshells so that they dont affect others
   local rc=0
   local RECIPE="${1}"
   (
      set -e

      readonly RECIPE
      [ -n "${__SUBSHELL__-}" ] || readonly __SUBSHELL__=y
      #[ -n "${S-}" ] || readonly S="${PRJROOT?}"


      # void INHERIT ( recipe ), raises die()
      #
      #  Runs another recipe.
      #  Note: infinite recursion is possible. It's up to you to avoid that.
      #
      INHERIT() {
         local __INHERITED__="${RECIPE}"
         print_command INHERIT "$*"
         printcmd_indent
         find_and_run_recipe "$@"
         printcmd_outdent
      }

      # void INHERIT_LOCAL ( **RECIPE ), raises die()
      #
      #  Calls INHERIT ( %RECIPE.local )
      #
      INHERIT_LOCAL() { INHERIT "${RECIPE}.local"; }

      printcmd_indent
      . "${1}"
      printcmd_outdent # just for completeness
   ) || rc=$?
   if [ ${rc} -eq 0 ]; then
      print_message "RECIPE_END" "${1}" '1;034' '1;104'
   else
      print_message "RECIPE_END" "${1}" '1;031' '1;104'
      exit ${rc}
   fi
}

# @private int find_recipe__file ( recipe_path, **recipe )
#
find_recipe__file() {
   if [ -f "${1}" ]; then
      recipe="${1}"
      return 0
   elif [ -f "${1}.recipe" ]; then
      recipe="${1}.recipe"
      return 0
   else
      return 1
   fi
}

# int find_recipe ( name )
#
find_recipe() {
   recipe=

   case "${1:?}" in
      /*)
         find_recipe__file "${1}" || return 1
         return 0
      ;;
      *)
         local d
         if \
            [ -n "${RECIPE-}" ] && find_recipe__file "${RECIPE%/*}/${1#./}"
         then
            return 0
         else
            for d in "${RECIPE_ROOT?}" "${PRJROOT_RECIPE?}"; do
               if find_recipe__file "${d}/${1#./}"; then
                  return 0
               fi
            done
            return 1
         fi
      ;;
   esac
}

# void find_and_run_recipe ( name ), raises die()
#
find_and_run_recipe() {
   local recipe
   find_recipe "${1:?}"     || die "no such recipe: ${1}."
   run_recipe "${recipe:?}" || die "run_recipe() is not allowed to return ${?}."
}

# @implicit int main ( *recipe_name )
#
for N; do
   RECIPE=
   __INHERITED__=
   find_and_run_recipe "${N}" || die
done
