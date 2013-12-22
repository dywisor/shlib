#@section functions
pack_target_all() {
   pack_run_targets ${PACK_TARGETS-}
   pack_virtual_target_done
}

pack_target_rootfs_example() {
   pack_init_target / as tarball name rootfs --xdev
   pack_exclude_file /CHROOT
   pack_exclude_dir /proc /sys /dev /run /tmp
}

#@section module_init
pack_declare_target all rootfs_example
