S := $(CURDIR)
O := $(S)
SRCDIR := $(S)/src

LOADER_LIB_BASEPATH := $(O)/dynloader

LOADER_LIB_BASH_DEP_NAMES := $(shell cat $(SRCDIR)/DEPEND)

ifeq ($(LOADER_LIB_BASH_DEP_NAMES),)
$(error "empty dep list")
endif



LOADER_LIB_BASH_DEPS := \
	$(foreach k,$(LOADER_LIB_BASH_DEP_NAMES),$(SRCDIR)/$(k:./%=%))

LOADER_LIB_SH_DEPS   := \
	$(foreach k,$(LOADER_LIB_BASH_DEPS),$(k:%.bash=%.sh))



LOADER_LIBS := $(addprefix $(LOADER_LIB_BASEPATH).,bash)


PHONY :=

PHONY += all
all: $(LOADER_LIBS)

PHONY += clean
clean:
	rm -f -- $(wildcard $(O)/*.make_tmp) $(LOADER_LIBS)

PHONY += install
install:
ifeq ($(HAVE_SHLIB_INSTALL_VARS),)
	$(error install target must not be run directly)
endif

	$(_DODIR) -- $(DESTDIR)$(SHLIB_SHAREDIR)/dynloader $(DESTDIR)$(BINDIR)

	true $(foreach k,\
		$(addprefix $(S)/,runscript.bash runscript-wrapper.bash) \
		$(O)/dynloader.bash,\
		\
		&& $(_DOEXE) -- $(k) \
			$(DESTDIR)$(SHLIB_SHAREDIR)/dynloader/$(notdir $(k)) \
	)

	$(_DOLINK) -- $(BINDIR_TO_SHAREDIR_RELPATH)/dynloader/runscript.bash \
		$(DESTDIR)$(BINDIR)/shlib-runscript$(SLOT_SUFFIX)

ifeq ($(_WANT_SLOT_SYM),1)
	$(_DOLINK) -- $(BINDIR_TO_SHAREDIR_RELPATH)/dynloader/runscript.bash \
		$(DESTDIR)$(BINDIR)/shlib-runscript
endif






$(LOADER_LIB_BASEPATH).bash: $(LOADER_LIB_BASH_DEPS)
	mkdir -p -- $(@D)
	cat $^ > $@.make_tmp
	mv $@.make_tmp $@

$(LOADER_LIB_BASEPATH).sh: $(LOADER_LIB_SH_DEPS)
	mkdir -p -- $(@D)
	cat $^ > $@.make_tmp
	mv $@.make_tmp $@




.PHONY: $(PHONY)
