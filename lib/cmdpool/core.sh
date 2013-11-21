#@section header
# ----------------------------------------------------------------------------
#
# This module provides functions to manage one or more command pools,
# which are directories (likely on a tmpfs) containing subdirs.
# These so-called "slots" (or "slot dirs") keep track a single command,
# e.g. by collecting its output and returncode, and make that information
# available as file(s).
#
# Slot dir creation is safe if the underlying filesystem handles mkdir(2)
# atomically, which is true for most filesystems.
#
# Useful for starting a series of commands asynchronously and collecting
# the result (output, returncode) later, possibly in another process.
#
# A helper script is required for keeping track of the commands, which is
# supposed to create some of the slot's files, in particular:
#
# * <slot>/environ    -- the command's environment (creation)
# * <slot>/running    -- file whose existence indicates that the command
#                        is running (creation and removal)
# * <slot>/child_pid  -- pid of the actual command (creation)
# * <slot>/stdout     -- the command's stdout (creation)
# * <slot>/stderr     -- the command's stderr (creation)
# * <slot>/returncode -- the command's returncode (creation)
# * <slot>/success    -- file whose existence indicates that the command
#                        was successful (returned 0) (creation)
# * <slot>/fail       -- file whose existence indicates that the command
#                        was not successful (non-zero returncode) (creation)
# * <slot>/stopping   -- file whose existence indicates that the command
#                        is about to halt (removal)
# * <slot>/stopped    -- file whose existence indicates that the command has
#                        been stopped by a signal (SIGKILL, SIGTERM)
#                        Contains the signal
# * <slot>/done       -- file whose existence indicates that the command
#                        is no longer running (creation)
#                        Contains the time (as seconds since epoch) at which
#                        the process was considered to be done
#
#
## TODO: specify slot dir somewhere (doc/ or here)
#
# Functions provided by this module (quickref):
#
# int  cmdpool_logger()
# int  cmdpool_log_error()
# void cmdpool_set_runcmd()                 -- helper_exe
# int  cmdpool_start()                      -- slot_root, slot_name, exe
# int  cmdpool_stop()                       -- slot, exe
# int  cmdpool_check_running()              -- slot
# int  cmdpool_check_done()                 -- slot
# int  cmdpool_remove_slot()                -- slot
# int  cmdpool_mark_for_removal()           -- slot
# int  cmdpool_iter_slots()                 -- slot_root, slot_name, func
# int  cmdpool_iter_completed_commands()    -- slot_root, slot_name, func
# void auto_cleanup cmdpool_cleanup_slots() -- slot_root, slot_name
# int  cmdpool_iter_slots_with_flag()       -- flag, slot_root, slot_name, func
# int  cmdpool_get_slot()                   -- slot_root, slot_name, exe
# int  cmdpool_do_start()                   -- slot, exe
#
#
# Example code using this module:
#
# # initialize cmdpool module
# cmdpool_set_runcmd /path/to/helper
#
# # start command
# cmdpool_start /run/cmdpool/$USER/dl wget wget http://... -O $outfile
# ln -s $outfile $v0/tmp/outfile
#
# # then, maybe in another process (don't forget to call cmdpool_set_runcmd())
# cmdpool_iter_completed_commands \
#    /run/cmdpool/$USER/dl wget unpack_outfile_if_successful
#
# ----------------------------------------------------------------------------


#@section functions

# @logger cmdpool_logger()
#
#  logger function that passes "cmdpool" as root facility.
#
cmdpool_logger() {
   ${LOGGER?} --facility=cmdpool "$@"
}


# @logger cmdpool_log_error()
#
#  logger function that passes "cmdpool" as root facility and
#  "ERROR" as log level.
#
cmdpool_log_error() {
   ${LOGGER?} --facility=cmdpool --level=ERROR "$@"
}



#@section functions

# @private int cmdpool__populate_slot ( slot, exe, *argv )
#
#  Populates a cmdpool slot by creating status/info files.
#  Returns 0 if all files could be created, and non-zero otherwise.
#
cmdpool__populate_slot() {
   local slot="${1:?}"
   shift
   : "${1:?}"

   mkdir -m 0750 "${slot}/tmp"             && \
   > "${slot}/stdout"                      && \
   > "${slot}/stderr"                      && \
   > "${slot}/pid"                         && \
   > "${slot}/child_pid"                   && \
   > "${slot}/env"                         && \
   > "${slot}/environ"                     && \
   echo "${1}"     > "${slot}/exe"         && \
   echo "${1##*/}" > "${slot}/exe_name"    && \
   echo "$*"       > "${slot}/cmdv"        && \
   date +%s        > "${slot}/initialized"
}


# @private int cmdpool__get_exe_name ( slot, exe=<slot~>, **exe_name! )
#
#  Sets the %exe_name variable, either by using the name of %exe (if given)
#  or by reading %slot/exe_name.
#
#  Returns 0 if %exe_name could be set successfully (and is not empty),
#  and non-zero otherwise.
#
cmdpool__get_exe_name() {
   exe_name=

   if [ -n "${2-}" ]; then
      exe_name="${2##*/}"
   elif [ -f "${1}/exe_name" ]; then
      if ! read -r exe_name < "${1}/exe_name"; then
         cmdpool_log_error "failed to get exe_name from file in '${1}'"
         return 2
      fi
   else
      cmdpool_log_error "cannot get exe_name for slot '${1}'"
      return 2
   fi
   [ -n "${exe_name}" ]
}


#@section functions

# void cmdpool_set_runcmd ( helper_exe, **X_CMDPOOL_RUNCMD! )
#
#  Sets the path to the cmdpool runcmd helper script (%X_CMDPOOL_RUNCMD).
#
#  Note: this _must_ not be changed while having any commands running that
#        you intend to stop.
#        (i.e. don't start a process, change runcmd and then try to stop proc)
#
cmdpool_set_runcmd() {
   X_CMDPOOL_RUNCMD="${1}"
}


# int cmdpool_get_slot ( slot_root, slot_name=<exe~>, exe, *argv, **v0! )
#
#  Creates a cmdpool slot in the given %slot_root and uses %slot_name or
#  the name of %exe as base name.
#  Passing an empty %slot_root and an empty %slot_name is not allowed.
#
#  Returns 0 on success, else non-zero. Stores the slot in %v0.
#
cmdpool_get_slot() {
   v0=
   local slot_root="${1:?}" slot_basename exe="${3:?}" slot_base

   case "${2}" in
      '')
         if [ -z "${slot_root}" ]; then
            cmdpool_log_error "implicit slot name needs slot_root"
            return 2
         else
            slot_basename="${exe##*/}"
            slot_basename="${slot_basename%.*}"
            slot_base="${slot_root%/}/${slot_basename}_"
         fi
      ;;
      '_')
         if [ -z "${slot_root}" ]; then
            cmdpool_log_error "empty slot name needs slot_root"
            return 2
         else
            slot_basename=""
            slot_base="${slot_root%/}/"
         fi
      ;;
      *)
         slot_basename="${2}"
         if [ -n "${slot_root}" ]; then
            slot_base="${slot_root%/}/${slot_basename}"
         else
            slot_base="${slot_basename}"
         fi
      ;;
   esac
   shift 2

   if ! dodir_minimal "$(dirname "${slot_base}")"; then
      cmdpool_log_error \
         "failed to created parent dir for slot base '${slot_base}'"
      return 3
   fi

   local slot
   local i_prev=0
   local i=1
   while \
      [ ${i} -gt ${i_prev} ] && \
      ! mkdir -m 0750 -- "${slot_base}${i}" 2>/dev/null
   do
      i_prev=${i}
      i=$(( ${i} + 1 ))
   done

   if [ ${i} -gt ${i_prev} ] && [ -d "${slot_base}${i}" ]; then
      slot="${slot_base}${i}"
      if cmdpool__populate_slot "${slot}" "$@"; then
         v0="${slot}"
      else
         cmdpool_log_error "failed to initialize slot '${slot}'"
         return 4
      fi
   else
      cmdpool_log_error "failed to get a slot"
      return 5
   fi
}


# int cmdpool_do_start ( slot, exe, *argv, **X_CMDPOOL_RUNCMD )
#
#  Starts a command in the given cmdpool slot.
#
cmdpool_do_start() {
   local slot="${1:?}"
   local exe="${2:?}"

   if [ ! -d "${slot}" ]; then
      cmdpool_log_error "cmdpool slot does not exist."
      return 2
   elif [ ! -f "${slot}/initialized" ]; then
      cmdpool_log_error "cmdpool slot is not initialized"
      return 3
   else
      # do not pass --stdout, --stderr to start-stop-daemon
      #  these seems to be implemented for openrc's s-s-d only
      #
      #  -a, --startas is considered deprecated in openrc's s-d
      #  (with -n, --name as replacement)
      #  TODO: check whether -n works as desired with busybox'/debian's s-s-d
      #
      cmdpool_logger --level=INFO "Starting ${exe##*/} ('${slot}')"
      if daemonize_command "${slot}/pid" \
         -a "${exe##*/}" -x "${X_CMDPOOL_RUNCMD:?}" -- "$@"
      then
         cmdpool_logger --level=DEBUG "start '${slot}': success"
      else
         cmdpool_log_error "failed to start ${exe##*/} ('${slot}')"
         return 4
      fi
   fi
}

# int cmdpool_start ( slot_root, slot_name=<exe~>, exe, *argv, **v0! )
#
#  Creates a slot for the given command and starts it afterwards.
#  See cmdpool_get_slot() and cmdpool_do_start() for details.
#
cmdpool_start() {
   v0=
   if cmdpool_get_slot "$@"; then
      local __cmdpool_slot="${v0:?}"
      shift 2
      cmdpool_do_start "${__cmdpool_slot}" "$@"
      local rc=$?
      v0="${__cmdpool_slot}"
      return ${rc}
   else
      return 2
   fi
}


# int cmdpool_stop ( slot, exe=<slot~>, **X_CMDPOOL_RUNCMD )
#
#  Stops a command (specified by its slot and optionally by its exe).
#  Returns success/failure.
#
cmdpool_stop() {
   local slot="${1:?}" exe_name
   cmdpool__get_exe_name "${slot}" "${2-}" || return

   if [ -e "${slot}/done" ]; then
      cmdpool_logger --level=INFO "not stopping ${exe_name}: already stopped"
   elif [ -e "${slot}/running" ]; then
      if [ -e "${slot}/stopping" ]; then
         cmdpool_logger --level=INFO \
            "not stopping ${exe_name}: stop() already called"
      else
         cmdpool_logger -0 --level=INFO "stopping ${exe_name} ('${slot}')"
         touch "${slot}/stopping"
         if daemonize_stop "${slot}/pid" \
            -n "${exe_name}" -x "${X_CMDPOOL_RUNCMD:?}"
         then
            cmdpool_logger --level=DEBUG "stopped ${exe_name}"
         else
            cmdpool_log_error \
               "failed to stop ${exe_name} ('${slot}', retcode=${?})"
            return 2
         fi
      fi
   else
      cmdpool_logger --level=WARN "not stopping ${exe_name}: not running"
      return 3
   fi
}


# int cmdpool_check_running ( slot )
#
#  Returns 0 if the command associated with the given slot is running,
#  else 1.
#
#  Note that "not running" does not necessarily mean "done".
#
cmdpool_check_running() {
   [ -e "${1:?}/running" ] && [ ! -e "${1:?}/done" ]
}


# int cmdpool_check_done ( slot )
#
#  Returns 0 if the command associated with the given slot is done, else 1.
#
cmdpool_check_done() {
   [ -e "${1:?}/done" ]
}


# int cmdpool_remove_slot ( slot )
#
#  Removes the slot of a command that is not running.
#  Returns 0 if successful, else non-zero.
#
cmdpool_remove_slot() {
   if cmdpool_check_running "${1:?}"; then
      cmdpool_log_error "cannot remove slot '${1}': process is running"
      return 2
   else
      rm -r -- "${1:?}"
   fi
}


# int cmdpool_mark_for_removal ( slot )
#
#  Marks a slot for auto removal (cmdpool_cleanup_slots()).
#
cmdpool_mark_for_removal() {
   cmdpool_logger --level=DEBUG "marking slot '${1-UNDEF}' for auto-removal"
   touch "${1:?}/auto_cleanup"
}


# int cmdpool_iter_slots (
#    slot_root, slot_name=, func, *argv, **F_CMDPOOL_ITER_ON_ERROR=return
# )
#
#  Calls %func ( slot, *argv, **slot=slot ) for each slot in %slot_root
#  whose name starts with %slot_name (but is not exactly %slot_name).
#
#  Passing an empty %slot_name results in no slot name restrictions.
#
cmdpool_iter_slots() {
   local slot_root="${1:?}"
   local slot_name="${2?}"
   local func="${3:?}"
   shift 3

   local slot
   for slot in "${slot_root%/}/${slot_name}"?*; do
      if [ -d "${slot}" ]; then
         ${func} "${slot}" "$@" || ${F_CMDPOOL_ITER_ON_ERROR:-return}
      fi
   done
}


# int cmdpool_iter_slots_with_flag (
#    flag, slot_root, slot_name=, func, *argv,
#    **F_CMDPOOL_ITER_ON_ERROR=return
# )
# DEFINES @cmdpool_slot_iterator <flag> <function name> (
#    slot_root, slot_name=, [[func], [*args]], [**F_CMDPOOL_ITER_ON_ERROR]
# )
#
#  Calls %func ( slot, *argv, **slot=slot ) for each slot in %slot_root
#  whose name starts with %slot_name (but is not exactly %slot_name)
#  and has the given flag file.
#
cmdpool_iter_slots_with_flag() {
   local flag="${1:?}"; flag="${flag#/}"
   : ${flag:?}
   local slot_root="${2:?}"
   local slot_name="${3?}"
   local func="${4:?}"
   shift 4

   local flag_f slot
   for flag_f in "${slot_root%/}/${slot_name}"?*"/${flag}"; do
      if [ -f "${flag_f}" ]; then
         slot="${flag_f%/${flag}}"
         ${func} "${slot}" "$@" || ${F_CMDPOOL_ITER_ON_ERROR:-return}
      fi
   done
   return 0
}


# @cmdpool_slot_iterator auto_cleanup cmdpool_cleanup_slots (
#    sloot_root, slot_name=
# )
#
#  Removes slots with the "auto_cleanup" flag.
#  See cmdpool_iter_slots_with_flag()/cmdpool_remove_slot() for details.
#
#  Always return 0 and ignores errors caused by cmdpool_remove_slot().
#
cmdpool_cleanup_slots() {
   local F_CMDPOOL_ITER_ON_ERROR=true
   cmdpool_iter_slots_with_flag \
      auto_cleanup "${1:?}" "${2-}" cmdpool_remove_slot
   return 0
}


# @cmdpool_slot_iterator done cmdpool_iter_completed_commands (
#    slot_root, slot_name=, func, *argv, **F_CMDPOOL_ITER_ON_ERROR=return
# )
#
#  Calls %func ( slot, *argv, **slot=slot ) for each slot
#  with the 'done' flag. See cmdpool_iter_slots_with_flag() for details.
#
#  Example:
#    F_CMDPOOL_ITER_ON_ERROR=true cmdpool_iter_completed_commands \
#       /run/cmdpool/$USER dl_ cmdpool_remove_slot
#
#   Removes all dl_* command slots that completed.
#   Note that this example is useless (in general), because you'd have no way
#   to check the exit codes (etc.) of commands that just completed.
#
cmdpool_iter_completed_commands() {
   cmdpool_iter_slots_with_flag done "$@"
}
