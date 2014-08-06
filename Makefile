BASH       ?= 0
SHLIBCC    := ./CC

ifeq ($(BASH),1)
SHLIBCCFLAGS := --as-lib --strip-virtual --stable-sort --bash
else
SHLIBCCFLAGS := --as-lib --strip-virtual --stable-sort
endif

SHLIB_MODE  ?= 0644
_SHLIB_FILE := ./build/shlib_$(shell date +%F).sh
#_SHLIB_FILE := ./shlib_$(shell git rev-parse --verify HEAD).sh

DESTDIR             :=
# FIXME: _SHLIB_FILE should be installed to FHS-incompliant dir
SHLIB_DEST          := $(DESTDIR)/sh/lib/shlib.sh
SHLIB_SRC_DEST      := $(DESTDIR)/usr/share/shlib
SHLIB_SRC_REAL_DEST := $(SHLIB_SRC_DEST)


.PHONY =

.PHONY += default
default: shlib verify

./build:
	-mkdir $@
	test -d $@


.PHONY += clean
clean:
	rm -rf ./build


# targets for building the "big" lib file
$(_SHLIB_FILE): ./build
	$(SHLIBCC) $(SHLIBCCFLAGS) all > $(_SHLIB_FILE)

.PHONY += shlib
shlib: $(_SHLIB_FILE)

.PHONY += clean-shlib
clean-shlib:
	rm -vf -- $(_SHLIB_FILE)

.PHONY += verify
verify: $(_SHLIB_FILE)
ifneq ($(BASH),1)
	/bin/busybox ash -n $(_SHLIB_FILE)
	/bin/dash -n $(_SHLIB_FILE)
endif
	/bin/bash -n $(_SHLIB_FILE)

.PHONY += install
install: $(_SHLIB_FILE) verify
	install -C -D -m $(SHLIB_MODE) $(_SHLIB_FILE) $(SHLIB_DEST)

.PHONY += uninstall
uninstall: $(SHLIB_DEST)
	rm -- $(SHLIB_DEST)

