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

# int find_recipe ( name )
#
find_recipe() {
   recipe=

   if [ "${1:?}" = "${1#/}" ]; then
      if [ -n "${RECIPE-}" ]; then
         recipe="${RECIPE%/*}/${1}"
      else
         recipe="${RECIPE_ROOT}/${1}"
      fi
   else
      recipe="${1}"
   fi

   if [ -f "${recipe}" ]; then
      true
   elif [ -f "${recipe}.recipe" ]; then
      recipe="${recipe}.recipe"
   else
      return 1
   fi
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
