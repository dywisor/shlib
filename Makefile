BASH       ?= 0
SHLIBCC    := ./CC
GENINSTALL := ./build-scripts/generate-install-src.sh
GENWRAPPER := ./build-scripts/generate-shlibcc-wrapper.sh

ifeq ($(BASH),1)
SHLIBCCFLAGS := --as-lib --strip-virtual --stable-sort --bash
else
SHLIBCCFLAGS := --as-lib --strip-virtual --stable-sort
endif

SHLIB_MODE  ?= 0644
_SHLIB_FILE := ./build/shlib_$(shell date +%F).sh
#_SHLIB_FILE := ./shlib_$(shell git rev-parse --verify HEAD).sh

DESTDIR             :=
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


# targets for building the initramfs
./build/initramfs.cpio: ./build-scripts/buildvars.sh
	QUIET=y ./build-scripts/buildvars.sh --force \
		$(CURDIR) $(CURDIR)/build/work busybox-initramfs $@

.PHONY += initramfs
initramfs: ./build/initramfs.cpio

.PHONY += clean-initramfs
clean-initramfs:
	rm -rf -- ./build/work
	rm -vf -- ./build/initramfs.cpio


# targets for installing shlib's sources

$(SHLIB_SRC_DEST):
	-mkdir -p -- $(SHLIB_SRC_DEST)
	test -d $(SHLIB_SRC_DEST)

.PHONY += install-src
install-src: $(GENINSTALL)
	sh $(GENINSTALL) "$(CURDIR)/lib" \
		"$(SHLIB_SRC_DEST)/lib" "-m 0644" "" "-m 0755" | sh

.PHONY += install-script-templates
install-script-templates: $(GENINSTALL)
	sh $(GENINSTALL) "$(CURDIR)/scripts" \
		"$(SHLIB_SRC_DEST)/examples" "-m 0644" "" "-m 0755" | sh

./build/shlibcc-wrapper.sh: ./build
	sh $(GENWRAPPER) shlibcc "$(SHLIB_SRC_REAL_DEST)/lib" > $@
	chmod 0755 -- $@

./build/shlibcc-scriptgen.sh: ./build
	sh $(GENWRAPPER) scriptgen "$(SHLIB_SRC_REAL_DEST)/lib" > $@
	chmod 0755 -- $@

.PHONY += build-shlibcc-wrapper
build-shlibcc-wrapper: ./build/shlibcc-wrapper.sh ./build/shlibcc-scriptgen.sh
	@true

.PHONY += install-shlibcc-wrapper
install-shlibcc-wrapper:  build-shlibcc-wrapper $(SHLIB_SRC_DEST)
	install -T -m 0755 -- ./build/shlibcc-wrapper.sh \
		"$(SHLIB_SRC_DEST)/shlibcc-wrapper.sh"
	install -T -m 0755 -- ./build/shlibcc-scriptgen.sh \
		"$(SHLIB_SRC_DEST)/shlibcc-scriptgen.sh"
