## bash_compat sets some handy variables

# void bash_compat()
#
#  Sets the EUID, UID and USER variables if unset.
#  Any output will be redirected to /dev/null.
#
bash_compat() {
   if [ -z "${EUID-}" ]; then
      EUID=`id -u 2>/dev/null`
      [ -n "${EUID}" ] || EUID=65534
   fi
   if [ -z "${UID-}" ]; then
      UID=`id -r -u 2>/dev/null`
      [ -n "${UID}" ] || UID=65534
   fi
   if [ -z "${USER-}" ]; then
      USER=`id -r -u -n 2>/dev/null`
      [ -n "${USER}" ] || USER=nobody
   fi
}

[ -n "${BASH_VERSION-}" ] || [ $$ -eq 1 ] || bash_compat