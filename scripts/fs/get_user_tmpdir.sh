# get_user_tmpdir
#
#  This script creates per-user tmpdirs
#
# Usage:
#
# * get_user_tmpdir [-q] [self]
#    Create tmpdir for the user that invoked this script.
#    May not be run by root unless "self" is given.
#
# * get_user_tmpdir [-q] user uid gid
#    Create tmpdir for the specified user. Can only be run by root.
#
# The tmpdir will be printed to stdout if successful.
# The -q switch suppresses all output and must be the first arg.
# (Useful for non-interactive code, e.g. in ~/.bash_profile)
#
# Depends on
#
# * /usr/bin/sudo (if not run as root)
# * /bin/busybox with mkdir, chmod, chown, id, touch
#
set -e
set -u

umask 0022

readonly SUDO=/usr/bin/sudo
readonly BUSYBOX=/bin/busybox

readonly TMPROOT=/tmp/users

readonly PATH=

qwrap() {
   if [ -z "${QUIET-}" ]; then
      "$@"
   else
      "$@" 2>/dev/null
   fi
}
reexec_as_root() {
   ## not a real exec() call
   qwrap ${SUDO} -n -u root -- "${0}" ${QUIET:+-q} "$@" || exit ${?}
   exit 0
}

bb_run() { qwrap ${BUSYBOX} "$@" 1>/dev/null; }
vecho()  { [ -n "${QUIET-}" ] || echo "$@" 2>/dev/null; }
verror() { vecho "$@" 1>&2; }
vdie()   { [ -z "${1-}" ] || verror "${1}"; exit "${2:-2}"; }

# int make_tmproot ( **TMPROOT )
#
make_tmproot() {
   if ! [ -d "${TMPROOT}" ]; then
      local p="${TMPROOT%/*}"
      [ -z "${p}" ] || [ -d "${p}" ] || \
         bb_run mkdir -p -m 0755 -- "${p}" || return

      bb_run mkdir -m 0711 -- "${TMPROOT}" || return
      # @double-tap
      bb_run chown 0:0 -- "${TMPROOT}"     || return
   fi
   bb_run touch "${TMPROOT}/.keep"
}

# int make_tmpdir ( user, uid, gid )
#
make_tmpdir() {
   local T="${TMPROOT}/${1:?}"
   if [ -d "${T}" ]; then
      bb_run chmod 0700 -- "${T}"
   else
      bb_run mkdir -m 0700 -- "${T}"
   fi && \
   bb_run chown "${2:?}:${3:?}" -- "${T}" && \
   bb_run touch "${T}/.keep" && \
   vecho "${T}"
}

if [ "x${1-}" = "x-q" ]; then
   QUIET=y
   shift || exit
elif [ "${QUIET:-n}" != "y" ]; then
   QUIET=
fi
readonly QUIET

## note that "! [ <test sth> ]" and "[ ! <test sth> ]" are *not* equal
## if <test sth> is not a valid statement.
## The former one returns 0, and the latter one 2.
##
if ! [ -x "${BUSYBOX}" ]; then
   vdie "busybox (${BUSYBOX}) is missing." 10

elif [ -z "${UID-}" ]; then
   vdie "UID is not set." 11

elif ! [ "${UID}" -ge 0 2>/dev/null ]; then
   vdie "bad UID '${UID}'." 12

elif [ -z "${USER-}" ]; then
   vdie "USER is not set." 13

elif [ "${USER}" = "nobody" ]; then
   vdie "USER must not be nobody." 14

elif [ "${UID}" != "0" ]; then
   if [ -x "${SUDO}" ]; then
      T_GID=$( ${BUSYBOX} id -g 2>/dev/null )

      if [ -n "${T_GID}" ]; then
         reexec_as_root "${USER}" "${UID}" "${T_GID}"
      else
         vdie "failed to set T_GID." 20
      fi
   else
      vdie "sudo (${SUDO}) is missing." 21
   fi
   # undef
   exit 29

elif [ "x${1-}" = "xself" ]; then
   make_tmproot         || vdie "failed to create tmproot." 30
   make_tmpdir root 0 0 || vdie "failed to create tmpdir."  31

elif [ "x${1:+S}${2:+E}${3:+T}" = "xSET" ]; then
   make_tmproot                     || vdie "failed to create tmproot." 40
   make_tmpdir "${1}" "${2}" "${3}" || vdie "failed to create tmpdir."  41

else
   vdie "missing user, uid and/or gid." 15
fi
