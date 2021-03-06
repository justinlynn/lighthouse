# -----------------------------------------------------------------------------

TOP = ..
include $(TOP)/mk/boilerplate.mk

#
# Header files built from the configure script's findings
#
H_CONFIG   = ghcautoconf.h
H_PLATFORM = ghcplatform.h

#
# All header files
#
H_FILES = $(filter-out $(H_CONFIG) $(H_PLATFORM),$(wildcard *.h))

ifneq "$(DOING_BIN_DIST)" "YES"

#
# Options
#
ifeq "$(GhcUnregisterised)" "YES"
SRC_CC_OPTS += -DNO_REGS -DUSE_MINIINTERPRETER
endif

ifeq "$(GhcEnableTablesNextToCode) $(GhcUnregisterised)" "YES NO"
SRC_CC_OPTS += -DTABLES_NEXT_TO_CODE
endif

SRC_CC_OPTS += -I. -I../rts
ifeq "$(HaveLibGmp)" "YES"
ifneq "$(GMP_INCLUDE_DIRS)" ""
SRC_CC_OPTS += -I$(GMP_INCLUDE_DIRS)
endif
else
SRC_CC_OPTS += -I../gmp/gmpbuild
endif

ifneq "$(GhcWithSMP)" "YES"
SRC_CC_OPTS += -DNOSMP
endif

all :: $(H_CONFIG) $(H_PLATFORM)

# The fptools configure script creates the configuration header file and puts it
# in fptools/mk/config.h. We copy it down to here (without any PACKAGE_FOO
# definitions to avoid clashes), prepending some make variables specifying cpp
# platform variables.

ifneq "$(TARGETPLATFORM)"  "$(HOSTPLATFORM)"

$(H_CONFIG) :
	@echo "*** Cross-compiling: please copy $(H_CONFIG) from the target system"
	@exit 1

else

$(H_CONFIG) : $(FPTOOLS_TOP)/mk/config.h $(FPTOOLS_TOP)/mk/config.mk

$(H_CONFIG) : Makefile
	@echo "Creating $@..."
	@echo "#ifndef __GHCAUTOCONF_H__"  >$@
	@echo "#define __GHCAUTOCONF_H__" >>$@
#	Turn '#define PACKAGE_FOO "blah"' into '/* #undef PACKAGE_FOO */'.
	@sed 's,^\([	 ]*\)#[	 ]*define[	 ][	 ]*\(PACKAGE_[A-Z]*\)[	 ][ 	]*".*".*$$,\1/* #undef \2 */,' $(FPTOOLS_TOP)/mk/config.h >> $@
	@echo "#endif /* __GHCAUTOCONF_H__ */"          >> $@
	@echo "Done."

endif

$(H_PLATFORM) : Makefile
	@echo "Creating $@..."
	@$(RM) $@
	@echo "#ifndef __GHCPLATFORM_H__"  >$@
	@echo "#define __GHCPLATFORM_H__" >>$@
	@echo >> $@
	@echo "#define BuildPlatform_TYPE  $(HostPlatform_CPP)" >> $@
	@echo "#define HostPlatform_TYPE   $(TargetPlatform_CPP)" >> $@
	@echo >> $@
	@echo "#define $(HostPlatform_CPP)_BUILD  1" >> $@
	@echo "#define $(TargetPlatform_CPP)_HOST  1" >> $@
	@echo >> $@
	@echo "#define $(HostArch_CPP)_BUILD_ARCH  1" >> $@
	@echo "#define $(TargetArch_CPP)_HOST_ARCH  1" >> $@
	@echo "#define BUILD_ARCH  \"$(HostArch_CPP)\"" >> $@
	@echo "#define HOST_ARCH  \"$(TargetArch_CPP)\"" >> $@
	@echo >> $@
	@echo "#define $(HostOS_CPP)_BUILD_OS  1" >> $@
	@echo "#define $(TargetOS_CPP)_HOST_OS  1" >> $@
	@echo "#define BUILD_OS  \"$(HostOS_CPP)\"" >> $@
	@echo "#define HOST_OS  \"$(TargetOS_CPP)\"" >> $@
ifeq "$(HostOS_CPP)" "irix"
	@echo "#ifndef $(IRIX_MAJOR)_HOST_OS" >> $@  
	@echo "#define $(IRIX_MAJOR)_HOST_OS  1" >> $@  
	@echo "#endif" >> $@  
endif
	@echo >> $@
	@echo "#define $(HostVendor_CPP)_BUILD_VENDOR  1" >> $@
	@echo "#define $(TargetVendor_CPP)_HOST_VENDOR  1" >> $@
	@echo "#define BUILD_VENDOR  \"$(HostVendor_CPP)\"" >> $@
	@echo "#define HOST_VENDOR  \"$(TargetVendor_CPP)\"" >> $@
	@echo >> $@
	@echo "/* These TARGET macros are for backwards compatibily... DO NOT USE! */" >> $@
	@echo "#define TargetPlatform_TYPE $(TargetPlatform_CPP)" >> $@
	@echo "#define $(TargetPlatform_CPP)_TARGET  1" >> $@
	@echo "#define $(TargetArch_CPP)_TARGET_ARCH  1" >> $@
	@echo "#define TARGET_ARCH  \"$(TargetArch_CPP)\"" >> $@
	@echo "#define $(TargetOS_CPP)_TARGET_OS  1" >> $@  
	@echo "#define TARGET_OS  \"$(TargetOS_CPP)\"" >> $@
	@echo "#define $(TargetVendor_CPP)_TARGET_VENDOR  1" >> $@
	@echo >> $@
	@echo "#endif /* __GHCPLATFORM_H__ */"          >> $@
	@echo "Done."

# ---------------------------------------------------------------------------
# Make DerivedConstants.h for the compiler

all :: DerivedConstants.h

ifneq "$(TARGETPLATFORM)" "$(HOSTPLATFORM)"

DerivedConstants.h :
	@echo "*** Cross-compiling: please copy DerivedConstants.h from the target system"
	@exit 1

else

mkDerivedConstants.c : $(H_CONFIG) $(H_PLATFORM)

mkDerivedConstantsHdr : mkDerivedConstants.o
	$(CC) -o $@ $(CC_OPTS) $(LD_OPTS) mkDerivedConstants.o

DerivedConstants.h : mkDerivedConstantsHdr
	./mkDerivedConstantsHdr >$@

endif

CLEAN_FILES += mkDerivedConstantsHdr$(exeext) DerivedConstants.h

# -----------------------------------------------------------------------------
#

all :: GHCConstants.h

ifneq "$(TARGETPLATFORM)" "$(HOSTPLATFORM)"

GHCConstants.h :
	@echo "*** Cross-compiling: please copy DerivedConstants.h from the target system"
	@exit 1

else

mkGHCConstants : mkGHCConstants.o
	$(CC) -o $@ $(CC_OPTS) $(LD_OPTS) mkGHCConstants.o

mkGHCConstants.o : mkDerivedConstants.c
	$(CC) -o $@ $(CC_OPTS) -c $<  -DGEN_HASKELL

GHCConstants.h : mkGHCConstants
	./mkGHCConstants >$@

endif

CLEAN_FILES += mkGHCConstants$(exeext) GHCConstants.h

endif

# ---------------------------------------------------------------------------
# boot setup:
#
#
# Install all header files
#
# Note: we keep per-platform copies of all the include files
# (ditto for interface files). This is not *really* needed, but
# it gives (perhaps) a cleaner binary dist structure..might change.
#
INSTALL_HEADERS += $(H_FILES) $(H_CONFIG) $(H_PLATFORM)

binary-dist:
	$(INSTALL_DIR)                     $(BIN_DIST_DIR)/includes
	$(INSTALL_DATA) Makefile           $(BIN_DIST_DIR)/includes/
	$(INSTALL_DATA) $(INSTALL_HEADERS) $(BIN_DIST_DIR)/includes/

#
# `make clean' settings:
#
CLEAN_FILES += $(H_CONFIG) $(H_PLATFORM)

#
# Finally, slurp in the standard targets.
#
include $(TOP)/mk/target.mk

# We need DerivedConstants.h in order to make dependencies in the RTS
# sources, so 'make boot' here should behave like 'make all'.
#
# However, note that we should do this only *after* 'make boot' has
# created .depend in here; otherwise an out-of-date .depend file can
# prevent 'make boot' from working, requiring manual removal of
# .depend (see #1095).  This is why the following target comes *after*
# target.mk is included above (target.mk contains "boot :: depend").
#
boot :: all
