_PN=shlib
pkgbase=${_PN}-git
pkgname=( ${_PN}{,-modules,-dynloader}-git )
pkgrel=1
pkgver=00000000
arch=('any')
url=
license=('GPL2')
source=("${pkgbase}"::"git://git.erdmann.es/dywi/${_PN}")
md5sums=('SKIP')

pkgver() {
	LANG=C LC_ALL=C date +%Y%m%d
}

my_shlib_make() {
	make -C "${pkgbase}/" PREFIX=/usr "${@}"
}

build() {
   echo "${pkgver}" > "${pkgbase}/lib/version"
	my_shlib_make dynloader
}

package_shlib-git() {
pkgdesc='shell module library meta package'
depends=( ${_PN}-{modules,dynloader}-git )

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
optdepends=(
	"${_PN}-modules-git: default shell module files"
)

	my_shlib_make DESTDIR="${pkgdir}" install-dynloader
}
