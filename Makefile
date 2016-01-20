CRYSTAL_BIN ?= $(shell which crystal)

VERSION := $(shell cat VERSION)
OS := $(shell uname -s | tr '[:upper:]' '[:lower:]')
ARCH := $(shell uname -m)

ifeq ($(OS),linux)
	CRFLAGS := --link-flags "-static -L/opt/crystal/embedded/lib"
endif

ifeq ($(OS),darwin)
	CRFLAGS := --link-flags "-L."
endif

SOURCES := $(shell find src -iname "*.cr") $(shell find src -iname "*.ecr")

# Builds an unoptimized binary.
all: bin/shards

bin/shards: $(SOURCES)
	$(CRYSTAL_BIN) build -o bin/shards src/shards.cr

# Builds an optimized static binary ready for distribution.
#
# On OS X the binary is only partially static (it depends on the system's
# dylib), but libyaml should be bundled, unless the linker can find
# libyaml.dylib
release:
	if [ "$(OS)" = "darwin" ] ; then \
	  cp /usr/local/lib/libyaml.a . ;\
	  chmod 644 libyaml.a ;\
	  export LIBRARY_PATH= ;\
	fi
	$(CRYSTAL_BIN) build --release -o bin/shards src/shards.cr $(CRFLAGS)
	gzip -c bin/shards > shards-$(VERSION)_$(OS)_$(ARCH).gz

clean:
	rm -rf .crystal bin/shards

.PHONY: test
test:
	make test_unit
	make test_integration

.PHONY: test_unit
test_unit:
	$(CRYSTAL_BIN) run test/*_test.cr -- --parallel=1

.PHONY: test_integration
test_integration: all
	$(CRYSTAL_BIN) run test/integration/*_test.cr -- --parallel=1

