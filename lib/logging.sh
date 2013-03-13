# int __logging_accept_level ( log_level )
#
#  Returns 0 if the given log level is (currently) accepted, else 1.
#
__logging_accept_level() {
   case "${1?}" in
      'DEBUG')
         [ "${DEBUG:-n}" = "y" ] || return 1
      ;;
   esac
   return 0
}

# @pass-through dolog (
#    <var args>,
#    **LOGFILE=,
#    **DOLOG_PRINT=y
# )
# DEFINES @logger <log level> <function name>
#
#  Logs zero or more messages to console if DOLOG_PRINT is set to 'y' and to
#  disk if LOGFILE is set and has a non-zero value.
#
#  The basic usage is "dolog --level=<log level> message".
#  For advanced usage, have a look at the "parse args" block below.
#
dolog() {
   local rc=$?

   # have any log dest?
   [ -n "${LOGFILE-}" ] || [ "${DOLOG_PRINT:-y}" = "y" ] || return ${rc}

   # parse args
   local level facility= time=0 msg= prefix= suffix=
   while [ $# -gt 0 ]; do
      case "${1}" in
         --level=*)
            level="${1#--level=}"
         ;;
         level=*)
            level="${1#level=}"
         ;;
         +?*)
            facility="${facility-}${facility:+.}${1#+}"
         ;;
         --facility=*)
            facility="${facility-}${facility:+.}${1#--facility=}"
         ;;
         --time|-t)
            time=1
         ;;
         --prefix=*|--pre=*)
            prefix="${1#*=}"
         ;;
         --suffix=*|--post=*)
            suffix="${1#*=}"
         ;;
         '')
            true
         ;;
         *)
            if [ -n "${msg-}" ]; then
msg="${msg}
${1# }"
            else
msg="${1# }"
            fi
         ;;
      esac
      shift
   done

   # set log level
   : ${level:=INFO}

   case "${level}" in
      INFO|WARN|ERROR|CRITICAL|DEBUG)
         true
      ;;
      info)
         level=INFO
      ;;
      warn)
         level=WARN
      ;;
      error)
         level=ERROR
      ;;
      critical)
         level=CRITICAL
      ;;
      debug)
         level=DEBUG
      ;;
      *)
         level=`echo "${level}" | tr [:lower:] [:upper:]`
      ;;
   esac

   # immediately return if log level is not enabled
   __logging_accept_level "${level}" || return ${rc}

   # construct the log message(s)
   local log_head_level="[${level}]" log_head=
   [ -z "${facility-}" ] || log_head="${log_head-}${log_head:+ }[${facility}]"

   if [ ${time} -eq 1 ]; then
      log_head="${log_head-}${log_head:+ }$(date +'%F %H:%M:%S') --"
   fi

   [ -z "${prefix-}"   ] || prefix="${prefix% } "
   [ -z "${suffix-}"   ] || suffix=" ${suffix# }"
   [ -z "${log_head-}" ] || log_head="${log_head} "

   # determine the console message function
   local print_func=true
   if [ "${DOLOG_PRINT:-y}" = "y" ]; then
      case "${level}" in
         ERROR|CRITICAL)
            print_func=eerror
         ;;
         WARN)
            print_func=ewarn
         ;;
         *)
            print_func=einfo
         ;;
      esac
   fi

   # finally log the message(s)
   local IFS="${IFS_NEWLINE}"
   set -- ${msg}
   IFS="${IFS_DEFAULT}"

   while [ $# -gt 0 ]; do
      ${print_func} "${log_head}${prefix}${1}${suffix}" "${log_head_level}"
      if [ -n "${LOGFILE-}" ]; then
         echo "${log_head_level} ${log_head}${prefix}${1}${suffix}" >> "${LOGFILE}"
      fi
      shift
   done

   # pass the initial return value
   return ${rc}
}

## logger functions

# @logger DEBUG     dolog_debug
# @logger INFO      dolog_info
# @logger WARN      dolog_warn
# @logger ERROR     dolog_error
# @logger CRITICAL  dolog_critical
# @logger TIMESTAMP dolog_timestamp
dolog_debug()     { dolog "$@" --level=DEBUG; }
dolog_info()      { dolog "$@" --level=INFO; }
dolog_warn()      { dolog "$@" --level=WARN; }
dolog_error()     { dolog "$@" --level=ERROR; }
dolog_critical()  { dolog "$@" --level=CRITICAL; }
dolog_timestamp() { dolog "$@" --time --level=TIMESTAMP; }

# void get_logger ( name, [facility...] )
#
#  Creates a logger function with the given name whose root facility (fixed
#  arg) is %facility if specified, else %name.
#
get_logger() {
   local logger_name="${1:?}" facility=

   if [ $# -gt 1 ]; then
      while shift && [ $# -gt 0 ]; do
         facility="${facility-}${facility:+.}${1#+}"
      done
   else
      facility="${1#*log_}"
   fi

   eval "${logger_name}() { dolog --facility=\"${facility}\" \"\$@\"; }"
}

# @implicit void main()
#
#  Sets LOGFILE to /init.log if the pid of this process is 1.
#
if [ $$ -eq 1 ]; then
   : ${LOGFILE=/init.log}
else
   : ${LOGFILE=}
fi
