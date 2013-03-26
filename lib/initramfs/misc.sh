# int initramfs_sleep ( *time )
#
#  Sleeps for the specified amount of time.
#
initramfs_sleep() {
	${LOGGER} --level=DEBUG "(initramfs) sleeping for $*"
	sleep "$@"
}

# int initramfs_debug_sleep ( *time, **INITRAMFS_DEBUG_SLEEP=y )
#
#  Sleeps for the specified amount of time if INITRAMFS_DEBUG_SLEEP
#  is set to y.
#
initramfs_debug_sleep() {
	if [ "${INITRAMFS_DEBUG_SLEEP:-y}" = "y" ]; then
		${LOGGER} --level=INFO "(initramfs debug) sleeping for $*"
		sleep "$@"
	else
		return 0
	fi
}

# int initramfs_rootdelay ( **CMDLINE_ROOTDELAY= )
#
#  rootdelay sleeping.
#
initramfs_rootdelay() {
	if [ -n "${CMDLINE_ROOTDELAY-}" ]; then
		dolog_info "rootdelay: sleeping for ${CMDLINE_ROOTDELAY} seconds"
		sleep "${CMDLINE_ROOTDELAY}"
	else
		return 0
	fi
}

# int initramfs_kmsg_redirect ( **CONSOLE )
#
#  Sets up stderr/stdout redirection to /dev/kmsg.
#
initramfs_kmsg_redirect() {
	exec >/dev/kmsg 2>&1 <${CONSOLE:?}
}

# void initramfs_suppress_printk()
#
#  Stops kernel messages from "polluting" the console.
#
initramfs_suppress_printk() {
	echo 0 > /proc/sys/kernel/printk
}

# void initramfs_switch_root ( *argv ), raises initramfs_die()
#
#  Switches to NEWROOT.
#
initramfs_switch_root() {
	: ${CMDLINE_INIT:=/sbin/init}

	[ -x "${NEWROOT}/${CMDLINE_INIT#/}" ] || \
		initramfs_die "cannot locate ${CMDLINE_INIT} in ${NEWROOT}"

	if [ $# -eq 0 ] && [ -n "${INIT_ARGV+y}" ]; then
		# this does not handle whitespace in INIT_ARGV
		set -- ${INIT_ARGV}
	fi

	local opts=""
	[ -z "${CONSOLE-}" ] || opts="${opts} -c ${CONSOLE}"

	exec switch_root ${opts} "${NEWROOT}" ${CMDLINE_INIT} "$@"
	initramfs_die "switch_root failed"
}
