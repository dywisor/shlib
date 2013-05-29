#!/bin/sh
##
## This script has to be appended to pack_system (or linked against it)
##

# fix up $TMPDIR
[ -n "${TMPDIR-}" ] && [ -d "${TMPDIR}" ] || TMPDIR=/tmp

# ========
#  config
# ========

# compression format
#  common choices are gzip and xz, depending on whether you want to spend
#  more time on reading (gzip) or unpacking (xz) tarballs
#
#  The target machine has a rather slow connection to its sysdisk (USB).
#
: ${PACK_COMPRESS_FORMAT:=xz}

# root directory
#  all targets are relative to this dir
#
: ${PACK_ROOT:=/}

# image dir
#  where tarballs / squashfs files will be written to
#
#  Leaving this empty results in auto-configuration by setup().
#
: ${IMAGE_DIR=}


# =======================
#  target-related config
# =======================

# You may want to set this to y to skip gentoo-related functionality
#  Not implemented yet.
: ${NOT_GENTOO:=n}

# in case you want to keep "everything" (build-time files/dirs will be
# removed, though)
KEEP_EVERYTHING=n

WITH_VDR_TARBALLS=y

# man page directories to remove:
MAN_PURGE="cs de es fi fr hu id it ja ko pl pt_BR ru sv tr zh_CN zh_TW"

# keymap dirs to remove:
KEYMAP_PURGE="amiga atari mac ppc sun \
i386/azerty i386/colemak i386/dvorak i386/fgGIod i386/olpc"

LOCALE_PURGE="cs da es fi fr hu id is it ja nl pl \
pt_BR pt_PT ro ru sv vi zh_CN zh_TW"

#LOCALE_PURGE="${LOCALE_PURGE-} de de_DE"
LOCALE_PURGE="${LOCALE_PURGE-} en_GB"

# lib64 or lib?
LIBDIR=lib64

# useless files in /etc/conf.d, /etc/init.d
# * useless ^= target has no use for these files
#
INITD_PURGE="crypto-loop dhcrelay dhcrelay6 fancontrol git-daemon hdparm \
iptables lm_sensors mdadm mdraid nullmailer pciparm pydoc-2.7 pydoc-3.2 \
smartd swap swapfiles sysstat wpa_supplicant"

# should this script die if a service in INITD_PURGE is found in
# /etc/runlevels/*? That's generally a good idea.
#
# Setting this to 'n' results in printing an error message only.
#
INITD_PURGE_DIE_IF_ENABLED=y

CONFD_PURGE="${INITD_PURGE-}"

PYTHON_INSTALLED_VERSIONS="2.7 3.2"

# keep development files?
#
# * /usr/include
#
# Note: only partially implemented
#
KEEP_DEV_FILES=y

# keep development tools?
#
# * app-portage/eix
# * app-portage/euses
# * app-portage/gentoolkit
# * app-portage/portage-utils
# * sys-apps/portage
#
# Note: only partially implemented
#
KEEP_DEV_TOOLS=y

# app-portage/portage-utils q applets
Q_APPLETS="qatom qcache qcheck qdepends qfile qgrep qlist qlop \
qmerge qpkg qsearch qsize qtbz2 quse qxpak q"


# ================
#  misc functions
# ================

python_purge_site_packages() {
   local p
   for p in ${PYTHON_INSTALLED_VERSIONS?}; do
      ex_prefix_foreach /${LIBDIR:?}/python${p#python}/site-packages "$@"
   done
}

man_x_purge() {
   local x="${1:?}"; shift
   local m
   case "${x}" in
      *.*)
         x="${x%.}"
      ;;
      *)
         x="${x}.bz2"
      ;;
   esac
   for m; do
      ex /share/man/man${x%.*}/${m%.${x}*}.${x}
   done
}

keep_everything()      { [ "${KEEP_EVERYTHING:-n}" = "y" ]; }
dont_keep_everything() { ! keep_everything; }

# =========
#  targets
# =========

# target definitions
#  int pack_target_<target name>() { /* packs $target */ }
#

## rootfs
pack_target_rootfs() {
   next / rootfs
   ex   /LIRAM_ENV /pack.sh /pack_tv.sh
   ex   /stagemounts /CHROOT /BUILD /portage
   exd  /proc /sys /dev /run /etc /var /usr /sh /tmp
   pack
}
add_target rootfs

## etc
pack_target_etc() {
   next /etc as tarball
   ex /VENDOR /machine-id
   ex /group- /gshadow- /passwd- /shadow-

   if [ "${WITH_VDR_TARBALLS:?}" = "y" ]; then
      ex /vdr /vdradmin
   fi

   if dont_keep_everything; then
      local f
      local s
      for f in ${INITD_PURGE?}; do
         # lazy implementation
         if [ -n "$( \
            find "${PACK_SRC}/runlevels" -xdev -type l -name "${f}" | head -n 1 \
         )" ]; then
            s="${s-}${s:+ }${f}"
         fi
      done
      if [ -n "${s-}" ]; then
         eerror "The following services are enabled but marked for removal"
         for f in ${s}; do eerror "  ${f}"; done

         if [ "${INITD_PURGE_DIE_IF_ENABLED:?}" = "y" ]; then
            die "Please fix INITD_PURGE."
         else
            ewarn "Continuing due to INITD_PURGE_DIE_IF_ENABLED=n."
         fi
      fi

      ex_prefix_foreach /conf.d ${CONFD_PURGE?}
      ex_prefix_foreach /init.d ${INITD_PURGE?}

      if [ "${KEEP_DEV_TOOLS:?}" != "y" ]; then
         ex \
            /eixrc /eclean /revdep-rebuild /env.d/99gentoolkit-env \
            /portage/bin/post_sync /portage/postsync.d/q-reinitialize \
            /etc-update.conf /dispatch-conf.conf \
            /logrotate.d/elog-save-summary

         # why keep env.d if /usr/sbin/env-update is to be removed?
         exd /env.d
      fi
   fi

   pack
}
add_target etc

## etc-vdr
pack_target_etc_vdr() { oneshot /etc/vdr etc-vdr; }
[ "${WITH_VDR_TARBALLS:?}" != "y" ] || add_target etc_vdr

## etc-vdradmin
pack_target_etc_vdradmin() { oneshot /etc/vdradmin etc-vdradmin; }
[ "${WITH_VDR_TARBALLS:?}" != "y" ] || add_target etc_vdradmin

## var
pack_target_var() {
   next /var
   if dont_keep_everything; then
      ex /portage /db /cache/eix /cache/db
   fi
   exd  /log /tmp /run /lock
   pack
}
add_target var

## log
pack_target_log() { oneshot /var/log as tarball; }
add_target log

## usr
pack_target_usr() {
   next /usr as squashfs

   ex  /portage
   exd /tmp

   if dont_keep_everything; then
      ex /share/info /share/doc /share/gtk-doc
      ex_prefix_foreach /share/keymaps ${KEYMAP_PURGE?}
      ex_prefix_foreach /share/man     ${MAN_PURGE?}
      ex_prefix_foreach /share/locale  ${LOCALE_PURGE?}

      if [ "${KEEP_DEV_FILES:?}" != "y" ]; then
         exd /include
      fi

      if [ "${KEEP_DEV_TOOLS:?}" != "y" ]; then
         # eix
         ex_prefix_foreach /bin \
            eix eix-diff eix-drop-permissions eix-functions.sh eix-installed \
            eix-installed-after eix-layman eix-remote eix-sync \
            eix-test-obsolete eix-update versionsort

         # euses
         ex /bin/euses
         ex /share/man/man1/euses.1.bz2

         # gentoolkit
         ex_prefix_foreach /bin \
            eclean eclean-dist eclean-pkg enalyze \
            epkginfo equery eread eshowkw euse glsa-check \
            revdep-rebuild revdep-rebuild.py revdep-rebuild.sh

         python_purge_site_packages gentoolkit

         man_x_purge 1 \
            equery glsa-check eread euse eshowkw \
            revdep-rebuild enalyze epkginfo eclean


         # portage-utils

         ex_prefix_foreach /bin ${Q_APPLETS?}
         man_x_purge 1 ${Q_APPLETS?}

         # portage (!)

         ex_prefix_foreach /bin \
            ebuild egencache emerge emerge-webrsync emirrordist \
            portageq quickpkg repoman

         ex_prefix_foreach /sbin \
            archive-conf dispatch-conf emaint env-update etc-update \
            fixpackages regenworld update-env update-etc

         # lazy-exclude (using lib instead of $LIBDIR is correct here)
         ex /lib/portage

         python_purge_site_packages _emerge portage repoman

         ex /share/portage
         man_x_purge 1 \
            repoman quickpkg fixpackages etc-update env-update emirrordist \
            emerge emaint egencache ebuild dispatch-conf
         man_x_purge 5 xpak portage make.conf ebuild color.map

      fi
   fi

   pack
}
add_target usr

## scripts
#
# This target is no longer used, because runtime changes to /sh are not
# expected for the target machine. A tarball containing all scripts can be
# created via "make tv-scripts" (in the shlib repo root directory).
#
pack_target_scripts() {
   next /sh scripts
   exd /build
   pack
}
#add_target scripts

# update - virtual target for packing live system changes
#          (packs everything except rootfs and usr)
#
pack_target_update() {
   if [ -z "${DOTAR_OVERWRITE-}" ]; then
      einfo "setting DOTAR_OVERWRITE=y"
      local DOTAR_OVERWRITE=y
   fi
   ${virtual} etc var log # scripts

   if [ "${WITH_VDR_TARBALLS:?}" = "y" ]; then
      ${virtual} etc_vdr etc_vdradmin
   fi
}
add_virtual_target update

# vdr update - virtual target that packs vdr dirs in /etc
#
pack_target_vdr_update() {
   if [ -z "${DOTAR_OVERWRITE-}" ]; then
      einfo "setting DOTAR_OVERWRITE=y"
      local DOTAR_OVERWRITE=y
   fi
   ${virtual} etc_vdr etc_vdradmin
}
add_virtual_target vdr_update


# ======
#  main
# ======

if [ "${PACK_TV_AS_LIB:-n}" != "y" ]; then
   pack_autodie
   MY_FAKE=n
   case "${1-}" in
      '-n'|'--dry-run'|'-p'|'--pretend')
         MY_FAKE=y
         shift || die
      ;;
      *)
         MY_FAKE=n
      ;;
   esac

   setup "${PACK_ROOT}" "${PACK_COMPRESS_FORMAT}" "${MY_FAKE}" "${IMAGE_DIR}"

   if [ $# -eq 0 ]; then
      pack_run_target all
   else
      pack_run_target "$@"
   fi
fi
