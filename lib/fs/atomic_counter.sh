# @private int atomic_file_counter__add (
#    file, delta, min_val=0, **v0!
# )
#
#  Writes
#   max ( min_val, max ( $(< file), min_val ) + delta )
#  to %file and stores the new value in %v0.
#
#  Returns success/failure.
#
atomic_file_counter__add() {
   v0=
   local old_val new_val min_val="${3:-0}"

   if [ -e "${1?}" ]; then
      old_val=$(cat "${1}" 2>/dev/null)

      [ -n "${old_val-}" ] && \
         [ "${old_val}" -ge ${min_val} 2>/dev/null ] || old_val="${min_val}"
   else
      old_val="${min_val}"
   fi

   new_val=$(( ${old_val} + ${2:?} ))

   [ ${new_val} -ge ${min_val} ] || new_val="${min_val}"

   echo "${new_val}" > "${1}" && v0="${new_val}"
}

# @private int atomic_file_counter__read ( file, min_val=0 )
#
#  Reads file and stores its value in %v0.
#  Returns 0 if the value was not empty and greater or equal min_val.
#
atomic_file_counter__read() {
   v0=$(cat "${1?}")
   [ -n "${v0}" ] && [ "${v0}" -ge "${2:-0}" 2>/dev/null ]
}

# @private int atomic_file_counter__reset ( file, min_val=0 )
#
#  Writes min_val to file. Returns 0 if successful, else != 0.
#
atomic_file_counter__reset() {
   echo "${2:-0}" > "${1?}"
}

# int atomic_file_counter ( counter_file, action, *action_args )
#
#  where action is
#  * fixup ( min_val=0 )
#     Sets counter_file to min_val if it does not exist or has an invalid
#     value. Technically, this increases the file's value by 0.
#  * reset ( min_val=0 )
#     Sets counter_file to min_val.
#  * increment|inc|add|+|++|+= ( pos_delta, min_val=0 )
#     Increases the file's value.
#  * decrement|dev|sub|-|--|-= ( neg_delta, min_val=0 )
#     Decreases the file's value.
#  * show|cat ( lock=n )
#     Prints the file's value to stdout.
#  * get|load ( lock=n, min_val=0 )
#     Stores the file's value in %v0 and verifies it.
#
atomic_file_counter() {
   case "${2-}" in
      'fixup')
         atomic_file_do atomic_file_counter__add "${1?}" "0" "${3-}"
      ;;
      'reset')
         atomic_file_do atomic_file_counter__reset "${1?}" "${3-}"
      ;;
      'increment'|'inc'|'add'|'+'|'++'|'+=')
         atomic_file_do atomic_file_counter__add "${1?}" "${3:-1}" "${4-}"
      ;;
      'decrement'|'dec'|'sub'|'-'|'--'|'-=')
         atomic_file_do atomic_file_counter__add "${1?}" "-${3:-1}" "${4-}"
      ;;
      'show'|'cat')
         if [ "${3:-n}" = "y" ]; then
            atomic_file_do cat "${1?}"
         else
            cat "${1?}"
         fi
      ;;
      'get'|'load')
         if [ "${3:-n}" = "y" ]; then
            atomic_file_do atomic_file_counter__read "${1?}" "${4-}"
         else
            atomic_file_counter__read "${1?}" "${4-}"
         fi
      ;;
      *)
         case "${1-}" in
            '--help'|'-h'|'--usage')
echo "Usage: atomic_file_counter <file> <action>

where action is:
* fixup [<min_value>]
* reset [<min_value>]
* increment|inc|add|+|++|+= <delta> [<min_value>]
* decrement|dec|sub|-|--|-= <delta> [<min_value>]
* show|cat [<lock>]
* get|load [<lock> [<min_value>]]

min_value defaults to 0."
               return 0
            ;;

            *)
               return 2
            ;;
         esac
      ;;
   esac
}
