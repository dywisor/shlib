# This script is a template for creating system images (tarballs and squashfs
# files). (You could also call it an 'abstraction layer'.)
#
# By default, it does *nothing* - adapt it to your needs
#
#
# =======
#  HOWTO
# =======
#
# First, it's a good idea to call pack_autodie(), which will enable
# on-error exit behavior. Then, you have to call setup ( sysroot, ... ).
#
# Now that the initial setup is complete, simply define the targets that
# should be packed. A new target is introduced by
#  next ( <dir relative to sysroot>, <image name>, <pack type> )
#
# followed by zero or more exclude statements,
# * ex   -- exclude file system paths
# * exd  -- exclude the contents of directories
#            (the directory will exist as empty dir in the image)
# * exda -- exclude directories specified by absolute paths
#            (normally not needed)
#
# Finally, pack() starts creation of the image file.
#
# Note:
#  You can also implement pack targets as functions.
#  The naming convention for pack functions is pack_target_<target name>().
#  Call pack_add_target ( <target name> ) after defining its function if
#  you want to register it (i.e., add it to %PACK_TARGETS).
#  These function can be run via pack_run_target().
#
# Note #2:
#  Don't forget to exclude other pack targets!
#  (E.g. exclude /usr from the rootfs target if usr is packed as squashfs file)
#
#
# ---------
#  Example
# ---------
#
# # initial setup
# pack_autodie
# setup /chroot/target/rootfs gzip
#
# # pack the rootfs (as tarball)
# next / rootfs
# exda /proc /sys /dev /usr
# pack
#
# # pack /usr as squashfs, excluding /usr/doc and the contents of /usr/include
# next /usr as squashfs
# ex /doc
# exd /include
# pack
#
## END HEADER

# void setup ( [root_dir=**PWD], [compression_format="gzip"], [fake="n"] )
#
#  Initial setup.
#  Sets the system root directory, the tarball compression format,
#  enables/disables fake mode and sets some other variables.
#
setup() {
   : ${PACK_TARGETS=}

   # --one-file-system is a sane default
   : ${DOTAR_TAROPTS_APPEND=--one-file-system}

   ${PACK_AUTODIE-} dotar_set_root "${1:-${PWD}}"
   ${PACK_AUTODIE-} dotar_set_image_dir "${DOTAR_ROOT_DIR}/images"

   ${PACK_AUTODIE-} dotar_set_compression "${2:-gzip}"

   local T
   get_tmpdir && PACK_TMPDIR="${T?}"

   if [ "${3:-n}" = "y" ]; then
      DOTAR_FAKE=y
      ewarn "fake mode enabled, no images will be created."
   else
      DOTAR_FAKE=n
   fi
}

# void pack_add_target ( *target, **PACK_TARGETS! ), raises die()
#
#  Adds zero or more pack targets to the PACK_TARGETS variable.
#  Also verifies that the respective pack functions exist.
#
pack_add_target() {
   while [ $# -gt 0 ]; do
      assert function_defined "pack_target_${1}() { /* packs ${1} */ }"
      PACK_TARGETS="${PACK_TARGETS-}${PACK_TARGETS:+ }${1}"
      shift
   done
}

# @function_alias add_target() renames pack_add_target()
#
add_target() { pack_add_target "$@"; }

# void pack_add_virtual_target ( *target ), raises die()
#
#  Like pack_add_target(), but (currently) doesn't register the target.
#
pack_add_virtual_target() {
   while [ $# -gt 0 ]; do
      assert function_defined "pack_target_${1}() { /* virtual pack target */ }"
      shift
   done
}

# @function_alias add_virtual_target() renames pack_add_virtual_target()
#
add_virtual_target() { pack_add_virtual_target "$@"; }

# int pack_run_target ( *target )
#
#  Packs targets by calling pack_target_<target> for each <target>.
#
pack_run_target() {
	local target EX_FUNC virtual
	for target; do
      # ex_prefix_foreach() uses EX_FUNC
		EX_FUNC=ex
      virtual=pack_run_target

		einfo "Packing ${target}"
		pack_target_${target}
	done
}

# @function_alias run_target() renames pack_run_target()
#
run_target() { pack_run_target "$@"; }

# void pack_autodie ( enable=y, **PACK_AUTODIE! )
#
#   Enables/Disables autodie behavior.
#
pack_autodie() {
   case "${1-}" in
      'y'|'')
         PACK_AUTODIE=autodie
      ;;
      *)
         PACK_AUTODIE=
      ;;
   esac
}

# void next ( src_dir, name=<default>, pack_type="tar" )
#
#  Starts a new pack target that will create an image of
#  <system root directory>/<src_dir> with the given name.
#
#  The second arg sets the name of the image file. A leading '@' char will
#  be removed. Passing "as" or the empty string as name results in setting
#   PACK_NAME to the last path component of <src_dir>.
#
#  The third arg sets the type of the image, available choices are
#  * '', 'tar', 'tarball' -- create a tarball (default)
#  * 'squashfs', 'sfs'    -- create a squashfs file
#
next() {
   ${PACK_AUTODIE-} dotar_from "${1?}"
   PACK_SRC="${DOTAR__SRC_DIR:?}"

   if [ -z "${2-}" ] || [ "${2}" = "as" ]; then
      PACK_NAME="${PACK_SRC##*/}"
   else
      PACK_NAME="${2#@}"
   fi

   case "${3-}" in
      ''|'tar'|'tarball')
         PACK_SFS=n
         unset PACK_SFS_EXCLUDE
         ${PACK_AUTODIE-} dotar_zap_exclude
      ;;
      'squashfs'|'sfs')
         PACK_SFS=y
         PACK_SFS_EXCLUDE="${PACK_TMPDIR?}/sfs.exclude"
         > "${PACK_SFS_EXCLUDE}" || die
      ;;
      *)
         die "unknown pack type '${3-}'"
      ;;
   esac

   exda "${DOTAR_IMAGE_DIR}"
}

is_sfs() { [ "${PACK_SFS:?}" = "y" ]; }

# int oneshot (...)
#
#  Immediately packs a target without excluding anything.
#  Passes all args to next().
#
oneshot() {
   next "$@" && pack
}

# int pack ( **PACK_NAME )
#
#  Creates the image file. Has to be called after setting up a target.
#
pack() {
   if is_sfs; then
      ${PACK_AUTODIE-} dosfs "$@"
   else
      ${PACK_AUTODIE-} dotar ${PACK_NAME:?} "$@"
   fi
}

# @private int pack_sfs_exclude__write (
#    dirpath, **PACK_SRC, **PACK_SFS_EXCLUDE
# )
#
#  Adds dirpath to the squashfs exclude file.
#
pack_sfs_exclude__write() {
   echo "${PACK_SRC?}/${1#/}" >> "${PACK_SFS_EXCLUDE?}"
}

# int pack_sfs_exclude ( *filepath )
#
pack_sfs_exclude() {
   while [ $# -gt 0 ]; do
      [ -z "${1}" ] || pack_sfs_exclude__write "${1}" || return
      shift
   done
}

# int pack_sfs_exclude_dir ( *dirpath )
#
pack_sfs_exclude_dir() {
   while [ $# -gt 0 ]; do
      [ -z "${1%/}" ] || pack_sfs_exclude__write "${1%/}/" || return
      shift
   done
}

# int pack_sfs_exclude_dir_absolute ( *dir )
#
pack_sfs_exclude_dir_absolute() {
   while [ $# -gt 0 ]; do
      [ -z "${1%/}" ] || \
         echo "${1%/}/" >> "${PACK_SFS_EXCLUDE?}" || return
      shift
   done
}


# int dosfs ( extra_opts=, **PACK_NAME, **MKSFS_OPTS=<default> )
#
#  Creates a squashfs file for the current target (whose pack_type has to be
#  squashfs).
#
dosfs() {
   local dest_file opts
   get_destfile "${PACK_NAME:?}.sfs" || return

   # create argv
   if [ -n "${MKSFS_OPTS+SET}" ]; then
      opts="${MKSFS_OPTS}"
   else
      opts="-noI -noappend"
   fi
   #[ ! -s "${PACK_SFS_EXCLUDE?}" ] || ...
   set -- \
      ${PACK_AUTODIE-} mksquashfs \
      "${PACK_SRC?}" "${dest_file?}" \
      -ef "${PACK_SFS_EXCLUDE?}" ${opts} "$@"

   if [ "${DOTAR_FAKE:-n}" != "y" ]; then
      "$@"
   else
      einfo "dosfs cmd: $*"
      einfo "--- begin exclude list ---"
      cat "${PACK_SFS_EXCLUDE}"
      einfo "---  end exclude list  ---"
   fi
}

# void|int ex ( *file )
#
#  Adds zero or more files to the exclude list. (relative paths)
#
ex() {
   if is_sfs; then
      ${PACK_AUTODIE-} pack_sfs_exclude "$@"
   else
      ${PACK_AUTODIE-} dotar_exclude "$@"
   fi
}

# @function_alias exf() renames ex()
#
exf() { ex "$@"; }

# void|int exd ( *dir )
#
#  Adds zero or more directories to the exclude list. (relative paths)
#
exd() {
   if is_sfs; then
      ${PACK_AUTODIE-} pack_sfs_exclude_dir "$@"
   else
      ${PACK_AUTODIE-} dotar_exclude_dir "$@"
   fi
}

# void|int exda ( *dir )
#
#  Adds zero or more directories to the exclude list. (absolute paths)
#
exda() {
   if is_sfs; then
      ${PACK_AUTODIE-} pack_sfs_exclude_dir_absolute "$@"
   else
      ${PACK_AUTODIE-} dotar_exclude_abs_dir "$@"
   fi
}

# void ex_prefix_foreach ( prefix, *ex_item, **EX_FUNC=ex )
#
#  Calls EX_FUNC ( <prefix><ex_item> ) for each <ex_item>.
#
ex_prefix_foreach() {
	local p="${1?}"
	[ -z "${p}" ] || p="${p%/}/"

	while shift; do
		[ -z "${1-}" ] || ${EX_FUNC:-ex} "${p}${1}"
	done
}

# void get_destfile (
#    filename, **dest_file!, **DOTAR_IMAGE_DIR, **DOTAR_OVERWRITE
# )
#
#  Sets the %dest_file variable like dotar() would.
#
get_destfile() {
   dest_file=

   [ -n "${DOTAR_IMAGE_DIR-}" ] || function_die "DOTAR_IMAGE_DIR is not set."

   local v0="${1:?}"

   ${PACK_AUTODIE-} dotar__doprefix_if "${v0}" "${DOTAR_IMAGE_DIR}" "m"
   dest_file="${v0}"

   if [ -e "${dest_file}" ]; then
      if [ ! -f "${dest_file}" ]; then
         eerror "get_desfile: dest file '${dest_file}' exists, but is not a file."
         return 21
      elif [ "${DOTAR_OVERWRITE:-n}" != "y" ]; then
         eerror "get_detfile: dest file '${dest_file}' exists."
         return 22
      fi
   fi
}

# int pack_target_rootfs_example()
#
#  An example pack target function.
#
pack_target_rootfs_example() {
	next / rootfs
   ex   /CHROOT
	exd  /proc /sys /dev /run /tmp
	pack
}

# int pack_target_all ( **PACK_TARGETS )
#
#  Packs all targets.
#
pack_target_all() {
   [ -z "${PACK_TARGETS-}" ] || ${virtual} ${PACK_TARGETS?}
}
add_virtual_target all
