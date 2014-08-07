#@section vars
SYSTEMD_NSPAWN_GENTOO_PORTAGE_ROOT_HOST=/portage
SYSTEMD_NSPAWN_GENTOO_PORTAGE_ROOT_CONTAINER=/portage

SYSTEMD_NSPAWN_GENTOO_TMP_SIZE=100m
SYSTEMD_NSPAWN_GENTOO_VARTMP_SIZE=12G

SYSTEMD_NSPAWN_GENTOO_NETWORK="bridge=@default"

#@section functions

systemd_nspawn_add_gentoo_defaults() {
   local p c
   p="${SYSTEMD_NSPAWN_GENTOO_PORTAGE_ROOT_HOST:?}"
   c="${SYSTEMD_NSPAWN_GENTOO_PORTAGE_ROOT_CONTAINER:?}"

   systemd_nspawn_add_bind_mounts \
      @${p}:${c} \
         @ro /tree \
         @rw /distfiles /packages

   systemd_nspawn_add_tmpfs_mounts \
      /tmp:rw,nodev,size=${SYSTEMD_NSPAWN_GENTOO_TMP_SIZE:?} \
      /var/tmp:rw,dev,exec,suid,size=${SYSTEMD_NSPAWN_GENTOO_VARTMP_SIZE:?}

   if [ -n "${SYSTEMD_NSPAWN_GENTOO_NETWORK?}" ]; then
      systemd_nspawn_add_network ${SYSTEMD_NSPAWN_GENTOO_NETWORK}
   fi
}
