#@section header
## bash_compat sets some handy variables

#@section functions_public

# void bash_compat()
#
#  Sets the SHELL, EUID, UID and USER variables if unset.
#  Any output will be redirected to /dev/null.
#
bash_compat() {
   : ${SHELL:=/bin/sh}

   if [ -z "${EUID-}" ]; then
      EUID=$(id -u 2>/dev/null)
      [ -n "${EUID}" ] || EUID=65534
   fi
   if [ -z "${UID-}" ]; then
      UID=$(id -r -u 2>/dev/null)
      [ -n "${UID}" ] || UID=65534
   fi
   if [ -z "${USER-}" ]; then
      USER=$(id -r -u -n 2>/dev/null)
      [ -n "${USER}" ] || USER=nobody
   fi
}

#@section module_init
[ -n "${BASH_VERSION-}" ] || [ $$ -eq 1 ] || bash_compat
