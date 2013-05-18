#EXPERIMENTAL
#
# This script relies on a config file that defines how a target should be built
#
# FIXME: split patchsets / external modules creation from this script

# vars

readonly CONFDIR=/etc/shlib/kcomp

HELP_DESCRIPTION="linux kernel compilation"

HELP_BODY="Prepares, configures, patches and compiles a kernel. The result
is a tarball that can be merged with the target's rootfs.
"

HELP_OPTIONS="
--force        (-f) -- create tarball file even if it already exists
--interactive  (-I) -- enable yes/no questions (allows to recover from failure)
--nconfig           -- set CONFIG_TARGET to nconfig
--oldconfig         -- set CONFIG_TARGET to oldconfig
--makepatch    (-m) -- start a shell for creating patches after cleaning up
--dist <file>       -- instead of compiling: package source tarball [TODO]
                        Note that this doesn't make any sense unless KERNEL_SRC_TYPE=tarball

--with-<patch-set>  -- enable a specific patch set,
 * aufs         -- TODO
 * zfs          -- ZFS on Linux
 * tp-smapi,
 * tp_smapi     -- tp_smapi

--with-<extra-modules> -- enable compilation of special modules,
 * acpi-call,
 * acpi_call    -- acpi_call (required by tpacpi-bat, for example)
 * vbox,
 * virtualbox   -- virtualbox modules

 --with-all     -- enable all patch sets and extra modules

--without-* can be used to remove features at runtime.

Note: unknown --with-* options will be ignored.
"

HELP_USAGE="Usage: ${SCRIPT_FILENAME} <target> [<tarball>]"


# void __panic__, raises die()
#
#  Sometimes I'm just too lazy to write error messages.
#  Needs to be fixed, though.
#
__panic__() { die "${1:-DIE BESTEN DER BESTEN DER BESTEN, SIR!}" "${2-}"; }

__double_tap__() {
   __quiet__ || ewarn "" "DOUBLE TAP!"
   "$@"
}

# void need_stdin, raises __panic__()
#
#  Raises __panic__ if no input terminal connected.
#
need_stdin() { tty -s || __panic__; }

# void this_needs_force (
#    common_message,
#    message_append_continue=,
#    message_append_exit=" (use --force)",
#    **FORCE=n
# ), raises die()
#
#  Some actions need force.
#  This function warns about that and calls die() unless %FORCE is set to 'y'.
#
this_needs_force() {
   if [ "${FORCE:-n}" = "y" ]; then
      [ -z "${1-}${2-}" ] || ewarn "${1}${2}"
      return 0
   else
      die "${1-}${3- use --force}"
   fi
}

# void einfo_<topic> (...)
#
#  einfo() wrappers.
#
einfo_action() { einfo "${1} ... " "${2-}"; }
einfo_new_modules() { einfo "${1}" "New modules:"; }
einfo_build_modules() { einfo "${1}" "Building external modules:"; }

# void kcomp_rename_use_flag ( **flag! )
#
kcomp_rename_use_flag() {
   case "${flag}" in
      vbox)
         flag=virtualbox
      ;;
      all)
         flag="zfs tp_smapi virtualbox acpi_call"
      ;;
   esac
}


# kcomp_edit_use ( *[+-]flag_name )
#
#  Enables and/or disable the listed USE flags, depending on their name
#  prefix ("-" => disable, "+" or None => "enable").
#
kcomp_edit_use() {
   F_USE_RENAME_FLAG=kcomp_rename_use_flag set_use "$@"
}


# void kcomp_main_set_target ( target, **TARGET ), raises die()
#
#  Sets and verifies the TARGET variable.
#
kcomp_main_set_target() {
   if [ -z "${TARGET-}" ]; then
      case "${1}" in
         ./*|/*)
            if [ -f "${1}" ]; then
               TARGET="${1}"
            elif [ -f "${1}.conf" ]; then
               TARGET="${1}.conf"
            else
               die "target file '${1}' does not exist."
            fi
         ;;
         *)
            TARGET="${CONFDIR}/${1}.conf"
            [ -f "${TARGET}" ] || die "no such target: '${1}' (${TARGET}?)"
         ;;
      esac
   else
      die "cannot build more than one target!"
   fi
}

# void kcomp_main_run_configure()
#
kcomp_main_run_configure() {
   einfo_action "Running configure"

   if [ -n "${CMDLINE_CONFIG_TARGET-}" ]; then
      CONFIG_TARGET="${CMDLINE_CONFIG_TARGET}"
      # FIXME move ^this to main()
   fi

   case "${CONFIG_TARGET:?}" in
      'oldconfig')
         einfo "-> via oldconfig"
         autodie kcomp_configure
         if __interactive__; then
            # set CONFIG_TARGET for retry to nconfig
            CONFIG_TARGET=nconfig
         fi
      ;;
      'nconfig'|'menuconfig'|'gconfig'|'xconfig')
         need_stdin
         INTERACTIVE=y
         einfo "-> interactive"
         kcomp_configure_interactive || ewarn "configure returned ${?}"

         while get_yn "Run ${CONFIG_TARGET} again?"; do
            kcomp_configure_interactive || ewarn "configure returned ${?}"
         done

         if [ "${1:-n}" = "y" ] || get_yn "Continue with 'compile'?"; then
            true
         elif \
            [ "${I_KNOW_WHAT_I_AM_DOING:-n}" = "y" ] || \
            get_yn "ARE YOU SURE?"
         then
            exit 2
         fi
      ;;
      *)
         __panic__
      ;;
   esac
}

# int kcomp_main_run_compile_interactive()
#
kcomp_main_run_compile_interactive() {
   einfo "Compiling ... "
   if kcomp_build; then
      return 0
   else
#      local try_count=0
      while get_yn "Configure and retry?"; do
         kcomp_main_run_configure y
         einfo_action "Compiling"
         if kcomp_build; then
            return 0
#         else
#            try_count=$(( ${try_count} + 1 ))
         fi
      done
      die "kernel compilation failed!"
   fi
}

# int kcomp_main_run_makepatch_shell()
#
kcomp_main_run_makepatch_shell() {
   local KVER rc=0
   kcomp_get_kver
   varcheck KSRC KBUILD KVER
   (
      export KVER KSRC KBUILD

      einfo "Starting makepatch shell"
      einfo
      einfo "you may reference the following variables:"
      einfo
      F_PRINTVAR=einfo printvar KVER KSRC KBUILD
      einfo
      einfo "Note that a non-zero shell return value will abort kernel compilation."

      if [ -n "${BASH_VERSION-}" ]; then
         abort() { exit 9; }
         export -f abort
         einfo "You can do so by calling abort() (unless your shell overrides this function)."
         einfo
      else
         einfo
      fi

      bash
   ) || rc=${?}
   if [ ${rc} -eq 0 ]; then
      return 0
   else
      ewarn "makepatch shell returned ${rc}, this will cause kernel compilation to abort."
      return ${rc}
   fi
}

# int kcomp_patchset_run ( build_dir, *cmdv )
#
#  Runs cmdv in build_dir. Expects source_dir == build_dir.
#
#  Note: automatically sets BUILDENV_ONESHOT=y and BUILDENV_UNSET_VARS=""
#
kcomp_patchset_run() {
   local S="${1:?}"
   shift && \
      BUILDENV_ONESHOT=y \
      BUILDENV_UNSET_VARS="" \
      buildenv_prepare_do "${S}" "${S}" buildenv_run_in_work "$@"
}

# int kcomp_patchset_zfs_configure ( *extra_argv, **KSRC, **KBUILD )
#
#  Runs configure in a spl or zfs build directory.
#
kcomp_patchset_zfs_configure() {
   buildenv_printrun ./configure \
      --with-config=all \
      --with-linux="${KSRC}" \
      --with-linux-obj="${KBUILD}" \
      --enable-linux-builtin "$@"
}

# void kcomp_get_source ( src, work )
#
#  Creates a work instance of src,
#  where src can be a directory or a tarball.
#
#  FIXME: rename/move, this is _not_ a kcomp function.
#
kcomp_get_source() {
   if [ -f "${1:?}" ]; then
      autodie dodir_clean "${2:?}"
      autodie buildenv_printrun tar xaf "${1}" -C "${2}" --strip-components 1
   elif [ -d "${1}" ]; then
      autodie cp -aTL -- "${1}" "${2}"
   else
      case "${1}" in
         git://*)
            autodie git clone --depth 1 "${1}" "${2}"
         ;;
         *)
            die "cannot locate source '${1}'"
         ;;
      esac
   fi
   __double_tap__ autodie test -d "${2}"
}

# void kcomp_make_extra_modules()
#
kcomp_make_extra_modules() {
   # kernel has already been built, be extra careful and avoid make clean etc.
   local S KVER KERNEL_VERSION KERNEL_RELEASE NEED_DEPMOD=n
   autodie kcomp_get_version
   varcheck ADDON_DIR KVER KBUILD KSRC KERNEL_DESTDIR

   local D="${KERNEL_DESTDIR}/"
   local MODULE_DIR="${D}/lib/modules/${KERNEL_RELEASE}"

   if use acpi_call; then
      einfo_build_modules "acpi_call"

      varcheck ACPI_CALL_SRC

      S="${ADDON_DIR}/acpi_call"
      kcomp_get_source "${ACPI_CALL_SRC}" "${S}"
      autodie rm -rf "${S}/.git"

      # F_MAKEOPTS_APPEND !!
      # note regarding '-j1': we're building exactly one module file here
      autodie kcomp_make_external "${S}" \
         KVERSION="${KVER}" KDIR="${KBUILD}" \
         -j1 default install

      autodie rm -r "${S}"

      einfo_new_modules "acpi_call"
      NEED_DEPMOD=y # really?
   fi

   if use virtualbox; then
      # FIXME: move this to main()
      : ${VIRTUALBOX_MODULES:=vboxdrv vboxnetflt vboxnetadp vboxpci}

      einfo_build_modules "${VIRTUALBOX_MODULES}"
      ewarn "a kernel with these modules loaded will be TAINTED"
      ewarn "Also check the license for virtualbox modules"

      varcheck VIRTUALBOX_MOD_SRC

      S="${ADDON_DIR}/vbox_mod"
      kcomp_get_source "${VIRTUALBOX_MOD_SRC}" "${S}"
      autodie rm -rf "${S}/.git"

      autodie kcomp_make_external "${S}" \
         KERN_DIR="${KSRC}" KERN_OUT="${KBUILD}" all

      autodie dodir_clean "${MODULE_DIR}/misc"
      local mod
      for mod in ${VIRTUALBOX_MODULES}; do
         autodie install -m 0664 "${S}/${mod}.ko" "${MODULE_DIR}/misc/${mod}.ko"
      done

      autodie rm -r -- "${S}"

      einfo_new_modules "${VIRTUALBOX_MODULES}"
      NEED_DEPMOD=y
   fi

   if [ "${NEED_DEPMOD:-n}" = "y" ]; then
      einfo_action "Running depmod"
      autodie kcomp_run_depmod
   fi
}

# void kcomp_apply_patchsets()
#
#  This function introduces some overhead when calling with no patch set
#  active.
#
kcomp_apply_patchsets() {
   einfo_action "Preparing the kernel"
   local HAVE_MODULES_BUILT=n

   varcheck ADDON_DIR KSRC KBUILD KERNEL_TMPDIR
   autodie dodir_clean "${ADDON_DIR}"

   # Expecting a clean tree
   #autodie kcomp_make_clean

   # kcomp_configure (possibly) destroys the user's config, thus
   # kcomp_reinit() will run at the end of this function
   autodie kcomp_configure
   autodie kcomp_make modules_prepare

   use_call tp_smapi autodie kcomp_patchset_tp_smapi
   use_call zfs      autodie kcomp_patchset_zfs

   # restore config
   autodie kcomp_reinit "${KERNEL_DEFAULT_CONFIG}"
}

# void kcomp_patchset_zfs()
#
#  Adds ZFS on Linux support to this kernel.
#
#  !!! Beware of legal implications.
#
kcomp_patchset_zfs() {
   einfo_action "Applying patch set: spl + zfs on linux"
   varcheck ZFS_SRC SPL_SRC \
      ADDON_DIR KSRC KBUILD KERNEL_TMPDIR

   local ZFS_BUILD="${ADDON_DIR}/build/zfs" SPL_BUILD="${ADDON_DIR}/build/spl"

   autodie dodir_clean "${SPL_BUILD}" "${ZFS_BUILD}"

   einfo_action "Unpacking zfs/spl source"

   kcomp_get_source "${SPL_SRC}" "${SPL_BUILD}"
   kcomp_get_source "${ZFS_SRC}" "${ZFS_BUILD}"

   autodie kcomp_configure
   # Module.symvers is required and can only be generated by make modules
   if \
      [ "${HAVE_MODULES_BUILT:-n}" != "y" ] && kcomp_kernel_with_modules
   then
      autodie kcomp_make modules
      HAVE_MODULES_BUILT=y
   fi

   einfo_action "Running configure for spl"

   autodie kcomp_patchset_run "${SPL_BUILD}" \
      kcomp_patchset_zfs_configure


   einfo_action "Running configure for zfs"

   autodie kcomp_patchset_run "${ZFS_BUILD}" \
      kcomp_patchset_zfs_configure --with-spl="${SPL_BUILD}"

   einfo_action "Copying spl and zfs into the kernel source dir"

   autodie kcomp_patchset_run "${SPL_BUILD}" ./copy-builtin "${KSRC}"
   autodie kcomp_patchset_run "${ZFS_BUILD}" ./copy-builtin "${KSRC}"

   einfo_action "Cleaning up"

   autodie rm -r "${SPL_BUILD}" "${ZFS_BUILD}"
   autodie kcomp_make_clean

   einfo "Kernel supports ZFS now ;) ZFS needs userloand support, too!"
   einfo "Don't forget to enable CONFIG_SPL and CONFIG_ZFS"

   ewarn 'BIG FAT WARNING' '!!!'
   ewarn "" '!!!'
   ewarn 'Keep in mind that you redistributing this kernel or its sources may lead to legal problems' '!!!'
   ewarn "" '!!!'
   [ "${I_KNOW_WHAT_I_AM_DOING:-n}" = "y" ] || sleep 1
}

# void kcomp_patchset_tp_smapi()
#
kcomp_patchset_tp_smapi() {
   local KVER
   autodie kcomp_get_kver

   varcheck KSRC KBUILD ADDON_DIR TP_SMAPI_SRC KVER
   local S="${ADDON_DIR}/tp_smapi"

   kcomp_get_source "${TP_SMAPI_SRC}" "${S}"
   autodie rm -rf "${S}/.git"

   #autodie dodir_clean "${S}"
   local PATCH="${S}/${KVER}.patch"

   einfo_action "Creating tp-smapi patch"

   autodie kcomp_configure

   autodie kcomp_patchset_run "${S}" \
      make -j1 \
         KVER="${KVER}" \
         KSRC="${KSRC}" \
         KBUILD="${KBUILD}" \
         PATCH="${PATCH##*/}" \
         patch

   __double_tap__ autodie test -f "${PATCH}"

   autodie kcomp_patch "${PATCH}"

   autodie dodir "${KERNEL_WORKDIR}/patch"
   autodie mv -T -- "${PATCH}" "${KERNEL_WORKDIR}/patch/tp_smapi-${KVER}.patch"
   autodie rm -r -- "${S}"
}

# parse args


# void argparse_any(), raises argparse_unknown() -- catch unhandled args
#
argparse_any() { argparse_unknown "$@"; }

# void argparse_arg(), raises die()
#
argparse_arg() {
   kcomp_main_set_target "${arg}"
}

# void argparse_longopt(), raises die()
#
argparse_longopt() {
   case "${longopt}" in
      'update')
         argparse_need_arg "$@"
         case "${1}" in
            [0-9]*)
               CHECK_UPDATE="${1}"
            ;;
            *)
               die "--update '${1}': bad value"
            ;;
         esac
      ;;
      'interactive')
         INTERACTIVE=y
         need_stdin
      ;;
      'force')
         FORCE=y
      ;;
      'makepatch')
         MAKEPATCH_SHELL=y
         need_stdin
      ;;
      'nconfig')
         CMDLINE_CONFIG_TARGET=nconfig
      ;;
      'oldconfig')
         CMDLINE_CONFIG_TARGET=oldconfig
      ;;
#      'dist')
#         argparse_need_arg
#         CMDLINE_KERNEL_DISTFILE="${1}"
#      ;;
      'with-'*)
         CMDLINE_USE="${CMDLINE_USE-} ${longopt#with-}"
      ;;
      'without-'*)
         CMDLINE_USE="${CMDLINE_USE-} -${longopt#without-}"
      ;;
      *)
         argparse_unknown
      ;;
   esac
}
argparse_shortopt() {
   case "${shortopt}" in
      'f')
         FORCE=y
      ;;
      'I')
         INTERACTIVE=y
         need_stdin
      ;;
      'm')
         need_stdin
         MAKEPATCH_SHELL=y
      ;;
      *)
         argparse_unknown
      ;;
   esac
}

setup_debug() {
   if __debug__; then
      BREAKPOINTS_ALL=y
      [ -z "${BASH_VERSION-}" ] || PRINT_FUNCTRACE=y
   fi
   return 0
}

# int kcomp_main ( *argv ), raises die()
#
#  Leaks vars! <- needs to be fixed when calling this function more than
#                 once per run
#
kcomp_main() {
   setup_debug

   if [ "${KCOMP_KEEP_LANG:-n}" != "y" ]; then
      LANG=C
      LC_ALL=C
      export LANG LC_ALL
   fi

   local TARGET= CHECK_UPDATE=

   if [ -n "$*" ]; then
      argparse_autodetect
      argparse_parse "$@"
      setup_debug
   fi

   if [ -z "${TARGET}" ]; then
      kcomp_main_set_target "default"
   fi

   readonly TARGET
   readonly CHECK_UPDATE

   einfo_action "Running pre-build checks and setup"

   [ -z "${CHECK_UPDATE}" ] || __panic__

   # read config
   . "${TARGET}" -- || die "failed to read config file '${TARGET}'"
   setup_debug

   breakpoint setup

   ##__verbose__ || BUILDENV_PATCH_OPTS="${BUILDENV_PATCH_OPTS-}${BUILDENV_PATCH_OPTS:+ }--quiet"

   # verify config and set up variables
   kcomp_edit_use ${USE-} ${CMDLINE_USE-}

   if use vbox; then
      die "vbox USE flag does no longer exist."
   fi

   varcheck KERNEL_SRC KERNEL_SRC_TYPE KERNEL_DESTFILE

   if [ -e "${KERNEL_DESTFILE}" ]; then
      if [ ! -f "${KERNEL_DESTFILE}" ]; then
         die "kernel destfile '${KERNEL_DESTFILE}' exists, but is not a file."
      else
         this_needs_force \
            "kernel destfile '${KERNEL_DESTFILE} exists" \
            " and will be overwritten later on (--force)" \
            ", use --force."
      fi
   fi

   # check KERNEL_SRC_TYPE
   case "${KERNEL_SRC_TYPE}" in
      'default'|'dir'|'directory')
         KERNEL_SRC_TYPE=default
         [ -d "${KERNEL_SRC}/" ] || \
            die "kernel source directory '${KERNEL_SRC}' does not exist."
      ;;
      'git')
         #KERNEL_SRC_TYPE=git
         varcheck_allow_empty KERNEL_GIT_REF
         [ -d "${KERNEL_SRC}/" ] || \
            die "kernel source directory '${KERNEL_SRC}' does not exist."
      ;;
      'tar'|'tarball')
         KERNEL_SRC_TYPE=tarball
         [ -f "${KERNEL_SRC}" ] || \
            die "kernel source tarball '${KERNEL_SRC}' does not exist."
      ;;
      *)
         die "unknown kernel source type '${KERNEL_SRC_TYPE}'!"
      ;;
   esac

   if [ -z "${KERNEL_WORKDIR-}" ]; then
      autodie get_tmpdir "kcomp"
      KERNEL_WORKDIR="${T}"
   else
      autodie dodir_clean "${KERNEL_WORKDIR}"
   fi

   : ${KERNEL_BUILD:="${KERNEL_WORKDIR}/build"}
   : ${KERNEL_DESTDIR:="${KERNEL_WORKDIR}/image"}
   KERNEL_TMPDIR="${KERNEL_WORKDIR}/tmp"
   ADDON_DIR="${KERNEL_WORKDIR}/addon"
   autodie dodir_clean "${KERNEL_BUILD}" "${KERNEL_DESTDIR}" "${KERNEL_TMPDIR}"

   readonly KERNEL_SRC KERNEL_SRC_TYPE KERNEL_WORKDIR KERNEL_BUILD
   readonly KERNEL_DESTDIR KERNEL_TMPDIR KERNEL_DESTFILE ADDON_DIR
   : ${KERNEL_OVERWRITE_CONFIG:=n}
   : ${KERNEL_DEFAULT_CONFIG=/proc/config.gz}

   : ${CONFIG_TARGET:=nconfig}

   # --- have config now ---

   # prepare kernel

   einfo_action "Preparing the kernel"
   breakpoint kernel_setup

   F_PRINTVAR=einfo printvar \
      KERNEL_SRC KERNEL_SRC_TYPE \
      KERNEL_WORKDIR KERNEL_BUILD KERNEL_DESTDIR KERNEL_DESTFILE \
      KERNEL_DEFAULT_CONFIG KERNEL_OVERWRITE_CONFIG

   F_PRINTVAR=einfo PRINTVAR_SKIP_EMPTY=y printvar \
      ARCH CROSS_COMPILE \
      KERNEL_LOCAL_BUILD \
      KERNEL_BASENAME KERNEL_INSTALL_TARGETS \
      KERNEL_TARGET KERNEL_REAL_TARGET \
      KERNEL_APPEND_DTB \
      BUILDENV_PATCH_OPTS


   # init:
   case "${KERNEL_SRC_TYPE}" in
      'default'|'tarball')
         autodie kcomp_init_${KERNEL_SRC_TYPE} \
            "${KERNEL_SRC}" "${KERNEL_BUILD}" \
            "${KERNEL_DEFAULT_CONFIG}" "${KERNEL_OVERWRITE_CONFIG}"
      ;;
      'git')
         autodie kcomp_init_git \
            "${KERNEL_SRC}" "${KERNEL_GIT_REF-}" "${KERNEL_BUILD}" \
            "${KERNEL_DEFAULT_CONFIG}" "${KERNEL_OVERWRITE_CONFIG}"
      ;;
      *)
         __panic__
      ;;
   esac

   # ARCH could have been set by kcomp_init_*()
   F_PRINTVAR=einfo printvar ARCH

   einfo_action "Cleaning up"

   autodie kcomp_make_clean

   # patch:
   breakpoint kernel_patch

   if [ -n "${KERNEL_PATCHES-}" ]; then

      einfo "-> Applying patches"
      F_ITER=kcomp_patch \
      ITER_UNPACK_ITEM=n \
      line_iterator "${KERNEL_PATCHES-}" || die "Failed to apply patches!"
   else
      einfo "No patches configured."
   fi

   autodie kcomp_apply_patchsets

   # makepatch shell?
   if [ "${MAKEPATCH_SHELL:-n}" = "y" ]; then
      autodie kcomp_main_run_makepatch_shell
   fi

   # configure:
   breakpoint kernel_configure
   kcomp_main_run_configure

   # catch CONFIG_MODVERSIONS
   if kcomp_kernel_with_modversions; then
      ewarn \
         "Kernel has CONFIG_MODVERSIONS enabled. This is known to fail ('module exec format error', ...)." \
         "CONFIG_WARN"

      if __interactive__; then
         if get_yn "Run config again?"; then
            kcomp_main_run_configure
            if kcomp_kernel_with_modversions; then
               ewarn "CONFIG_MODVERSIONS is still enabled." "CONFIG_WARN"
            fi
         fi
      else
         this_needs_force "CONFIG_MODVERSIONS is enabled."
      fi
   fi

   # compile:
   breakpoint kernel_compile
   if __interactive__; then
      autodie kcomp_main_run_compile_interactive
   else
      einfo_action "Compiling"
      autodie kcomp_build
   fi

   # install:
   breakpoint kernel_install
   einfo_action "Installing into ${KERNEL_DESTDIR}"
   autodie kcomp_install "${KERNEL_DESTDIR}"

   # compile/install extra modules
   breakpoint kernel_addons
   autodie kcomp_make_extra_modules

   # pack:
   breakpoint kernel_pack
   einfo_action "Creating tarball"
   autodie kcomp_pack "${KERNEL_DESTDIR}" "${KERNEL_TMPDIR}/${KERNEL_DESTFILE##*/}"
   autodie mv -T -f -- "${KERNEL_TMPDIR}/${KERNEL_DESTFILE##*/}" "${KERNEL_DESTFILE}"

   einfo "${KERNEL_DESTFILE} is ready."
   breakpoint kernel_done
   # END;
}


# @implicit int main ( *argv )
#
kcomp_main "$@"
