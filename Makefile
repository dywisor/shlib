SHELL := /bin/sh
export SHELL

DESTDIR       :=
PREFIX        := /usr/local
SHAREDIR      := $(PREFIX)/share
BINDIR        := $(PREFIX)/bin
SLOT          :=
SYMLINK_SLOT  := 0
BASH          ?= 0
export DESTDIR PREFIX SHAREDIR BINDIR SLOT SYMLINK_SLOT BASH

PN                 := shlib
S                  := $(CURDIR)
O                  := $(CURDIR)/build/$(PN)
SHLIB_BUILDSCRIPTS := $(S)/build-scripts
SHLIB_LIB_SRC      := $(S)/lib
SHLIBCC            := $(S)/CC
export O
#export SHLIB_BUILDSCRIPTS SHLIB_LIB_SRC SHLIBCC

VERSION := $(shell head -n 1 $(S)/lib/VERSION 2>/dev/null)
ifeq ($(VERSION),)
   override VERSION := undef
endif

SHLIBCC_LIB_FLAGS := --as-lib --strip-virtual --stable-sort

_SHLIBCC_GEN_LIB   = $(SHLIBCC) $(SHLIBCC_LIB_FLAGS) -S $(SHLIB_LIB_SRC)
ifeq ($(BASH),1)
_SHLIBCC_GEN_LIB  += --bash
endif

X_GENINSTALL     := $(SHLIB_BUILDSCRIPTS)/generate-install-src.sh
X_GENPRELINK     := $(SHLIB_BUILDSCRIPTS)/gen-prelinked-tree.sh
X_GENWRAPPER     := $(SHLIB_BUILDSCRIPTS)/generate-shlibcc-wrapper.sh
WRAPPER_SHELL    := sh
WRAPPER_SHLIBCC  := /usr/bin/shlibcc
SHLIBCC_WRAPPERS := shlibcc scriptgen

ifeq ($(SLOT),)
_WANT_SLOT_SYM := 0
SLOT_SUFFIX    :=
SHLIB_SHAREDIR := $(SHAREDIR)/$(PN)/default
else
SLOT_SUFFIX    := _$(SLOT)
SHLIB_SHAREDIR := $(SHAREDIR)/$(PN)/$(PN)$(SLOT_SUFFIX)
_WANT_SLOT_SYM := $(SYMLINK_SLOT)
endif

export SLOT_SUFFIX SHLIB_SHAREDIR _WANT_SLOT_SYM

STATICLOADER_PRELINKED_ROOT = $(SHLIB_SHAREDIR)/staticloader/modules
STATICLOADER_PRELINK_SUFFIX = .sh
export STATICLOADER_PRELINKED_ROOT STATICLOADER_PRELINK_SUFFIX

SRCDIR_STATICLOADER_BUILDDIR       = $(O)/srcdir-staticloader
SRCDIR_STATICLOADER_PRELINKED_ROOT = $(SRCDIR_STATICLOADER_BUILDDIR)/prelinked

SHLIB_INCLUDEDIR := $(SHLIB_SHAREDIR)/include
export SHLIB_INCLUDEDIR

DIRMODE  := 0755
INSMODE  := 0644
EXEMODE  := 0755
LINKMODE := -nfT -s
export DIRMODE INSMODE EXEMODE LINKMODE

_DOLINK   = ln $(LINKMODE)
_DODIR    = install -m $(DIRMODE) -d
_DOINS    = install -m $(INSMODE)
_DOEXE    = install -m $(EXEMODE)
export _DOLINK _DODIR _DOINS _DOEXE

ifeq ($(BINDIR_TO_SHAREDIR_RELPATH),)
BINDIR_TO_SHAREDIR_RELPATH := $(shell \
	realpath -Lsm  \
		--relative-base=$(PREFIX) --relative-to=$(BINDIR) $(SHLIB_SHAREDIR) \
)
endif
export BINDIR_TO_SHAREDIR_RELPATH

ifeq ($(BINDIR_TO_SHAREDIR_RELPATH),)
$(error failed to get bindir->sharedir relpath (run "make BINDIR_TO_SHAREDIR_RELPATH=UNDEF help"))
endif

_DYNLOADER_MAKEOPTS    = -C $(S)/dynloader    O=$(O) S=$(S)/dynloader
_STATICLOADER_MAKEOPTS = -C $(S)/staticloader O=$(O) S=$(S)/staticloader

_SRCDIR_STATICLOADER_MAKEOPTS =
_SRCDIR_STATICLOADER_MAKEOPTS += -C $(S)/staticloader
_SRCDIR_STATICLOADER_MAKEOPTS += O=$(SRCDIR_STATICLOADER_BUILDDIR)
_SRCDIR_STATICLOADER_MAKEOPTS += S=$(S)/staticloader
_SRCDIR_STATICLOADER_MAKEOPTS += HAVE_SHLIB_INSTALL_VARS=0
_SRCDIR_STATICLOADER_MAKEOPTS += STATICLOADER_DIR=$(S)/staticloader
_SRCDIR_STATICLOADER_MAKEOPTS += STATICLOADER_MODULES_ROOT=$(SHLIB_LIB_SRC)
_SRCDIR_STATICLOADER_MAKEOPTS += STATICLOADER_FUNCTIONS=$(S)/staticloader/functions.sh
_SRCDIR_STATICLOADER_MAKEOPTS += STATICLOADER_PRELINKED_ROOT=$(SRCDIR_STATICLOADER_PRELINKED_ROOT)


HAVE_SHLIB_INSTALL_VARS = 1
export HAVE_SHLIB_INSTALL_VARS

_ALMOST_ALL_TARGETS = shlib src dynloader shlibcc-wrapper
_ALL_TARGETS        = $(_ALMOST_ALL_TARGETS) staticloader srcdir-staticloader


PHONY :=

PHONY += default
default:

PHONY += all
all: shlib dynloader

PHONY += install-all
install-all: $(addprefix install-,$(_ALMOST_ALL_TARGETS))


PHONY += clean
clean: $(addprefix clean-,$(_ALL_TARGETS))
	test -n '$(O)'
	rm -r -f -- '$(O)'

PHONY += clean-shlib
clean-shlib:
	rm -f $(O)/shlib.sh

PHONY += clean-src
clean-src:

PHONY += clean-dynloader
clean-dynloader:
	rm -f -- $(S)/runscript
	$(MAKE) $(_DYNLOADER_MAKEOPTS) clean

PHONY += clean-staticloader
clean-staticloader:
	test ! -d '$(O)/prelinked' || rm -r -- '$(O)/prelinked'
	$(MAKE) $(_STATICLOADER_MAKEOPTS) clean


PHONY += clean-srcdir-staticloader
clean-srcdir-staticloader:
	rm -f  -- '$(S)/runscript-static'
	test ! -d '$(SRCDIR_STATICLOADER_PRELINKED_ROOT)' || \
		rm -r '$(SRCDIR_STATICLOADER_PRELINKED_ROOT)'
	$(MAKE) $(_SRCDIR_STATICLOADER_MAKEOPTS) clean


PHONY +=

PHONY += clean-shlibcc-wrapper
clean-shlibcc-wrapper:
	rm -f -- $(wildcard $(O)/*_wrapper)


PHONY += shlib
shlib: $(O)/shlib.sh

PHONY += src
src:

PHONY += dynloader
dynloader:
	$(MAKE) $(_DYNLOADER_MAKEOPTS) all
	rm -f -- $(S)/runscript
	ln -s -- dynloader/runscript.bash $(S)/runscript

PHONY += staticloader
staticloader:
	$(X_GENPRELINK) \
		'$(SHLIB_LIB_SRC)' '$(O)/prelinked' \
		'$(SHLIB_INCLUDEDIR)' '$(STATICLOADER_PRELINKED_ROOT)' \
		'$(STATICLOADER_PRELINK_SUFFIX)'

	$(MAKE) $(_STATICLOADER_MAKEOPTS) all

PHONY += srcdir-staticloader
srcdir-staticloader: clean-srcdir-staticloader
	$(X_GENPRELINK) \
		'$(SHLIB_LIB_SRC)' '$(SRCDIR_STATICLOADER_PRELINKED_ROOT)' - - \
		'$(STATICLOADER_PRELINK_SUFFIX)'

	$(MAKE) $(_SRCDIR_STATICLOADER_MAKEOPTS) all
	chmod +x '$(SRCDIR_STATICLOADER_BUILDDIR)/runscript.sh'

	rm -f  -- '$(S)/runscript-static'
	ln -s  -- '$(SRCDIR_STATICLOADER_BUILDDIR)/runscript.sh' '$(S)/runscript-static'


PHONY += shlibcc-wrapper
shlibcc-wrapper: $(foreach k,$(SHLIBCC_WRAPPERS),$(O)/$(k)_wrapper)


PHONY += install-shlib
install-shlib:
	$(_DODIR) -- $(DESTDIR)$(SHLIB_SHAREDIR)

	$(_DOINS) -- $(O)/shlib.sh $(DESTDIR)$(SHLIB_SHAREDIR)/$(PN).sh
ifeq ($(_WANT_SLOT_SYM),1)
	$(_DOLINK) -s -- $(notdir $(SHLIB_SHAREDIR))/$(PN).sh \
		$(DESTDIR)$(dir $(SHLIB_SHAREDIR))$(PN).sh
endif

PHONY += install-src
install-src: $(O)/install-src.sh
	$(SHELL) $<
ifeq ($(_WANT_SLOT_SYM),1)
	$(_DOLINK) -s -- $(notdir $(SHLIB_SHAREDIR)) \
		$(DESTDIR)$(dir $(SHLIB_SHAREDIR))default
endif

PHONY += install-full-src
install-full-src:
	@echo '$@: unsafe'
	$(_DODIR) -- $(DESTDIR)$(dir $(SHLIB_INCLUDEDIR))

	cp -a --no-preserve=ownership --remove-destination \
		'$(SHLIB_LIB_SRC)/.' '$(DESTDIR)$(SHLIB_INCLUDEDIR)/'
	find '$(DESTDIR)$(SHLIB_INCLUDEDIR)/' -type f -print0 | xargs -0 chmod $(INSMODE) --
	find '$(DESTDIR)$(SHLIB_INCLUDEDIR)/' -type d -print0 | xargs -0 chmod $(DIRMODE) --
ifeq ($(_WANT_SLOT_SYM),1)
	$(_DOLINK) -s -- $(notdir $(SHLIB_SHAREDIR)) \
		$(DESTDIR)$(dir $(SHLIB_SHAREDIR))default
endif

PHONY += install-dynloader
install-dynloader:
	$(MAKE) $(_DYNLOADER_MAKEOPTS) install

PHONY += install-staticloader
install-staticloader:
	$(_DODIR) -- $(DESTDIR)$(dir $(STATICLOADER_PRELINKED_ROOT))

	cp -a --no-preserve=ownership --remove-destination \
		'$(O)/prelinked/.' '$(DESTDIR)$(STATICLOADER_PRELINKED_ROOT)/'
	find '$(DESTDIR)$(STATICLOADER_PRELINKED_ROOT)/' -type f -print0 | xargs -0 chmod $(INSMODE) --
	find '$(DESTDIR)$(STATICLOADER_PRELINKED_ROOT)/' -type d -print0 | xargs -0 chmod $(DIRMODE) --

	$(MAKE) $(_STATICLOADER_MAKEOPTS) install

PHONY += install-shlibcc-wrapper
install-shlibcc-wrapper:
	$(_DODIR) -- $(DESTDIR)$(SHLIB_SHAREDIR) $(DESTDIR)$(BINDIR)

	true $(foreach k,$(SHLIBCC_WRAPPERS),\
		&& $(_DOEXE) -- $(O)/$(k)_wrapper $(DESTDIR)$(SHLIB_SHAREDIR)/shlib-$(k) \
		&& $(_DOLINK) -- $(BINDIR_TO_SHAREDIR_RELPATH)/shlib-$(k) \
			$(DESTDIR)$(BINDIR)/shlib-$(k)$(SLOT_SUFFIX) \
	)

ifeq ($(_WANT_SLOT_SYM),1)
	true $(foreach k,$(SHLIBCC_WRAPPERS),\
		&& $(_DOLINK) -- $(BINDIR_TO_SHAREDIR_RELPATH)/shlib-$(k) \
			$(DESTDIR)$(BINDIR)/shlib-$(k) \
	)
endif

$(O)/shlib.sh: $(addprefix $(SHLIB_LIB_SRC)/all.,sh depend) $(SHLIB_LIB_SRC)/
	mkdir -p -- $(@D)
	$(_SHLIBCC_GEN_LIB) all > $@.make_tmp
	$(SHELL) -n $@.make_tmp
	mv -f -- $@.make_tmp $@

$(O)/install-src.sh: $(X_GENINSTALL) FORCE
	mkdir -p -- $(@D)

	$< '$(SHLIB_LIB_SRC)' '$(DESTDIR)$(SHLIB_INCLUDEDIR)' \
		'-m $(INSMODE)' '' '-m $(DIRMODE)' > $@.make_tmp
	$(SHELL) -n $@.make_tmp
	mv -f -- $@.make_tmp $@


$(O)/%_wrapper: $(X_GENWRAPPER)
	mkdir -p $(@D)

	$< $* $(SHLIB_INCLUDEDIR) $(WRAPPER_SHLIBCC) $(WRAPPER_SHELL) > $@.make_tmp
	$(WRAPPER_SHELL) -n $@.make_tmp
	mv -f -- $@.make_tmp $@


PHONY += version
version:
	@printf "%s\n" '$(VERSION)'

PHONY += help
help:
	@echo  'Targets:'
	@echo  '  default                  - Does nothing (default target)'
	@echo  '  all                      - Build all targets marked with [*]'
	@echo  '  install-all              - Install everything'
	@echo  '  clean                    - Remove generated files'
	@echo  '                              (implies all clean- targets)'
	@echo  '  version                  - Print version'
	@echo  ''
	@echo  'Build targets:'
	@echo  '* shlib                    - Build the big library file'
	@echo  '* src                      - Does nothing'
	@echo  '* dynloader                - Build the dynamic module loader'
	@echo  '  staticloader             - Build the static module loader'
	@echo  '  srcdir-staticloader      - Build srcdir static module loader'
	@echo  '  shlibcc-wrapper          - Build shlibcc wrapper scripts'
	@echo  ''
	@echo  'Install targets:'
	@echo  '  install-shlib            - Install library file to DESTDIR/SHLIB_SHAREDIR'
	@echo  '  install-src              - Install module files to DESTDIR/SHLIB_INCLUDEDIR'
	@echo  '  install-dynloader        - Install dynloader to DESTDIR/SHLIB_SHAREDIR/dynloader'
	@echo  '                             and set up links in DESTDIR/BINDIR'
	@echo  '  install-staticloader     - Install staticloader to DESTDIR/SHLIB_SHAREDIR/staticloader'
	@echo  '                             and set up links in DESTDIR/BINDIR'
	@echo  '  install-shlibcc-wrapper  - Install shlibcc wrappers to DESTDIR/SHLIB_SHAREDIR'
	@echo  '                             and set up links in DESTDIR/BINDIR'
	@echo  '  install-full-src         - Install *all* module files to DESTDIR/SHLIB_INCLUDEDIR'
	@echo  '                              This includes the usual files plus experimental/blocked modules'
	@echo  '                              NOT RECOMMENDED'
	@echo  ''
	@echo  ' Note: install targets do not imply build actions'
	@echo  ''
	@echo  'Clean targets:'
	@echo  '  clean-shlib               - Remove files generated by "shlib"'
	@echo  '  clean-src                 - Does nothing'
	@echo  '  clean-dynloader           - Remove files generated by "dynloader"'
	@echo  '  clean-staticloader        - Remove files generated by "staticloader"'
	@echo  '  clean-srcdir-staticloader - Remove files generated by "srcdir-staticloader"'
	@echo  '  clean-shlibcc-wrapper     - Remove files generated by "shlibcc-wrapper"'
	@echo  ''
	@echo  ''
	@echo  'Variables:'
	@echo  '  PN                - program name [$(PN)]'
	@echo  '                      (default: shlib)'
	@echo  '  SHELL             - shell (e.g. for running build/install scripts) [$(SHELL)]'
	@echo  '                      (default: /bin/sh)'
	@echo  ''
	@echo  'install-related variables:'
	@echo  '  DESTDIR           - installation root directory [$(DESTDIR)]'
	@echo  '                      (default: <empty>)'
	@echo  '  PREFIX            - installation prefix [$(PREFIX)]'
	@echo  '                      (relative to DESTDIR)'
	@echo  '  SHAREDIR          - arch indep data dir [$(SHAREDIR)]'
	@echo  '                      (default: PREFIX/share)'
	@echo  '  BINDIR            - binaries directory [$(BINDIR)]'
	@echo  '                      (default: PREFIX/bin)'
	@echo  ''
ifeq ($(SLOT),)
	@echo  '  SLOT              - installation slot [<empty>]'
else
	@echo  '  SLOT              - installation slot [$(SLOT)]'
endif
	@echo  '                       $(PN) will be installed in a slot-specific'
	@echo  '                       subdirecty if SLOT is set and not empty'
	@echo  '                      (default: <empty>)'
	@echo  '  SHLIB_SHAREDIR    - data root dir for $(PN) [$(SHLIB_SHAREDIR)]'
	@echo  '                      (default: depends on SLOT,'
	@echo  '                       empty SLOT => SHAREDIR/PN/default'
	@echo  '                             SLOT => SHAREDIR/PN/PN_SLOT)'
	@echo  '  SHLIB_INCLUDEDIR  - shell module file dest dir [$(SHLIB_INCLUDEDIR)]'
	@echo  '                      (default: SHLIB_SHAREDIR/include)'
ifeq ($(SYMLINK_SLOT),)
	@echo  '  SYMLINK_SLOT      - if set to 1: create non-SLOT symlinks for SLOT installation [0]'
else
	@echo  '  SYMLINK_SLOT      - if set to 1: create non-SLOT symlinks for SLOT installation [$(SYMLINK_SLOT)]'
endif
	@echo  '                      (default: 0)'
	@echo  ''
	@echo  '  BINDIR_TO_SHAREDIR_RELPATH  -'
	@echo  '                      path of SHLIB_SHAREDIR relative to BINDIR [$(BINDIR_TO_SHAREDIR_RELPATH)]'
	@echo  '                       Needs to be set manually on systems without'
	@echo  '                       coreutils'\'' realpath, e.g. Debian'
	@echo  '                      (default: <automatic detection>)'
	@echo  ''
	@echo  '  DIRMODE           - mode for creating directories [$(DIRMODE)]'
	@echo  '                      (default: 0755)'
	@echo  '  INSMODE           - mode for installing data files [$(INSMODE)]'
	@echo  '                      (default: 0644)'
	@echo  '  EXEMODE           - mode for installing executable files [$(EXEMODE)]'
	@echo  '                      (default: 0755)'
	@echo  '  LINKMODE          - options for linking directories and files [$(LINKMODE)]'
	@echo  '                      (default: -nfT -s)'
	@echo  ''
	@echo  'build-related variables:'
	@echo  '  O                 - output directory [$(O)]'
	@echo  '                      (default: <source directory>/build/$$PN)'
	@echo  '  SHLIBCC           - path to or name of shlibcc [$(SHLIBCC)]'
	@echo  '                      (default: autodetection using <source directory>/CC)'
	@echo  '  SHLIBCC_LIB_FLAGS - shlibcc options for creating library files'
	@echo  '                       [$(SHLIBCC_LIB_FLAGS)]'
	@echo  '  WRAPPER_SHELL     - shell that will be used in shlibcc wrapper scripts [$(WRAPPER_SHELL)]'
	@echo  '                      (default: sh)'
	@echo  '  WRAPPER_SHLIBCC   - path to shlibcc for the generated wrapper scripts [$(WRAPPER_SHLIBCC)]'
	@echo  '                       Has to be an *absolute* path.'
	@echo  '                      (default: /usr/bin/shlibcc)'
	@echo  '  BASH              - if set to 1: prefer bash modules ("shlib" target)'


FORCE:


.PHONY: $(PHONY)
