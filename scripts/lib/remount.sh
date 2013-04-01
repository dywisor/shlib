: ${VERBOSE:=y}

case "${SCRIPT_NAME}" in
   *_*)
      MOUNTPOINT_NAME="${SCRIPT_NAME%_*}"
      REMOUNT_MODE="${SCRIPT_NAME##*_}"
   ;;
   *-*)
      MOUNTPOINT_NAME="${SCRIPT_NAME%-*}"
      REMOUNT_MODE="${SCRIPT_NAME##*-}"
   ;;
   remount*)
      die "you have to symlink this script rather than executing it directly"
   ;;
   *)
      die "cannot parse script name '${SCRIPT_NAME}'."
   ;;
esac

#[ "${REMOUNT_MODE}" = "ro" ] || [ "${REMOUNT_MODE}" = "rw" ] || \
#   die "remount mode has to be ro or rw"

case "${MOUNTPOINT_NAME}" in
   rootfs)
      MP=/
   ;;
   efi|EFI)
      MP=/boot/efi
   ;;
   log)
      MP=/var/log
   ;;
   nfs-*|nfs_*)
      MP="/nfs/${MOUNTPOINT_NAME#nfs?}"
   ;;
   *)
      MP="/${MOUNTPOINT_NAME}"
   ;;
esac

VERBOSE="${VERBOSE:-y}"

if disk_mounted "" "${MP}"; then
   remount "${MP}"
elif [ "${REMOUNT_ALLOW_MOUNT:-y}" = "y" ]; then
   domount "${MP}" -o ${REMOUNT_MODE}
else
   die "cannot mount ${MP} due to REMOUNT_ALLOW_MOUNT != y"
fi
