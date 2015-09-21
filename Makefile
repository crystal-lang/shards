ifndef CRYSTAL_BIN
	CRYSTAL_BIN := $(shell which crystal)
endif

VERSION := $(shell cat VERSION)
OS := $(shell uname -s | tr '[:upper:]' '[:lower:]')
ARCH := $(shell uname -m)

ifeq ($(OS),linux)
	RELEASE_CRFLAGS  --link-flags "-static -L/opt/crystal/embedded/lib"
endif
ifeq ($(OS),darwin)
	CRFLAGS := --link-flags "-L/usr/local/lib"
endif

all:
	$(CRYSTAL_BIN) build -o bin/shards src/shards.cr $(CRFLAGS)

release:
	$(CRYSTAL_BIN) build --release -o bin/shards src/shards.cr $(RELEASE_CRFLAGS) $(CRFLAGS)

tarball: release
	tar zcf shards-$(VERSION)_$(OS)_$(ARCH).tar.gz -C bin shards

.PHONY: test
test: test_unit test_integration

.PHONY: test_unit
test_unit:
	$(CRYSTAL_BIN) run test/*_test.cr

.PHONY: test_integration
test_integration: all
	$(CRYSTAL_BIN) run test/integration/*_test.cr

