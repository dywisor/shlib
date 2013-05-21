# PRINTMSG_QUIET and PRINTCMD_QUIET
#  have to be set _before_ including this module
#

if [ "${PRINTMSG_QUIET:-n}" = "y" ]; then

print_message()    { return 0; }
printcmd_indent()  { return 0; }
printcmd_outdent() { return 0; }

else

# print_message ( head=, message=, head_color=, message_color=, head_len=12 )
#
print_message() {
   local I="${PRINTCMD_INDENT-}"

   if [ "${NO_COLOR:-n}" = "y" ]; then
      echo "${I}${1-}${2:+ }${2-}"

   else
      local z='\033[0;000m'
      local ch="${3:-0}"; ch="${ch%m}m"
      local cm="${4:-0}"; cm="${cm%m}m"
      local len="${5:-12}"
      [ -z "${I}" ] || I="${z}${I}"

      if [ -n "${1-}" ] && [ "${1}" != "_" ]; then
         if [ -n "${2-}" ]; then
            printf "${I}\033[${ch}%-${len}s${z} \033[${cm}%s${z}\n" "${1}" "${2}"
         else
            printf "${I}\033[${ch}%-${len}s${z}\n" "${1}"
         fi
      elif [ -n "${2-}" ]; then
         if [ "x${1-}" = "x_" ]; then
            printf "${I}\033[${ch}%-${len}s${z} \033[${cm}%s${z}\n" "" "${2}"
         else
            printf "\033[${cm}%s${z}\n" "${2}"
         fi
      fi
   fi
   return 0
}
printcmd_indent() {
   PRINTCMD_INDENT="${PRINTCMD_INDENT-}${PRINTCMD_INDENT_BY-  }"
}
printcmd_outdent() {
   [ -z "${PRINTCMD_INDENT-}" ] || PRINTCMD_INDENT="${PRINTCMD_INDENT%${PRINTCMD_INDENT_BY-  }}"
   [ "${PRINTCMD_OUTDENT_NEWLINE:-n}" != "y" ] || echo
}
fi


if \
   [ "${PRINTMSG_QUIET:-n}" = "y" ] || [ "${PRINTCMD_QUIET:-n}" = "y" ]
then

print_command() { return 0; }
print_pwd()     { return 0; }
print_setvar()  { return 0; }
printcmd()      { return 0; }


else

# void print_command ( exe, *argv, **PRINTCMD_... )
#
print_command() {
   local exe="${1:?}"; shift
   print_message "${exe}" "$*" \
      "${PRINTCMD_COLOR_CMD:-1;032m}" "${PRINTCMD_COLOR_ARGV:-0m}" \
      "${PRINTCMD_CMD_LEN:-12}"
}

# @function_alias printcmd() renames print_command()
printcmd() { print_command "$@"; }

# void print_pwd ( [message], **PWD, **PRINTCMD_... )
#
print_pwd() {
   local PRINTCMD_COLOR_CMD="${PRINTCMD_COLOR_PWD:-1;033m}"
   print_command "[${PWD}]" "$*"
}

print_setvar() {
   local PRINTCMD_COLOR_CMD="${PRINTCMD_COLOR_SETVAR-1;034m}"
   if [ -n "${2+SET}" ]; then
      print_command "${3:-SETVAR}" "${1:?}=${2-}"
   else
      : ${1:?}
      local val
      eval val="\${${1}-}"
      print_command "${3:-SETVAR}" "${1}=${val}"
   fi
}

fi
