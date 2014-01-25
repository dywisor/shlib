#@section functions

# void x11__run_and_filter_who ( repl_expr )
#
x11__run_and_filter_who() {
   who | sed -nr -e "s,^(\S+)\s+([:][0-9.]+)\s+.*$,${1},p" | sort -u
}

# void print_x_users()
print_x_users()              { x11__run_and_filter_who '\1'; }
# void print_x_displays()
print_x_displays()           { x11__run_and_filter_who '\2'; }
# void print_x_users_and_displays()
print_x_users_and_displays() { x11__run_and_filter_who '\1 \2'; }

# void get_users ( **v0! )
get_x_users()                { v0="$( print_x_users )"; }
# void get_x_displays ( **v0! )
get_x_displays()             { v0="$( print_x_displays )"; }
# void get_x_users_and_displays ( **v0! )
get_x_users_and_displays()   { v0="$( print_x_users_and_displays )"; }

# int x11__run_command_on_display (
#    target_user, display, *cmdv, (DISPLAY=%display)
# )
#
x11__run_command_on_display() {
   local user="${1:?}"
   local display="${2:?}"
   shift 2 || return 64

   DISPLAY="${display}" "$@"
}

# int x11__sudo_run_command_as (
#    target_user, display, *cmdv, **X_SUDO="sudo", (DISPLAY=%display)
# )
#
x11__sudo_run_command_as() {
   local user="${1:?}"
   local display="${2:?}"
   shift 2 || return 64

   if [ -n "${USER-}" ] && [ "${user}" = "${USER}" ]; then
      DISPLAY="${display}" "$@"
   else
      ${X_SUDO:-sudo} -n -u "${user}" DISPLAY="${display}" -- "$@"
   fi
}

# int run_as_x_user (
#    [*varargs], *cmdv,
#    **F_RUN_AS_X_USER="x11__sudo_run_command_as"
# )
#
run_as_x_user() {
   local __runas_func="${F_RUN_AS_X_USER:-x11__sudo_run_command_as}"
   local target_user
   local user
   local item

   case "${1-}" in
      '--target-user'|'-u')
         target_user="${2:?}"
         shift 2 || return 64
      ;;
      '-a'|'--all')
         target_user="@all"
         shift || return 64
      ;;
      '--')
         shift || return 64
      ;;
   esac

   for item in $(print_x_users_and_displays); do
      if [ -z "${item}" ]; then
         true
      elif [ -z "${user}" ]; then
         user="${item}"
      else
         case "${target_user}" in
            '')
               ${__runas_func:?} "${user}" "${item}" "$@"
               return ${?}
            ;;
            '@all')
               ${__runas_func:?} "${user}" "${item}" "$@"
            ;;
            "${user}")
               ${__runas_func:?} "${user}" "${item}" "$@"
            ;;
         esac

         user=
      fi
   done
}

# int xnotify_all (
#    *argv,
#    **X_NOTIFY="notify-send"
#    **F_RUN_AS_X_USER="x11__run_command_on_display"
# )
#
xnotify_all() {
   local F_RUN_AS_X_USER="${F_RUN_AS_X_USER:-x11__run_command_on_display}"
   run_as_x_user -a "${X_NOTIFY:-notify-send}" "$@"
}

# int xnotify_user (
#    user, *argv,
#    **X_NOTIFY="notify-send",
#    **F_RUN_AS_X_USER="x11__run_command_on_display"
#
xnotify_user() {
   local F_RUN_AS_X_USER="${F_RUN_AS_X_USER:-x11__run_command_on_display}"
   local target_user="${1:?}"
   shift || return 64
   run_as_x_user -u "${target_user}" "${X_NOTIFY:-notify-send}" "$@"
}
