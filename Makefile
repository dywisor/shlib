BASH         ?= 0
SHLIBCC       = ./CC
MAKE_SCRIPTS  = ./make_scripts.sh
ifeq ($(BASH),1)
SHLIBCCFLAGS    = --as-lib --strip-virtual --stable-sort --bash
MAKESCRIPT_BASH = y
else
SHLIBCCFLAGS    = --as-lib --strip-virtual --stable-sort
MAKESCRIPT_BASH = n
endif

SHLIB_MODE   ?= 0644

_SHLIB_FILE = ./build/shlib_$(shell date +%F).sh
#_SHLIB_FILE = ./shlib_$(shell git rev-parse --verify HEAD).sh

DESTDIR ?=
DEST    ?= $(DESTDIR)/sh/lib/shlib.sh
USE     ?=
ifeq ($(LOCAL),1)
USE := local $(USE)
endif

default: shlib verify

./build:
	@mkdir ./build

$(_SHLIB_FILE): ./build
	$(SHLIBCC) $(SHLIBCCFLAGS) all > $(_SHLIB_FILE)

verify: $(_SHLIB_FILE)
ifneq ($(BASH),1)
	/bin/busybox ash -n $(_SHLIB_FILE)
	/bin/dash -n $(_SHLIB_FILE)
endif
	/bin/bash -n $(_SHLIB_FILE)

shlib: $(_SHLIB_FILE)

install: $(_SHLIB_FILE) verify
	install -C -D -m $(SHLIB_MODE) $(_SHLIB_FILE) $(DEST)

uninstall: $(DEST)
	rm -- $(DEST)

clean:
	rm -rf ./build

clean-scripts:
	rm -rf ./build/scripts

reinstall: clean install

scripts-linked: clean-scripts $(MAKE_SCRIPTS)
	MAKESCRIPT_DEST=./build/scripts \
	MAKESCRIPT_SHLIB=$(DEST) \
	MAKESCRIPT_STANDALONE=n \
	MAKESCRIPT_FLAT=y \
	MAKESCRIPT_BASH=$(MAKESCRIPT_BASH) \
	$(MAKE_SCRIPTS)

scripts-standalone: clean-scripts $(MAKE_SCRIPTS)
	MAKESCRIPT_DEST=./build/scripts \
	MAKESCRIPT_SHLIB=$(DEST) \
	MAKESCRIPT_STANDALONE=y \
	MAKESCRIPT_FLAT=y \
	MAKESCRIPT_BASH=$(MAKESCRIPT_BASH) \
	$(MAKE_SCRIPTS)

scripts: scripts-linked

initramfs: ./build-scripts/buildvars.sh
	QUIET=y ./build-scripts/buildvars.sh --force $(CURDIR) $(CURDIR)/build/work busybox-initramfs $(CURDIR)/build/initramfs.cpio

tv-scripts: ./build-scripts/buildvars.sh
	USE=$(USE) ./build-scripts/buildvars.sh --force $(CURDIR) $(CURDIR)/build/work -x dobuild-ng $(CURDIR)/files/recipe/tv
	( cd $(CURDIR)/build/work/tv && tar c ./ -f $(CURDIR)/build/tv-scripts.txz --xz --owner=root --group=root; )

tv-scripts-host: ./build-scripts/buildvars.sh
	USE=$(USE) ./build-scripts/buildvars.sh --force $(CURDIR) $(CURDIR)/build/work -x dobuild-ng $(CURDIR)/files/recipe/tv-host

# @lazy
tv-all: tv-scripts-host tv-scripts initramfs

.PHONY: shlib install uninstall clean clean-scripts verify default reinstall \
	scripts-linked scripts-standalone scripts initramfs \
	tv-scripts tv-scripts-host tv-all
