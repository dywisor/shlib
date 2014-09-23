EAPI=5

EGIT_REPO_URI="
	git://github.com/dywisor/shlib.git
	https://github.com/dywisor/shlib.git"
#EGIT_COMMIT="${PV}"

inherit base git-r3

DESCRIPTION="shell module library"
HOMEPAGE=""
SRC_URI=""

LICENSE="GPL-2+"
#SLOT="${PV%%.*}"
SLOT="0"
IUSE="+symlink dynloader +staticloader +shlibcc"
REQUIRED_USE="staticloader? ( !dynloader )"

KEYWORDS=""

DEPEND=""
RDEPEND="shlibcc? ( dev-util/shlibcc ) dynloader? ( app-shells/bash )"

pkg_pretend() {
	if ! { use shlibcc || use dynloader || use staticloader; }; then
		ewarn "No shlibcc/module loader USE flag is enabled."
	fi
}

src_prepare() {
	[ -f "${S}/lib/version" ] || die "lib/version does not exist."
	echo "${PV}" > "${S}/lib/version" || die "failed to write lib/version"
	default
}

src_configure() { :; }

src_compile() {
	emake \
		SLOT="${SLOT}" PREFIX="${EPREFIX}/usr" \
		$(usex shlibcc{,-wrapper} "") \
		$(usex dynloader{,} "") \
		$(usex staticloader{,} "")
}

src_install() {
	emake \
		DESTDIR="${D}" PREFIX="${EPREFIX}/usr" SLOT="${SLOT}" \
		SYMLINK_SLOT=$(usex symlink 1 0) \
		install-src \
		$(usex shlibcc   install-shlibcc-wrapper "") \
		$(usex {,install-}dynloader "") \
		$(usex {,install-}staticloader "")

	if use staticloader; then
		dosym staticloader/modules/all.sh /usr/share/shlib/shlib_${SLOT}/shlib.sh
	fi
}
