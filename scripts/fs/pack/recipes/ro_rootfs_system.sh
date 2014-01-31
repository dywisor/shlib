#@section module_init

##if ! __pack_pretend__; then

# keep portage db/cache?
#  note that setting 'n' here makes the target unusable for recovery
#
: ${KEEP_VAR_PORTAGE:=n}

##fi # !__pack_pretend__


#@section functions

pack_target_rootfs() {
   next / name rootfs as tarball

   #exf /busybox_static
   exf /LIRAM /CHROOT /BUILD /_SETUP_SCRIPTS /portage
   exf \
      /_compare_etc.sh /pack.sh /stagemounts.sh \
      /upgrade.sh /_symstorm_squashed.bash

   exd /proc /sys /dev /run
   exd /squashed-rootfs /etc /var
   exd /tmp /mnt /media
   exd /boot /kernel-modules
   exd /persistent
}

pack_target_system() {
   next /squashed-rootfs name squashed-rootfs as squashfs

   exf /usr/portage /usr/tmp /usr/src
}

pack_target_etc() {
   next /etc as tarball
}

pack_target_var() {
   next /var as tarball

   exd /tmp /run /lock

   if [ "${KEEP_VAR_PORTAGE:-n}" != "y" ]; then
      ex /portage /db/pkg /cache/eix /cache/edb
   fi

   ex /log/portage /log/emerge.log /log/emerge-fetch.log
}

pack_target_var_pkg_db() {
   next /var/db/pkg as tarball
}

pack_target_persistent() {
   next /persistent as tarball

   ex_prefix_foreach /users/root .config .gconfd .bash_history .distcc
}


#@section module_init
register_target rootfs
register_target system
register_target etc
register_target var
register_target persistent
#kernel-modules, kernel from @extern
declare_target var_pkg_db
