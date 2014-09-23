if [ -z "${__HAVE_SHLIB_DYNLOADER_DYNSCRIPT__-}" ]; then

shlib_require() {
	shlib_dynloader_load_deps "$@" || exit
}

fi # __HAVE_SHLIB_DYNLOADER_DYNSCRIPT__
