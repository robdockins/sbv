# (c) Copyright Levent Erkok. All rights reserved.
#
# The sbv library is distributed with the BSD3 license. See the LICENSE file
# in the distribution for details.

OS := $(shell uname)

GHCVERSION := $(shell ghc --version | awk '{print $$NF}')

ifeq ($(GHCVERSION), 8.0.1)
# GHC 8.0.1 (and possibly others) don't understand hide-source-paths and are picky about redundant constraints. Also,
# for this version use old style cabal comands.
CONFIGOPTS = "-Werror -Wall -Wno-redundant-constraints"
CBUILD=build
CINSTALL=install
CCONFIGURE=configure
CHADDOCK=haddock
CSDIST=sdist
else
CONFIGOPTS = "-Werror -Wall -fhide-source-paths"
CBUILD=new-build
CINSTALL=new-install
CCONFIGURE=new-configure
CHADDOCK=new-haddock
CSDIST=new-sdist
endif

SHELL := /usr/bin/env bash

export SBV_TEST_ENVIRONMENT := local

DOCTESTSOURCES := $(shell find Data/SBV -name "*.hs") $(shell find Documentation/SBV -name "*.hs")

ifeq ($(OS), Darwin)
# OSX tends to sleep for long jobs; so run through caffeinate
TIME        = /usr/bin/time caffeinate
NO_OF_CORES = `sysctl hw.ncpu | awk '{print $$2}'`
else
TIME        = /usr/bin/time
NO_OF_CORES = `grep -c "^processor" /proc/cpuinfo`
endif

.PHONY: install docs test release testPattern tags clean veryclean

all: quick

quick: tags
	@$(TIME) cabal $(CBUILD)
	@$(TIME) cabal $(CINSTALL) --force-reinstalls
	
install: tags
	@$(TIME) cabal $(CCONFIGURE) --enable-tests --ghc-options=$(CONFIGOPTS)
	@$(TIME) cabal $(CBUILD)
	@$(TIME) cabal $(CINSTALL) --force-reinstalls

docs:
	cabal $(CHADDOCK) --haddock-option=--hyperlinked-source --haddock-option=--no-warnings

test: lintTest docTest regularTests

lintTest:
	@$(TIME) ./dist/build/SBVHLint/SBVHLint

docTest:
	@$(TIME) doctest --fast --no-magic $(DOCTESTSOURCES)

regularTests:
	@$(TIME) ./dist/build/SBVTest/SBVTest --hide-successes -j $(NO_OF_CORES)

release: veryclean install docs test
	cabal $(CSDIST)
	@make -C buildUtils veryclean
	@make -C buildUtils
	buildUtils/testInterfaces
	buildUtils/checkLinks
	@echo "*** SBV is ready for release!"

# use this as follows:
#         make testPattern TGT=U2Bridge
testPattern:
	$(TIME) ./dist/build/SBVTest/SBVTest --hide-successes -p ${TGT}

# use this as follows:
#         make docTestPattern TGT=./Documentation/SBV/Examples/Puzzles/HexPuzzle.hs
docTestPattern:
	$(TIME) doctest --fast --no-magic --verbose ${TGT}

tags:
	@fast-tags -R --nomerge .

hlint: 
	@echo "Running HLint.."
	@hlint Data SBVTestSuite -i "Use otherwise" -i "Parse error" -i "Use fewer imports" -i "Use module export list" -i "Use import/export shortcut"

clean:
	@rm -rf dist

veryclean: clean
	@make -C buildUtils clean
	@-ghc-pkg unregister sbv
