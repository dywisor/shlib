#@section functions

# void liram_manage_check_vars ( *varnames )
#
#  Verifies that the given variables are set and not empty.
#  Dies on first failure.
#
liram_manage_check_vars() {
   while [ ${#} -gt 0 ]; do
      if ! var_is_set_nonempty "${1}"; then
         liram_manage_die "\$${1} is not set." || return
      fi
      shift
   done
}

# int liram_manage_check_dir_writable ( dirpath )
#
liram_manage_check_dir_writable() {
   touch "${1}/.keep" 2>>${DEVNULL}
}

# int liram_manage_boot_slot_exists ( **LIRAM_BOOT_SLOT )
#
#  Returns 0 if the boot slot exists (as directory), else 1.

liram_manage_boot_slot_exists() {
   [ -d "${LIRAM_BOOT_SLOT}" ]
}

# void liram_manage_update_boot_slot ( name|relpath, **LIRAM_BOOT_SLOT )
#
liram_manage_update_boot_slot() {
   #@VARCHECK 1
   if [ -e "${LIRAM_BOOT_SLOT}" ] && [ ! -h "${LIRAM_BOOT_SLOT}" ]; then
      liram_manage_die "cannot update boot slot: exists, but is not a symlink."

   elif [ -d "${LIRAM_IMAGE_ROOT}/${1}/" ]; then
      liram_manage_log_info "setting boot slot to ${1}"
      liram_manage_autodie ln -nsfT -- "${1}" "${LIRAM_BOOT_SLOT}"

   else
      liram_manage_die "cannot update boot slot to ${1}: no such slot."
   fi
}

# int liram_manage_fixup_boot_slot()
#
liram_manage_fixup_boot_slot() {
   # recover LIRAM_BOOT_SLOT if required and possible
   if [ -z "${LIRAM_BOOT_SLOT-}" ]; then
      liram_manage_log_info "boot slot: not set, fixup not possible."
      return 0

   elif liram_manage_boot_slot_exists; then
      liram_manage_log_debug "boot slot: exists, fixup not necessary."
      return 0

   elif [ -z "${LIRAM_FALLBACK_SLOT_NAME-}" ]; then
      liram_manage_log_warn \
         "boot slot: fallback slot is not set, fixup not possible."
      return 1

   else
      liram_manage_log_info "boot slot: fixup required and possible."
      liram_manage_update_boot_slot "${LIRAM_FALLBACK_SLOT_NAME}"
   fi
}

# void liram_manage_get_slot (
#    slot_name=**LIRAM_SLOT_NAME, **LIRAM_IMAGE_ROOT,
#    **LIRAM_DEST_SLOT!, **LIRAM_DEST_SLOT_NAME!,
#    **LIRAM_DEST_SLOT_WORKDIR!, **LIRAM_DEST_SLOT_SUCCESS!
# ), raises liram_manage_die()
#
#  Creates a new (unique) slot in %LIRAM_IMAGE_ROOT.
#  Dies on error.
#
liram_manage_get_slot() {
   LIRAM_DEST_SLOT=
   LIRAM_DEST_SLOT_NAME=
   LIRAM_DEST_SLOT_WORKDIR=
   LIRAM_DEST_SLOT_SUCCESS=n

   local base_slot slot
   local i prev_i

   # slot_name should not contain any "/" chars
   base_slot="${LIRAM_IMAGE_ROOT}/${1:-${LIRAM_SLOT_NAME}}"

   liram_manage_log_info "Trying to get a slot (${1:-${LIRAM_SLOT_NAME}})"

   if mkdir -- "${base_slot}" 2>>${DEVNULL}; then
      LIRAM_DEST_SLOT="${base_slot}"
   else
      # resolve conflict
      i=1
      prev_i=0
      slot="${base_slot}-r${i}"

      while ! mkdir -- "${slot}" 2>>${DEVNULL}; do
         prev_i="${i}"
         i=$(( ${i} + 1 ))
         [ ${i} -gt ${prev_i} ] || liram_manage_die "overflow"       || return
         [ ${i} -lt 1000      ] || liram_manage_die "too many slots" || return
         slot="${base_slot}-r${i}"
      done

      LIRAM_DEST_SLOT="${slot}"
   fi

   LIRAM_DEST_SLOT_NAME="${LIRAM_DEST_SLOT##*/}"
   liram_manage_autodie mkdir -- "${LIRAM_DEST_SLOT}/work" && \
      LIRAM_DEST_SLOT_WORKDIR="${LIRAM_DEST_SLOT}/work" || return

   liram_manage_log_info "New slot is ${LIRAM_DEST_SLOT_NAME}"
}

liram_manage_have_pack_script() {
   case "${LIRAM_MANAGE_PACK_SCRIPT-}" in
      '')
         return 1
      ;;
      /*)
         [ -x "${LIRAM_MANAGE_PACK_SCRIPT}" ] || return 2
      ;;
      *)
         qwhich "${LIRAM_MANAGE_PACK_SCRIPT}" || return 3
      ;;
   esac
   return 0
}

# int liram_manage_call_pack_script (
#    *pack_targets,
#    **LIRAM_IMAGE_ROOT, **LIRAM_DEST_SLOT_WORKDIR, **PACK_SCRIPT_ARGS=
# )
#
liram_manage_call_pack_script() {
   "${LIRAM_MANAGE_PACK_SCRIPT:?}" \
      -t xz -s gzip --no-overwrite --root / \
      --image-dir "${LIRAM_DEST_SLOT_WORKDIR}" ${PACK_SCRIPT_ARGS} "$@"
}
