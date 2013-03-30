BASH         ?= 0
SHLIBCC       = ./CC
ifeq ($(BASH),1)
SHLIBCCFLAGS  = --as-lib --strip-virtual --bash
else
SHLIBCCFLAGS  = --as-lib --strip-virtual
endif

SHLIB_MODE   ?= 0644

_SHLIB_FILE = ./build/shlib_$(shell date +%F).sh
#_SHLIB_FILE = ./shlib_$(shell git rev-parse --verify HEAD).sh

DESTDIR ?=
DEST    ?= $(DESTDIR)/sh/lib/shlib.sh

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

reinstall: clean install

.PHONY: shlib install uninstall clean verify default reinstall
