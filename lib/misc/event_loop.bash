#@HEADER
# Continuously parse command output.
#
#@LICENSE
#@DEFAULT GPL-2+


#@section const
readonly EVENT_LOOP_SHOULD_RUN=0
readonly EVENT_LOOP_WANT_EXCEPTION=1
readonly EVENT_LOOP_DID_NOT_RUN=2
readonly EVENT_LOOP_INVALID=3

#@section functions

# void event_loop_exception ( log_message=, **event_loop_status! )
#
event_loop_exception() {
   #[ -z "${1-}" ] || logger ... "${1}"
   event_loop_status=${EVENT_LOOP_WANT_EXCEPTION}
}

# void event_loop_resume ( **event_loop_status! )
#
event_loop_resume() {
   event_loop_status=${EVENT_LOOP_SHOULD_RUN}
}

# @private shbool event_loop__should_run (
#    **event_loop_status:=EVENT_LOOP_INVALID?!
# )
#
event_loop__should_run() {
   [[ \
      ${event_loop_status:=${EVENT_LOOP_INVALID}} \
      -eq ${EVENT_LOOP_SHOULD_RUN} \
   ]]
}


# int event_loop_inner (
#    *cmdv, **F_EVENT_DATA_HANDLER, **F_EVENT_ON_EXC=return,
#    **EVENT_READ_OPTS=["-r",],
#    (**event_data!)
# )
#
#  Calls %F_EVENT_DATA_HANDLER ( <event_data>, **<event_data> ) for each
#  output (line, depending on %EVENT_READ_OPTS) from %cmdv.
#
#  %event_data is passed both as arg and variable since %EVENT_READ_OPTS
#  could cause event_data to be an array etc.
#
event_loop_inner() {
   #@VARCHECK F_EVENT_DATA_HANDLER event_loop_status *
   local event_data
   while \
      event_loop__should_run && \
      read "${EVENT_READ_OPTS[@]--r}" event_data
   do
      ${F_EVENT_DATA_HANDLER:?} "${event_data}" || ${F_EVENT_ON_EXC:-return}
      # reset %event_loop_status if %F_EVENT_DATA_HANDLER() unset it
   done < <( "${EVENT_CMDV[@]}" )
}

# int event_loop (
#    event_handler, event_exit_handler=<break>, *cmdv,
#    (**event_loop_status!)
# )
#
event_loop() {
   #@VARCHECK 1 3
   local F_EVENT_DATA_HANDLER="${1}"
   local F_EVENT_EXIT_HANDLER="${2:-break}"
   local event_loop_status=0
   local event_loop_rc
   shift 2 || return ${EVENT_LOOP_INVALID}
   local EVENT_CMDV=( "$@" )

   while event_loop__should_run; do
      event_loop_rc=0
      event_loop_inner "${EVENT_CMDV[@]}" || event_loop_rc=${?}
      case "${F_EVENT_EXIT_HANDLER-}" in
         ''|'break')
            break
         ;;
         *)
            ${F_EVENT_EXIT_HANDLER} "${event_loop_rc}" || return ${?}
         ;;
      esac
   done

   return ${event_loop_rc:-${EVENT_LOOP_DID_NOT_RUN}}
}
