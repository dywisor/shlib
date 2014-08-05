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


$(LOADER_LIB_BASEPATH).bash: $(LOADER_LIB_BASH_DEPS)
	mkdir -p -- $(@D)
	cat $^ > $@.make_tmp
	mv $@.make_tmp $@

$(LOADER_LIB_BASEPATH).sh: $(LOADER_LIB_SH_DEPS)
	mkdir -p -- $(@D)
	cat $^ > $@.make_tmp
	mv $@.make_tmp $@



.PHONY: $(PHONY)
