SHELL := /bin/sh

DESTDIR       :=
PREFIX        := /usr/local
SHAREDIR      := $(PREFIX)/share
BINDIR        := $(PREFIX)/bin
SLOT          :=
SYMLINK_SLOT  := 0

PN                 := shlib
S                  := $(CURDIR)
O                  := $(CURDIR)/build/$(PN)_src
SHLIB_BUILDSCRIPTS := $(S)/build-scripts
SHLIB_LIB_SRC      := $(S)/lib


X_GENINSTALL     := $(SHLIB_BUILDSCRIPTS)/generate-install-src.sh
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

SHLIB_INCLUDEDIR := $(SHLIB_SHAREDIR)/include

DIRMODE  := 0755
INSMODE  := 0644
EXEMODE  := 0755
LINKMODE := -nfT -s

_DOLINK   = ln $(LINKMODE)
_DODIR    = install -m $(DIRMODE) -d
_DOINS    = install -m $(INSMODE)
_DOEXE    = install -m $(EXEMODE)

BINDIR_TO_SHAREDIR_RELPATH := $(shell \
	realpath -Lsm  \
		--relative-base=$(PREFIX) --relative-to=$(BINDIR) $(SHLIB_SHAREDIR) \
)

ifeq ($(BINDIR_TO_SHAREDIR_RELPATH),)
$(error failed to get bindir->sharedir relpath.)
endif


PHONY :=

PHONY += all
all:

PHONY += clean
clean:
	test -n '$(O)'
	rm -r -f -- '$(O)'

PHONY += dynloader
dynloader:
	$(MAKE) -C $(S)/dynloader all

PHONY += shlibcc-wrapper
shlibcc-wrapper: $(foreach k,$(SHLIBCC_WRAPPERS),$(O)/$(k)_wrapper)


PHONY += install-src
install-src: $(O)/install-src.sh
	$(SHELL) $<
ifeq ($(_WANT_SLOT_SYM),1)
	$(_DOLINK) -s -- $(notdir $(SHLIB_SHAREDIR)) \
		$(DESTDIR)$(dir $(SHLIB_SHAREDIR))default
endif

PHONY += install-dynloader
install-dynloader:
	$(_DODIR) -- $(DESTDIR)$(SHLIB_SHAREDIR)/dynloader $(DESTDIR)$(BINDIR)

	true $(foreach k,$(addsuffix .bash,runscript runscript-wrapper dynloader),\
		&& $(_DOEXE) -- $(S)/dynloader/$(k) $(DESTDIR)$(SHLIB_SHAREDIR)/dynloader/$(k) \
	)

	$(_DOLINK) -- $(BINDIR_TO_SHAREDIR_RELPATH)/dynloader/runscript.bash \
		$(DESTDIR)$(BINDIR)/shlib-runscript$(SLOT_SUFFIX)

ifeq ($(_WANT_SLOT_SYM),1)
	$(_DOLINK) -- $(BINDIR_TO_SHAREDIR_RELPATH)/dynloader/runscript.bash \
		$(DESTDIR)$(BINDIR)/shlib-runscript
endif



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



$(O)/install-src.sh: $(X_GENINSTALL) FORCE
	mkdir -p $(@D)

	$< '$(SHLIB_LIB_SRC)' '$(DESTDIR)$(SHLIB_INCLUDEDIR)' \
		'-m $(INSMODE)' '' '-m $(DIRMODE)' > $@.make_tmp
	$(SHELL) -n $@.make_tmp
	mv -f -- $@.make_tmp $@


$(O)/%_wrapper: $(X_GENWRAPPER)
	mkdir -p $(@D)

	$< $* $(SHLIB_INCLUDEDIR) $(WRAPPER_SHLIBCC) $(WRAPPER_SHELL) > $@.make_tmp
	$(WRAPPER_SHELL) -n $@.make_tmp
	mv -f -- $@.make_tmp $@



FORCE:


.PHONY: $(PHONY)
