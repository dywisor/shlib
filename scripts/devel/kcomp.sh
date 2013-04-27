#EXPERIMENTAL
#
# This script relies on a config file that defines how a target should be built
#

readonly CONFDIR=/etc/shlib/kcomp

TARGET=
CHECK_UPDATE=

# void __panic__, raises die()
#
#  Sometimes I'm just too lazy to write error messages.
#  Needs to be fixed, though.
#
__panic__() { die "${1:-DIE BESTEN DER BESTEN DER BESTEN, SIR!}" "${2-}"; }

need_stdin() { tty -s || __panic__; }


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
   einfo "Running configure ... "
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

         [ "${1:-n}" = "y" ] || get_yn "Continue with 'compile'?" || exit 2
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
         einfo "Compiling ... "
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

# parse args

HELP_DESCRIPTION="linux kernel compilation"

HELP_BODY="Prepares, configures, patches and compiles a kernel. The result
is a tarball that can be merged with the target's rootfs.
"

HELP_OPTIONS="
--update <KVER>     -- do not compile/install if version is <= KVER
--force        (-f) -- create tarball file even if it already exists
--interactive  (-I) -- enable yes/no questions (allows to recover from failure)
--makepatch    (-m) -- start a shell for creating patches after cleaning up
"

HELP_USAGE="Usage: ${SCRIPT_FILENAME} <target> [<tarball>]"



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

if [ -n "$*" ]; then
   argparse_autodetect
   argparse_parse "$@"
fi

if [ -z "${TARGET}" ]; then
   kcomp_main_set_target "default"
fi

readonly TARGET
readonly CHECK_UPDATE

einfo "Running pre-build checks and setup ... "

[ -z "${CHECK_UPDATE}" ] || __panic__

. "${TARGET}" -- || die "failed to read config file '${TARGET}'"

varcheck KERNEL_SRC KERNEL_SRC_TYPE KERNEL_DESTFILE

if [ -e "${KERNEL_DESTFILE}" ]; then
   if [ ! -f "${KERNEL_DESTFILE}" ]; then
      die "kernel destfile '${KERNEL_DESTFILE}' exists, but is not a file."
   elif [ "${FORCE:-n}" != "y" ]; then
      die "kernel destfile '${KERNEL_DESTFILE}' exists, use --force."
   else
      ewarn "kernel destfile '${KERNEL_DESTFILE}' exists and will be overwritten later on (--force)."
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
      VARCHECK_ALLOW_EMPTY=y varcheck KERNEL_GIT_REF
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
autodie dodir_clean "${KERNEL_BUILD}" "${KERNEL_DESTDIR}" "${KERNEL_TMPDIR}"

readonly KERNEL_SRC KERNEL_SRC_TYPE KERNEL_WORKDIR KERNEL_BUILD KERNEL_DESTDIR KERNEL_TMPDIR KERNEL_DESTFILE
: ${KERNEL_OVERWRITE_CONFIG:=n}
: ${KERNEL_DEFAULT_CONFIG=/proc/config.gz}

: ${CONFIG_TARGET:=nconfig}

# prepare kernel

einfo "Preparing the kernel ... "

F_PRINTVAR=einfo printvar \
   KERNEL_SRC KERNEL_SRC_TYPE \
   KERNEL_WORKDIR KERNEL_BUILD KERNEL_DESTDIR KERNEL_DESTFILE \
   KERNEL_DEFAULT_CONFIG KERNEL_OVERWRITE_CONFIG

F_PRINTVAR=einfo PRINTVAR_SKIP_EMPTY=y printvar \
   ARCH CROSS_COMPILE \
   KERNEL_LOCAL_BUILD \
   KERNEL_BASENAME KERNEL_INSTALL_TARGETS \
   KERNEL_TARGET KERNEL_REAL_TARGET \
   KERNEL_APPEND_DTB


# init:
case "${KERNEL_SRC_TYPE}" in
   'default'|'tarball')
      autodie kcomp_init_${KERNEL_SRC_TYPE} \
         "${KERNEL_SRC}" "${KERNEL_BUILD}" \
         "${KERNEL_DEFAULT_CONFIG}" "${KERNEL_OVERWRITE_CONFIG}"
   ;;
   'git')
      autodie kcomp_init_git \
         "${KENREL_SRC}" "${KERNEL_GIT_REF-}" "${KERNEL_BUILD}" \
         "${KERNEL_DEFAULT_CONFIG}" "${KERNEL_OVERWRITE_CONFIG}"
   ;;
   *)
      __panic__
   ;;
esac

# ARCH could have been set by kcomp_init_*()
F_PRINTVAR=einfo printvar ARCH

einfo "Cleaning up ... "

autodie kcomp_make_clean

if [ "${MAKEPATCH_SHELL:-n}" = "y" ]; then
   autodie kcomp_main_run_makepatch_shell
fi


# patch:
if [ -n "${KERNEL_PATCHES-}" ]; then
   einfo "-> Applying patches"
   F_ITER=kcomp_patch \
   ITER_UNPACK_ITEM=n \
   line_iterator "${KERNEL_PATCHES-}" || die "Failed to apply patches!"
else
   einfo "No patches configured."
fi

kcomp_main_run_configure

if __interactive__; then
   autodie kcomp_main_run_compile_interactive
else
   einfo "Compiling ... "
   autodie kcomp_build
fi

einfo "Installing into ${KERNEL_DESTDIR} ... "
autodie kcomp_install "${KERNEL_DESTDIR}"

einfo "Creating tarball ... "
autodie kcomp_pack "${KERNEL_DESTDIR}" "${KERNEL_TMPDIR}/${KERNEL_DESTFILE##*/}"
autodie mv -T -f -- "${KERNEL_TMPDIR}/${KERNEL_DESTFILE##*/}" "${KERNEL_DESTFILE}"

einfo "${KERNEL_DESTFILE} is ready."
