SHLIBCC = ./CC
SHLIBCCFLAGS = --as-lib --strip-virtual

shlib: $(SHLIBCC)
#	$(SHLIBCC) $(SHLIBCCFLAGS) all > ./shlib_$(shell git rev-parse --verify HEAD).sh
	$(SHLIBCC) $(SHLIBCCFLAGS) all > ./shlib_$(shell date +%F).sh

.PHONY: shlib
