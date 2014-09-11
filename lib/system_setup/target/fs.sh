#@HEADER
# fs ops:
#
#  <name>::T ::= <name> is a filesystem path under TARGET_DIR
#  (== is $TARGET_DIR or matches $TARGET_DIR/*)
#
#  rel_<name> ::= <name> must be interpreted as filesystem path under
#                TARGET_DIR
#                 (== prefix $$name with $TARGET_DIR/ if necessary)
#
#
#  copy_tree               ( src,    dst::T )
#  move_file               ( src::T, dst::T )
#  copy_file               ( src,    dst::T )
#  create_symlink          ( src,    dst::T )
#  remove_file             ( dst::T )
#  make_dirs               -- not available
#
#  target_copy_tree        ( src,     rel_dst )
#  target_move_file        ( rel_src, rel_dst )
#  target_copy_file        ( src,     rel_dst )
#  target_create_symlink   ( src,     rel_dst )
#  target_remove_file      ( rel_dst )
#  target_make_dirs        ( *rel_dst )
#
#  intarget_copy_tree      ( rel_src, rel_dst )
#  intarget_move_file      ( rel_src, rel_dst )
#  intarget_copy_file      ( rel_src, rel_dst )
#  intarget_create_symlink -- not available
#  intarget_remove_file    -- alias to target_remove_file()
#  intarget_make_dirs      -- alias to target_make_dirs()
#

#@section vars
: ${COPY_TREE_RSYNC_OPTS="-H"}
: ${COPY_TREE_CP_OPTS=}
: ${COPY_FILE_OPTS=}
: ${MOVE_FILE_OPTS=}
: ${CREATE_SYMLINK_OPTS=}

#@section functions

# target_*() wrappers
DONT_OVERRIDE_FUNCTION target_copy_tree
target_copy_tree() {
   local v0; apply_target_path_prefix "${2:?}"
   copy_tree "${1:?}" "${v0:?}"
}

DONT_OVERRIDE_FUNCTION target_move_file
target_move_file() {
   local v0; apply_target_path_prefix "${2:?}"
   move_file "${1:?}" "${v0:?}"
}

DONT_OVERRIDE_FUNCTION target_copy_file
target_copy_file() {
   local v0; apply_target_path_prefix "${2:?}"
   copy_file "${1:?}" "${v0:?}"
}

DONT_OVERRIDE_FUNCTION target_create_symlink
target_create_symlink() {
   local v0; apply_target_path_prefix "${2:?}"
   create_symlink "${1:?}" "${v0:?}"
}

DONT_OVERRIDE_FUNCTION target_remove_file
target_remove_file() {
   local v0; apply_target_path_prefix "${1:?}"
   remove_file "${v0:?}"
}

# intarget_*() wrappers
DONT_OVERRIDE_FUNCTION intarget_copy_tree
intarget_copy_tree() {
   local v0; apply_target_path_prefix "${1:?}"
   target_copy_tree "${v0:?}" "${2:?}"
}

DONT_OVERRIDE_FUNCTION intarget_move_file
intarget_move_file() {
   local v0; apply_target_path_prefix "${1:?}"
   target_move_file "${v0:?}" "${2:?}"
}

DONT_OVERRIDE_FUNCTION intarget_copy_file
intarget_copy_file() {
   local v0; apply_target_path_prefix "${1:?}"
   target_copy_file "${v0:?}" "${2:?}"
}

DONT_OVERRIDE_FUNCTION intarget_remove_file
intarget_remove_file() {
   target_remove_file "$@"
}

DONT_OVERRIDE_FUNCTION intarget_make_dirs
intarget_make_dirs() {
   target_make_dirs "$@"
}


# recursive copy, using rsync||cp
DONT_OVERRIDE_FUNCTION copy_tree
if hash rsync 2>/dev/null; then

copy_tree() {
   : ${1:?} ${2:?}
   check_is_target_path "${2%/}/" "copy_tree dest"

   run_dmc mkdir ${DODIR_OPTS--p} -- "${2%/*}" && \
   run_dmc rsync -a ${COPY_TREE_RSYNC_OPTS-} -- "${1%/}/" "${2%/}/"
}

else

copy_tree() {
   : ${1:?} ${2:?}
   check_is_target_path "${2%/}/" "copy_tree dest"

   run_dmc mkdir ${DODIR_OPTS--p} -- "${2%/*}" && \
   run_dmc cp -a ${COPY_TREE_CP_OPTS-} -- "${1%/}/." "${2%/}/"
}

fi # hash rsync

# file move/copy
DONT_OVERRIDE_FUNCTION move_file
move_file() {
   : ${1:?} ${2:?}
   check_is_target_path "${1}" "move_file src"
   check_is_target_path "${2}" "move_file dest"

   run_dmc mkdir ${DODIR_OPTS--p} -- "${2%/*}" && \
   run_dmc mv ${MOVE_FILE_OPTS-} ${MV_OPT_NO_TARGET_DIR--T} -- "${1}" "${2}"
}

DONT_OVERRIDE_FUNCTION copy_file
copy_file() {
   : ${1:?} ${2:?}
   check_is_target_path "${2}" "copy_file dest"

   run_dmc mkdir ${DODIR_OPTS--p} -- "${2%/*}" && \
   run_dmc cp ${COPY_FILE_OPTS-} ${CP_OPT_NO_TARGET_DIR--T} -- "${1}" "${2}"
}

DONT_OVERRIDE_FUNCTION remove_file
remove_file() {
   : ${1:?}
   check_is_target_path "${1}" "remove_file path"

   run_dmc rm ${REMOVE_FILE_OPTS-} -- "${1}"
}

DONT_OVERRIDE_FUNCTION target_make_dirs
target_make_dirs() {
   local v0

   while [ $# -gt 0 ]; do
      apply_target_path_prefix "${1}"

      run_dmc mkdir ${DODIR_OPTS--p} -- "${v0}" || return ${?}
      shift
   done

   return 0
}

DONT_OVERRIDE_FUNCTION create_symlink
create_symlink() {
   : ${1:?} ${2:?}
   check_is_target_path "${2}" "symlink path"

   run_dmc mkdir ${DODIR_OPTS--p} -- "${2%/*}" && \
   run_dmc ln -s \
      ${CREATE_SYMLINK_OPTS-} ${LN_OPT_NO_TARGET_DIR--T} -- "${1}" "${2}"
}
