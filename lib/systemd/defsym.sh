#@section const

readonly DEFAULT_SYSTEMD_LIBDIR=/usr/lib/systemd

#@section module_init_vars

if [ -z "${SYSTEMD_LIBDIR-}" ]; then
   __systemd_defsym_iter=
   SYSTEMD_LIBDIR="${DEFAULT_SYSTEMD_LIBDIR}"

   for __systemd_defsym_iter in /usr/lib/systemd /lib/systemd; do
      if [ -d "${__systemd_defsym_iter}" ]; then
         SYSTEMD_LIBDIR="${__systemd_defsym_iter}"
         break
      fi
   done

   unset -v __systemd_defsym_iter
fi
