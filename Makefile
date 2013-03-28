SHLIBCC = ./CC
SHLIBCCFLAGS = --as-lib --strip-virtual

_SHLIB_FILE = ./build/shlib_$(shell date +%F).sh
#_SHLIB_FILE = ./shlib_$(shell git rev-parse --verify HEAD).sh

DESTDIR ?=
DEST    ?= $(DESTDIR)/sh/lib/shlib.sh

./build:
	@mkdir ./build

$(_SHLIB_FILE): ./build
	$(SHLIBCC) $(SHLIBCCFLAGS) all > $(_SHLIB_FILE)

shlib: $(_SHLIB_FILE)

install: $(_SHLIB_FILE)
	install -C -D -g 100 -m 0644 $(_SHLIB_FILE) $(DEST)

uninstall: $(DEST)
	rm -- $(DEST)

clean:
	rm -rf ./build

.PHONY: shlib install uninstall clean
