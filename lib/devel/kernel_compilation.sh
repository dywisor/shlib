# HIGHLY EXPERIMENTAL
# - standard (non-cross) kernel compilation seems to work ok so far
# -- tested with kcomp_init_default()
#
#
# ----------------------------------------------------------------------------
#
# Configuration variables used by kcomp:
#
#  for kernel compilation:
#  * KERNEL_TARGET (defaults to bzImage)
#  * KERNEL_REAL_TARGET (optional)
#  * KERNEL_APPEND_DTB (optional)
#  * ARCH (defaults to $(arch))
#  * CROSS_COMPILE (optional)
#
#  for kernel installation
#  * KERNEL_BASENAME (optional, defaults to linux)
#  * KERNEL_INSTALL_TARGETS (optional)
#  * KCOMP_LOCAL_BUILD (defaults to y if CROSS_COMPILE is not set, else n)
#
#
# Compiling and installing a kernel with the aid of this module usually
# comes down to:
#
# A: Call (exactly) one of the kcomp_init functions (mandatory)
#
# * kcomp_init_default when building against a source directory
# * kcomp_init_tarball when building against a source tarball
# * kcomp_init_git when building against a specific version (commit/tag/ref)
#   of a clean, already up-to-date git tree
#
# B: Prepare the build dir further (optional)
#
#  * configure the kernel with kcomp_configure{,_interactive}()
#  * patch the kernel source dir with kcomp_patch()
#
# C: Build the kernel with kcomp_build() (optional)
#
# D: Install the kernel somewhere with kcomp_install() (optional)
#
# * needs a compiled kernel (obviously)
# * the dest dir can also be a temporary directory
#
# E: Create a tarball of the installed kernel with kcomp_pack() (optional)
#
# * needs an installed kernel
# * this will automatically make all packed files root-owned
#
#
# This module provides core functionality only. Updating a git tree,
# creating temporary dirs etc. has to be done by other modules or your script.
#
# ----------------------------------------------------------------------------

# @extern void buildenv_prepare()   -- workdir, srcdir
# @extern int buildenv_make()       -- *argv
# @extern int buildenv_run()        -- *cmdv
# @extern int buildenv_patch_src()  -- [patch_opts], *patch_file
# @extern int buildenv_patch_work() -- [patch_opts], *patch_file
# @extern int buildenv_prepare_do() -- workdir, srcdir, cmd, *argv
# @extern int buildenv_printrun()   -- *cmdv

# int kcomp_prepare_build_dir (
#   kernel_build_dir=<kernel_src_dir>,
#   initial_config="/proc/config.gz",
#   overwrite_config="n"
# )
#
#  Creates the kernel build dir and an initial config file, either imported
#  or generated via make defconfig.
#
kcomp_prepare_build_dir() {
   local kbuild="${1:-${__KCOMP_KSRC:?}}" initial_config="${2-/proc/config.gz}"

   if dodir "${kbuild}" && touch "${kbuild}"; then
      __KCOMP_KBUILD=`readlink -f "${kbuild}"`
      __KCOMP_CONFIG="${__KCOMP_KBUILD}/.config"

      if [ -n "${initial_config}" ]; then
         [ "${initial_config}" != "@default" ] || initial_config="/proc/config.gz"

         if [ ! -e "${__KCOMP_CONFIG}" ] || [ "${3:-n}" = "y" ]; then
            if compress_supports "${initial_config}"; then
               dolog_info -0 "Importing config file ${initial_config} (compressed file)"
               do_uncompress "${initial_config}" > "${__KCOMP_CONFIG}" || __KCOMP_CONFIG=
            else
               dolog_info -0 "Importing config file ${initial_config}"
               cp -T -L -- "${initial_config}" "${__KCOMP_CONFIG}" || __KCOMP_CONFIG=
            fi
         fi
      elif [ ! -e "${__KCOMP_CONFIG}" ]; then
         dolog_info -0 "Creating default config"
         buildenv_make -j1 defconfig || __KCOMP_CONFIG=
      fi

      if [ -z "${__KCOMP_CONFIG}" ]; then
         dolog_error -0 "Could not create initial config"
         unset -v __KCOMP_CONFIG
         return 3
      fi
   else
      dolog_error -0 "Cannot create build directory ${kbuild}"
      return 2
   fi
}

# int kcomp_init_default (
#    kernel_src_dir, kernel_build_dir,
#    initial_config, overwrite_config,
#    **ARCH!, **KERNEL_TARGET="bzImage"!,
#    **BUILDENV_UNSET_VARS!
# )
#
#  Initializes kcomp for building a kernel from a src directory.
#
kcomp_init_default() {
   BUILDENV_UNSET_VARS="KSRC KBUILD"

   __KCOMP_KSRC=`readlink -f "${1:?}"`
   : ${KERNEL_TARGET:=bzImage}
   [ -n "${ARCH-}" ] || ARCH=`arch`

   if shift && kcomp_prepare_build_dir "$@"; then
      KSRC="${__KCOMP_KSRC}"
      KBUILD="${__KCOMP_KBUILD}"
      return 0
   else
      return ${?}
   fi
}

# int kcomp_init_tarball (
#    tarball_file, kernel_dir, initial_config, overwrite_config, **ARCH!
# )
#
#  Unpacks tarball_file into kernel_src_dir and calls kcomp_init_default().
#
kcomp_init_tarball() {
   : ${1:?} ${2:?}

   dolog_info -0 "Unpacking kernel tarball ${1} into ${2}"

   dodir_clean "${2}" && \
   buildenv_printrun tar xaf "${1}" -C "${2}" --strip-components 1 && \
   shift && kcomp_init_default "${1}" "$@"
}

# int kcomp_init_git (
#    kernel_src_dir, git_ref,
#    kernel_build_dir,
#    initial_config, overwrite_config,
#    **ARCH!
# )
#
#  Checks out git ref in kernel_src_dir and calls kcomp_init_default().
#
kcomp_init_git() {
   local K="${1:?}"

   [ -z "${2?}" ] || \
      BUILDENV_SRCDIR="${K}" buildenv_run_in_src git checkout "${2}" || return

   shift 2 && kcomp_init_default "${K}" "$@"
}

# int kcomp_patch ( [patch_opts], *patch_file )
#
#  Applies a series of patches to the kernel source directory.
#
kcomp_patch() {
   kcomp__prepare_do buildenv_patch_src "$@"
}

# int kcomp_configure_interactive ( **CONFIG_TARGET=nconfig )
#
#  Lets the user configure the kernel interactively.
#
kcomp_configure_interactive() {
   kcomp__make ${CONFIG_TARGET:-nconfig}
}

# int kcomp_configure()
#
#  Configures the kernel via make oldconfig.
#
kcomp_configure() {
   yes '' | kcomp__make -j1 oldconfig
}

# int kcomp_set_localname ( new_name )
#
#  Sets the kernel's name.
#
kcomp_set_localname() {
   sed \
      -e "s,^CONFIG_LOCALVERSION=.*,CONFIG_LOCALVERSION=\"-${1#-}\"," \
      -i "${__KCOMP_KBUILD}/.config"
}

# int kcomp_make_clean()
#
#  Runs "make clean" in the kernel's build directory.
#
kcomp_make_clean() {
   kcomp__make -j1 clean
}

# void kcomp_get_version ( **KVER!, **KERNEL_RELEASE!, **KERNEL_VERSION! )
#
#  Sets some version-related variables.
#
kcomp_get_version() {
   KVER=
   KERNEL_RELEASE=`kcomp__make kernelrelease 2>/dev/null`
   KERNEL_VERSION=`kcomp__make kernelversion 2>/dev/null`
   [ -z "${KERNEL_RELEASE}" ] || \
      [ -z "${KERNEL_VERSION}" ] || KVER="${KERNEL_RELEASE%+}"
}

# int kcomp_build (
#    **KERNEL_TARGET, **KERNEL_REAL_TARGET, **KERNEL_APPEND_DTB,
#    **ARCH, **CROSS_COMPILE
# )
#
#  Builds the kernel and its modules.
#
#  Note:
#
#     This function offers extended cross compilation features.
#
#     For example, Dreamplug users with an old version of u-boot may want
#     to append the device tree binary to the kernel image and can do so
#     by passing
#
#     * KERNEL_TARGET=zImage
#     * KERNEL_TARGET=uImage
#     * KERNEL_APPEND_DTB=arch/arm/boot/kirkwood-dreamplug.dtb
#
#     plus the usual ARCH / CROSS_COMPILE variables.
#
kcomp_build() {
   local BUILDENV_WORKDIR BUILDENV_SRCDIR

   buildenv_prepare "${__KCOMP_KBUILD:?}" "${__KCOMP_KSRC:?}" || return

   dolog_info -0 "Creating kernel image ${KERNEL_TARGET}"
   if buildenv_make ${KERNEL_TARGET}; then

      __KCOMP_KERNEL_IMAGE="${__KCOMP_KBUILD}/arch/${ARCH:?}/boot/${KERNEL_TARGET}"

      if [ ! -e "${__KCOMP_KERNEL_IMAGE}" ]; then
         dolog_warn -0 "${__KCOMP_KERNEL_IMAGE} is missing."

      elif [ -n "${KERNEL_APPEND_DTB-}" ]; then
         if \
            buildenv_make "${KERNEL_APPEND_DTB##*/}" && \
            cat "${__KCOMP_KBUILD}/${KERNEL_APPEND_DTB#./}" >> "${__KCOMP_KERNEL_IMAGE}"
         then
            true
         else
            dolog_error -0 "Failed to append device tree binary"
            return 5
         fi
      fi

      if [ -n "${KERNEL_REAL_TARGET-}" ]; then
         if buildenv_make ${KERNEL_REAL_TARGET}; then
            __KCOMP_KERNEL_IMAGE="${__KCOMP_KBUILD}/arch/${ARCH:?}/boot/${KERNEL_REAL_TARGET}"

            [ -e "${__KCOMP_KERNEL_IMAGE}" ] || \
               dolog_warn -0 "${__KCOMP_KERNEL_IMAGE} is missing."
         else
            dolog_error -0 "Failed to build kernel target '${KERNEL_REAL_TARGET}'."
            unset -v __KCOMP_KERNEL_IMAGE
            return 10
         fi
      fi

      if kcomp__kernel_with_modules; then
         dolog_info -0 "Building modules"
         if buildenv_make modules; then
            dolog_info -0 "Built a modular kernel"
         else
            dolog_error -0 "Failed to build the modules"
            return 2
         fi
      else
         dolog_info -0 "Built a static kernel (without modules)"
      fi

      return 0
   else
      dolog_error -0 "make ${KERNEL_TARGET} returned $?"
      return 1
   fi
}

# int kcomp_install ( destdir )
#
#  Installs the kernel and its modules into destdir.
#
kcomp_install() {
   local __BUILDENV_SUBSHELL=n
   kcomp__prepare_do buildenv_run kcomp__do_install "$@"
}

# int kcomp_pack ( destdir, file, compression_format=<detect> )
#
#  Creates a tarball %file with the contents of %destdir.
#  Meant for usage with kcomp_install().
#
kcomp_pack() {
   local __BUILDENV_SUBSHELL=n
   local destdir="${1:?}" tarfile="${2:?}" v0 compress_arg

   [ -z "${3-A}" ] || compress_detect_taropt "${3:-${tarfile}}"
   compress_arg="${v0?}"

   (
      cd "${destdir}" && \
      buildenv_printrun \
         tar c ./ -f "${tarfile}" ${compress_arg-} \
            --owner=root --group=root --one-file-system
   )
}

# @private int kcomp__do_install (
#    destdir,
#    **KERNEL_BASENAME, **KERNEL_TARGET,
#    **KERNEL_INSTALL_TARGETS,
#    **KCOMP_LOCAL_BUILD,
#    **ARCH, **CROSS_COMPILE,
#    **SUDOFY_USER=<USER>
# ), raises exit()
#
#  Actually installs the kernel.
#
#  !!! Never run this function directly.
#      It expects to be called in a subshell.
#
kcomp__do_install() {
   [ "${__BUILDENV_SUBSHELL:-n}" = "y" ] || \
      function_die "expecting subshell" "kcomp__do_install()"
   # this function is always run in a subshell
   set -e

   : ${KERNEL_TARGET:?} ${KERNEL_BASENAME:=linux} ${SUDOFY_USER:=${USER?}}
   SUDOFY_ONLY_OTHERS=n

   D="${1:?}/"

   [ -z "${ARCH-}"          ] || export ARCH
   [ -z "${CROSS_COMPILE-}" ] || export CROSS_COMPILE

   dodir_clean "${D}"

   export INSTALL_MOD_PATH="${D}"
   export INSTALL_FW_PATH="${D}lib/firmware"
   export INSTALL_HDR_PATH="${D}usr"

   export INSTALL_KERNEL_PATH="${D}boot"

   KERNEL_RELEASE=`make kernelrelease 2>/dev/null`
   KVER="${KERNEL_RELEASE%+}"
   : ${KVER:?}

   dolog_info -0 "Install ${KERNEL_BASENAME}-${KVER} config-${KVER} into ${D} ... "
   # dodir() does not support sudofy

   if [ -z "${__KCOMP_KERNEL_IMAGE-}" ]; then
      __KCOMP_KERNEL_IMAGE="${__KCOMP_KBUILD}/arch/${ARCH:?}/boot/${KERNEL_TARGET}"
   fi



   dodir "${INSTALL_KERNEL_PATH}"
   sudofy cp -vL -- "${__KCOMP_KERNEL_IMAGE}" "${INSTALL_KERNEL_PATH}/${KERNEL_BASENAME}-${KVER}"
   sudofy cp -vL -- "${__KCOMP_CONFIG}"       "${INSTALL_KERNEL_PATH}/config-${KVER}"

   if kcomp__kernel_with_modules; then
      dolog_info -0 "Installing modules into ${INSTALL_MOD_PATH} ... "
      sudofy make -j1 modules_install

      if \
         [ "${KCOMP_LOCAL_BUILD:-y}" != "y" ] || \
         {
            [ -n "${CROSS_COMPILE-}" ] && [ -z "${KCOMP_LOCAL_BUILD-}" ]
         }
      then
         dolog_info -0 "Removing source/build symlinks in ${INSTALL_MOD_PATH} ... "
         for symlink in \
            "${INSTALL_MOD_PATH}/lib/modules/${KERNEL_RELEASE}/"{source,build}
         do
            if [ -h "${symlink}" ]; then
               sudofy rm "${symlink}"
            fi
         done
      fi
   else
      dolog_info -0 "static kernel detected (CONFIG_MODULES=n)"
   fi

   for target in ${KERNEL_INSTALL_TARGETS-}; do
      case "${target}" in
         "${KERNEL_TARGET}"|"${KERNEL_REAL_TARGET}"|'modules')
            true
         ;;
         *)
            sudofy make -j1 "${target}"
         ;;
      esac
   done

   set +e
}

# int kcomp__prepare_do ( *cmdv )
#
#  Runs cmdv in kcomp's build environment.
#
kcomp__prepare_do() {
   BUILDENV_ONESHOT=y buildenv_prepare_do \
      "${__KCOMP_KBUILD:?}" "${__KCOMP_KSRC:?}" "$@"
}

# int kcomp__make ( *argv )
#
#  Runs make *argv in kcomp's build environment.
#
kcomp__make() {
   kcomp__prepare_do buildenv_make "$@"
}

# @private int kcomp__kernel_with_modules ( **__KCOMP_CONFIG )
#
#  Checks whether the configured kernel uses modules or not.
#
kcomp__kernel_with_modules() {
   if \
      grep -q -x -- CONFIG_MODULES=[ym] "${__KCOMP_CONFIG:?}"
   then
      return 0
   elif \
      grep -q -x -- '# CONFIG_MODULES is not set' "${__KCOMP_CONFIG:?}"
   then
      return 1
   else
      dolog_warn -0 "Cannot detect value of CONFIG_MODULES"
      return 2
   fi
}
