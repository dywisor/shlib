#@section vars
#X_MKNOD=mknod
#X_MDEV=/sbin/mdev

: ${DEVTMPFS_OPTS:=rw,nosuid,relatime,size=10240k,nr_inodes=64012,mode=755}
: ${DEVPTS_OPTS:=rw,nosuid,noexec,relatime,gid=5,mode=620}
: ${DEVFS_TYPE=}

: ${PROCFS_OPTS:=rw,nosuid,nodev,noexec,relatime}
: ${SYSFS_OPTS:=rw,nosuid,nodev,noexec,relatime}

: ${MDADM_SCAN_OPTS=--no-degraded}

: ${DEVFS_TTY_GID:=5}
