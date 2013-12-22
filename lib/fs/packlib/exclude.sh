#@HEADER
# exclude list helpers for mksquashfs/tar
#

#@section functions

## squashfs list item creators

# int pack_exclude__squashfs_rel_file ( relpath, **PACK_SRC, **item! )
#
pack_exclude__squashfs_rel_file() {
   [ -n "${1}" ] || return 1
   local k="${1#/}"
   item="-e${NEWLINE}${PACK_SRC%/}/${k#./}"
}

# int pack_exclude__squashfs_rel_dir ( relpath, **PACK_SRC, **item! )
pack_exclude__squashfs_rel_dir() {
   [ -n "${1}" ] && pack_exclude__squashfs_rel_file "${1%/}/"
}

# int pack_exclude__squashfs_abs_file ( abspath, **item! )
#
pack_exclude__squashfs_abs_file() {
   [ -n "${1}" ] || return 1
   item="-e${NEWLINE}${1}"
}

# int pack_exclude__squashfs_abs_dir ( abspath, **item! )
#
pack_exclude__squashfs_abs_dir() {
   [ -n "${1}" ] && pack_exclude__squashfs_abs_file "${1%/}/"
}


## tar list item creators

# int pack_exclude__tar_rel_file ( relpath, **item! )
#
pack_exclude__tar_rel_file() {
   [ -n "${1}" ] || return 1
   local k="${1#/}"
   item="--exclude${NEWLINE}./${k#./}"
}

# int pack_exclude__tar_rel_dir ( relpath, **item! )
#
pack_exclude__tar_rel_dir() {
   [ -n "${1}" ] && pack_exclude__tar_rel_file "${1%/}/*"
}

# int pack_exclude__tar_abs_file ( abspath, **PACK_SRC, **item! )
#
pack_exclude__tar_abs_file() {
   local v0

   if [ -z "${1}" ]; then
      return 1
   elif get_fspath "${1}" && get_relpath "${PACK_SRC}" "${v0}"; then
      item="--exclude${NEWLINE}${v0}"
      return 0
   else
      # warn?
      return 2
   fi
}

# int pack_exclude__tar_abs_dir ( abspath, **PACK_SRC, **item! )
#
pack_exclude__tar_abs_dir() {
   local v0

   if [ -z "${1}" ]; then
      return 1
   elif get_fspath "${1}" && get_relpath "${PACK_SRC}" "${v0}"; then
      item="--exclude${NEWLINE}${v0}/*"
      return 0
   else
      # warn?
      return 2
   fi
}

# int pack_exclude__prefix_item (
#    fspath, **PACK_EXCLUDE_PREFIX, **F_PACK_EXCLUDE_CREATE_ITEM
# )
#
pack_exclude__prefix_item() {
   [ -n "${1}" ] && \
      ${F_PACK_EXCLUDE_CREATE_ITEM:?} "${PACK_EXCLUDE_PREFIX}${1}"
}



## actual pack_exclude() functions

# @extern void zap_exclude_list()
#
# @extern ~int exclude_list_call ( func )
#

# @private void pack_exclude_list_append ( exclude_type, *values )
#
pack_exclude_list_append() {
   local F_PACK_EXCLUDE_CREATE_ITEM=pack_exclude__${PACK_TYPE:?}_${1:?}
   local F_CREATE_EXCLUDE_ITEM

   if [ -n "${PACK_EXCLUDE_PREFIX-}" ]; then
      F_CREATE_EXCLUDE_ITEM=pack_exclude__prefix_item
   else
      F_CREATE_EXCLUDE_ITEM="${F_PACK_EXCLUDE_CREATE_ITEM}"
   fi

   shift
   exclude_list_append "$@"
}

# void pack_exclude_set_prefix ( prefix, **PACK_EXCLUDE_PREFIX! )
#
pack_exclude_set_prefix() {
   PACK_EXCLUDE_PREFIX="${1?}"
   if [ -n "${PACK_EXCLUDE_PREFIX}" ]; then
      PACK_EXCLUDE_PREFIX="${PACK_EXCLUDE_PREFIX%/}/"
   fi
}

# void pack_exclude_prefix_foreach (
#    prefix, *values, **F_PACK_EXCLUDE=pack_exclude_file
# )
pack_exclude_prefix_foreach() {
   local PACK_EXCLUDE_PREFIX
   pack_exclude_set_prefix "${1?}"
   shift
   ${F_PACK_EXCLUDE:-pack_exclude_file} "$@"
}


pack_exclude_file() {
   pack_exclude_list_append rel_file "$@"
}

pack_exclude_file_abs() {
   pack_exclude_list_append abs_file "$@"
}

pack_exclude_dir() {
   pack_exclude_list_append rel_dir "$@"
}

pack_exclude_dir_abs() {
   pack_exclude_list_append abs_dir "$@"
}

pack_exclude_image_dir() {
   if [ -n "${PACK_IMAGE_DIR-}" ]; then
      pack_exclude_list_append abs_dir "${PACK_IMAGE_DIR}"
   fi
}

pack_exclude_sub_mounts() {
   # COULDFIX: detect subtrees,
   #           e.g. "/mnt/disk","/mnt/disk/proc" -> exclude "/mnt/disk" only
   #
   [ -r /proc/self/mounts ] || return 0
   local fs mp DONT_CARE

   while read -r fs mp DONT_CARE; do
      case "${mp}" in
         "${PACK_SRC%/}/"?*)
            pack_exclude_dir_abs "${mp}"
         ;;
      esac
   done < /proc/self/mounts
}
