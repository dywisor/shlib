S := $(CURDIR)
O := $(S)

ifeq ($(HAVE_SHLIB_INSTALL_VARS),1)
STATICLOADER_DIR          = $(SHLIB_SHAREDIR:/=)/staticloader
STATICLOADER_MODULES_ROOT = $(SHLIB_INCLUDEDIR)
STATICLOADER_FUNCTIONS    = $(SHLIB_STATICLOADER_DIR)/functions.sh
#STATICLOADER_PRELINKED_ROOT =
#STATICLOADER_PRELINK_SUFFIX =
endif



PHONY :=

PHONY += all
all: $(O)/runscript.sh

PHONY += clean
clean:
	rm -f -- $(wildcard $(O)/*.make_tmp) $(O)/runscript.sh

PHONY += install
install:
ifeq ($(HAVE_SHLIB_INSTALL_VARS),)
	$(error install target must not be run directly)
endif

	$(_DODIR) -- $(DESTDIR)$(STATICLOADER_DIR) $(DESTDIR)$(BINDIR)

	$(_DOINS) -- $(S)/functions.sh $(DESTDIR)$(STATICLOADER_DIR)/functions.sh
	$(_DOEXE) -- $(O)/runscript.sh $(DESTDIR)$(STATICLOADER_DIR)/runscript.sh

# cannot install both dynloader and staticloader
	$(_DOLINK) -- $(BINDIR_TO_SHAREDIR_RELPATH)/staticloader/runscript.sh \
		$(DESTDIR)$(BINDIR)/shlib-runscript$(SLOT_SUFFIX)

ifeq ($(_WANT_SLOT_SYM),1)
	$(_DOLINK) -- $(BINDIR_TO_SHAREDIR_RELPATH)/staticloader/runscript.sh \
		$(DESTDIR)$(BINDIR)/shlib-runscript
endif


$(O)/%.sh: $(O)/%.sh.make_tmp
	mv -f -- '$<' '$@'

$(O)/runscript.sh.make_tmp: $(S)/runscript.sh.in FORCE
ifeq ($(STATICLOADER_PRELINKED_ROOT),)
	$(error STATICLOADER_PRELINKED_ROOT not set.)
endif
ifeq ($(STATICLOADER_MODULES_ROOT),)
	$(error STATICLOADER_MODULES_ROOT not set.)
endif
ifeq ($(STATICLOADER_PRELINK_SUFFIX),)
	$(error STATICLOADER_PRELINK_SUFFIX not set.)
endif
ifeq ($(STATICLOADER_FUNCTIONS),)
	$(error STATICLOADER_FUNCTIONS not set.)
endif

	mkdir -p -- '$(@D)'
	< "$<" > "$@" sed \
		$(foreach name,PRELINKED_ROOT MODULES_ROOT PRELINK_SUFFIX FUNCTIONS,\
			-e 's|@@SHLIB_STATICLOADER_$(name)@@|$(STATICLOADER_$(name))|g') \


FORCE:

.PHONY: $(PHONY)
