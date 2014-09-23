_PN=shlib
pkgbase=${_PN}-git
pkgname=( ${_PN}{,-modules,-dynloader,-staticloader}-git )
pkgrel=1
pkgver=00000000
arch=('any')
url=
license=('GPL2')
source=("${pkgbase}"::"git://git.github.com/${_PN}.git")
md5sums=('SKIP')

pkgver() {
	LANG=C LC_ALL=C date +%Y%m%d
}

my_shlib_make() {
	make -C "${pkgbase}/" PREFIX=/usr "${@}"
}

build() {
   echo "${pkgver}" > "${pkgbase}/lib/version" || return
	my_shlib_make dynloader || return
	my_shlib_make staticloader
}

package_shlib-git() {
pkgdesc='shell module library meta package'
depends=( ${_PN}-{modules,module-loader}-git )

	true
}

package_shlib-modules-git() {
pkgdesc='shell module library files'
depends=()


	my_shlib_make DESTDIR="${pkgdir}" install-src
}


package_shlib-dynloader-git() {
pkgdesc='shell module library loader'
depends=('bash')
provides=("${_PN}-module-loader-git")
conflicts=("${_PN}-staticloader-git")
optdepends=(
	"${_PN}-modules-git: default shell module files"
)

	my_shlib_make DESTDIR="${pkgdir}" install-dynloader
}

package_shlib-dynloader-git() {
pkgdesc='static shell module library loader'
depends=("${_PN}-modules-git")
provides=("${_PN}-module-loader-git")
conflicts=("${_PN}-dynloader-git")

	my_shlib_make DESTDIR="${pkgdir}" install-staticloader || return
	ln -s -- staticloader/modules/all.sh \
		"${pkgdir%/}/usr/share/shlib/default/shlib.sh"
}
