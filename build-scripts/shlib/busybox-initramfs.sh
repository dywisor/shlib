set -e
set -u
# load build env and build functions
with_stdfunc || die

readonly DEFAULT_BUSYBOX_VERSION="1.21.1"

depcheck mknod fakeroot cpio

readonly D="${BUILD_ROOT}/initramfs"
FILESDIR="${FILESROOT}/initramfs"

WORKDIR="${BUILD_WORKDIR}/initramfs"
autodie dodir_minimal "${WORKDIR}"


INITRAMFS_CPIO_BUILD="${WORKDIR}/initramfs.cpio"
[ ! -e "${INITRAMFS_CPIO_BUILD}" ] || autodie rm "${INITRAMFS_CPIO_BUILD}"

case "${1-}" in
   [0-9].[0-9][0-9].[0-9]*)
      BUSYBOX_PV="${1}"
      shift
   ;;
   *)
      BUSYBOX_PV="${DEFAULT_BUSYBOX_VERSION}"
   ;;
esac

DISTDIR="${PRJROOT}/local/src/busybox-${BUSYBOX_PV}"
autodie dodir_minimal "${DISTDIR}"

BUSYBOX_SRC_LIST="${FILESDIR}/busybox_src-${BUSYBOX_PV}"
BUSYBOX_CONFIG_FILE="${FILESDIR}/bbconfig-${BUSYBOX_PV}"

assert -f "${BUSYBOX_SRC_LIST}"
assert -f "${BUSYBOX_CONFIG_FILE}"


prefetch_info() { einfo "Fetching ${remote_uri} => ${distfile}"; }
http_fetch() {
	if [ -e "${2}" ]; then
		#einfo "${2} exists - skipping"
      einfo "file exists - skipping download"
	else
		wget -O "${2}" "${1}"
	fi
}

F_FETCH_PRE=prefetch_info
F_FETCH_ITEM=http_fetch


autodie fetch_list_from_file "${BUSYBOX_SRC_LIST}"

BUSYBOX_DISTFILE="${DISTDIR}/busybox-${BUSYBOX_PV}.tar.bz2"
assert -f "${BUSYBOX_DISTFILE}"


S="${WORKDIR}/busybox-${BUSYBOX_PV}"
if [ -d "${S}" ]; then
   autodie rm -rf "${S}"
fi

einfo "Unpacking ${BUSYBOX_DISTFILE} ..."
autodie tar xjf "${BUSYBOX_DISTFILE}" -C "${WORKDIR}/"
[ -d "${S}" ] || die "${S} is missing"


einfo "Patching ${S} ..."
for patch in ${DISTDIR}/busybox-${BUSYBOX_PV}-*.patch; do
	if [ -f "${patch}" ]; then
		einfo "${patch} ..." "**"
		autodie patch -up1 -d "${S}" -i "${patch}"
	fi
done


einfo "building busybox"
autodie cp -LfT -- "${BUSYBOX_CONFIG_FILE}" "${S}/.config"

if __quiet__; then
   (
      cd "${S}" && \
      yes '' | make ${MAKEOPTS} -j1 oldconfig 1>/dev/null 2>/dev/null && \
      make ${MAKEOPTS} busybox 1>/dev/null 2>/dev/null
   )
elif __verbose__; then
   (
      cd "${S}" && \
      yes '' | make ${MAKEOPTS} -j1 oldconfig && \
      make ${MAKEOPTS} busybox
   )
else
   (
      cd "${S}" && \
      yes '' | make ${MAKEOPTS} -j1 oldconfig 1>/dev/null && \
      make ${MAKEOPTS} busybox 1>/dev/null
   )
fi || die "failed to compile busybox"


BUSYBOX_DESTFILE="${D}/bin/busybox"
autodie dodir_minimal "${BUSYBOX_DESTFILE%/*}"
autodie cp -LfT -- "${S}/busybox" "${BUSYBOX_DESTFILE}"
autodie chmod 0755 "${BUSYBOX_DESTFILE}"


einfo "building initramfs scripts"
(
   export TARGET_SHLIB_ROOT="/"
   export D
   prepare_dobuild && \
   ${DOBUILD} "${FILESDIR}/initramfs.recipe"
) || exit

einfo "Preparing fakeroot script"

autodie dodir "${D}/dev"

FAKEROOT_SCRIPT="${WORKDIR}/make-initramfs.fakeroot.sh"
echo '#!/bin/sh' > "${FAKEROOT_SCRIPT}" || die

fk() {
   local line
   for line; do
      echo "${line}" >> "${FAKEROOT_SCRIPT}" || die
   done
}

addnod() { fk "mknod ${D}/dev/$*"; }

for dev in console null kmsg fd stdin stdout stderr; do
   [ ! -e "${D}/dev/${dev}" ] || autodie rm "${D}/dev/${dev}"
done

fk "set -e"
fk "chown -R 0:0 ${D}"
addnod tty     -m 666 c 5 0
addnod console -m 666 c 5 1
addnod null    -m 666 c 1 3
addnod kmsg    -m 666 c 1 11
#for i in `seq 0 2`; do
#   addnod tty${i}  -m 666 c 4  ${i}
#   #addnod ttyS${i} -m 666 c 4 6$(( 4 + ${i} ))
#done

fk "cd ${D} && find . | cpio --quiet -o -H newc > ${INITRAMFS_CPIO_BUILD}"
autodie chmod u+x "${FAKEROOT_SCRIPT}"

einfo "Creating ${INITRAMFS_CPIO_BUILD}"
autodie fakeroot -- "${FAKEROOT_SCRIPT}"

if [ -n "${1-}" ]; then
   einfo "Creating output file ${1}"

   [ ! -e "${1}" ] || autodie mv -vfT -- "${1}" "${1}.old"

   if compress__detect_format "${1}" && [ -n "${compress_exe}" ]; then
      ${compress_exe} < "${INITRAMFS_CPIO_BUILD}" > "${1}" || die
   else
      autodie cp -fT -- "${INITRAMFS_CPIO_BUILD}" "${1}"
   fi
else
   autodie mv -vfT "${INITRAMFS_CPIO_BUILD}" "${BUILD_ROOT}/${INITRAMFS_CPIO_BUILD##*/}"
fi

einfo "Cleaning up"
autodie rm -r "${D}"
autodie rm -r "${WORKDIR}"
