EAPI=5

EGIT_REPO_URI="git://git.erdmann.es/dywi/${PN}.git"
#EGIT_COMMIT="${PV}"

inherit base git-r3

DESCRIPTION="shell module library"
HOMEPAGE="http://git.erdmann.es/trac/dywi_${PN}"
SRC_URI=""

LICENSE="GPL-2+"
#SLOT="${PV%%.*}"
SLOT="0"
IUSE="+symlink +dynloader +shlibcc"

KEYWORDS=""

DEPEND=""
RDEPEND="shlibcc? ( dev-util/shlibcc ) dynloader? ( app-shells/bash )"

pkg_pretend() {
	if ! use shlibcc && ! use dynloader; then
		ewarn "Neither the shlibcc nor the dynloader USE flag are enabled."
	fi
}

src_prepare() {
	[ -f "${S}/lib/version" ] || die "lib/version does not exist."
	echo "${PV}" > "${S}/lib/version" || die "failed to write lib/version"
	default
}

src_configure() { :; }

src_compile() {
	emake -f Makefile.${PN} \
		SLOT="${SLOT}" PREFIX="${EPREFIX}/usr" \
		$(usex shlibcc{,-wrapper} "") $(usex dynloader{,} "")
}

src_install() {
	emake -f Makefile.${PN} \
		DESTDIR="${D}" PREFIX="${EPREFIX}/usr" SLOT="${SLOT}" \
		SYMLINK_SLOT=$(usex symlink 1 0) \
		install-src \
		$(usex shlibcc   install-shlibcc-wrapper "") \
		$(usex {,install-}dynloader "")
}
