TOP=../..
include $(TOP)/mk/boilerplate.mk

# -----------------------------------------------------------------------------
# ghc-pkg.bin

SRC_HC_OPTS += -cpp -Wall -fno-warn-name-shadowing -fno-warn-unused-matches

# This causes libghccompat.a to be used:
include $(GHC_COMPAT_DIR)/compat.mk

SRC_HC_OPTS += $(PACKAGE_CABAL)

# This is required because libghccompat.a must be built with
# $(GhcHcOpts) because it is linked to the compiler, and hence
# we must also build with $(GhcHcOpts) here:
SRC_HC_OPTS += $(GhcHcOpts) $(GhcStage1HcOpts)

ifeq "$(ghc_ge_607)" "YES"
SRC_HC_OPTS += -package containers
endif

# On Windows, ghc-pkg is a standalone program
# ($bindir/ghc-pkg.exe), whereas on Unix it needs a wrapper script
# to pass the appropriate flag to the real binary
# ($libexecdir/ghc-pkg.bin) so that it can find package.conf.
ifeq "$(HOSTPLATFORM)" "i386-unknown-mingw32"
HS_PROG           = ghc-pkg.exe
INSTALL_PROGS    += $(HS_PROG)
else
HS_PROG           = ghc-pkg.bin
INSTALL_LIBEXECS += $(HS_PROG)
endif

# -----------------------------------------------------------------------------
# Create the Version.hs file

VERSION_HS = Version.hs
EXTRA_SRCS += $(VERSION_HS)

boot :: $(VERSION_HS)

Version.hs : Makefile $(TOP)/mk/config.mk
	@$(RM) -f $(VERSION_HS)
	@echo "Creating $(VERSION_HS) ... "
	@echo "module Version where" >>$(VERSION_HS)
	@echo "version, targetOS, targetARCH :: String" >>$(VERSION_HS)
	@echo "version    = \"$(ProjectVersion)\"" >> $(VERSION_HS)
	@echo "targetOS   = \"$(TargetOS_CPP)\"" >> $(VERSION_HS)
	@echo "targetARCH = \"$(TargetArch_CPP)\"" >> $(VERSION_HS)

DIST_CLEAN_FILES += $(VERSION_HS)

# -----------------------------------------------------------------------------
# ghc-pkg and ghc-pkg-inplace scripts

# ghc-pkg-inplace used to be either a /bin/sh script, or a .bat script
# on Windows.  It is now a real binary, compiled from a tiny .hs
# file.  The problem with using scripts here was that the .bat script
# cannot be executed by /bin/sh on MSYS (it can on Cygwin), but the
# /bin/sh script cannot be executed by Cabal.  So we would have needed
# both.  A single binary is therefore simpler.

INPLACE_HS=ghc-pkg-inplace.hs
INPLACE_PROG=ghc-pkg-inplace
EXCLUDED_SRCS+=$(INPLACE_HS)

$(INPLACE_HS): Makefile $(FPTOOLS_TOP)/mk/config.mk
	echo "import System.Cmd; import System.Environment; import System.Exit" > $@
	echo "main = do args <- getArgs; rawSystem \"$(FPTOOLS_TOP_ABS)/$(GHC_PKG_DIR_REL)/$(HS_PROG)\" (\"--global-conf\":\"$(FPTOOLS_TOP_ABS)/driver/package.conf.inplace\":args) >>= exitWith" >> $@

$(INPLACE_PROG): $(INPLACE_HS)
	$(HC) --make $< -o $@

all :: $(INPLACE_PROG)

CLEAN_FILES += $(INPLACE_HS) $(INPLACE_PROG)

ifneq "$(HOSTPLATFORM)" "i386-unknown-mingw32"
LINK = ghc-pkg
LINK_TARGET = $(LINK)-$(ProjectVersion)
INSTALLED_SCRIPT=$(DESTDIR)$(bindir)/$(LINK_TARGET)
install::
	$(INSTALL_DIR) $(DESTDIR)$(bindir)
	$(RM) -f $(INSTALLED_SCRIPT)
	echo "#!$(SHELL)"                                           >> $(INSTALLED_SCRIPT)
	echo "GHCPKGBIN=$(libexecdir)/$(HS_PROG)"                   >> $(INSTALLED_SCRIPT)
	echo "PKGCONF=$(libdir)/package.conf"                       >> $(INSTALLED_SCRIPT)
	echo 'exec $$GHCPKGBIN --global-conf $$PKGCONF $${1+"$$@"}' >> $(INSTALLED_SCRIPT)
	$(EXECUTABLE_FILE) $(INSTALLED_SCRIPT)
endif

# ghc-pkg is needed to boot in rts/ and library dirs
# Do a recursive 'make all' after generating dependencies, because this
# will work with 'make -j'.
ifneq "$(BootingFromHc)" "YES"
boot :: depend
	$(MAKE) all
endif

binary-dist:
	$(INSTALL_DIR)                $(BIN_DIST_DIR)/utils/ghc-pkg
	$(INSTALL_DATA)    Makefile   $(BIN_DIST_DIR)/utils/ghc-pkg/
	$(INSTALL_PROGRAM) $(HS_PROG) $(BIN_DIST_DIR)/utils/ghc-pkg/

include $(TOP)/mk/target.mk
