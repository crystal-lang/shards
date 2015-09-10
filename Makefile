ifndef CRYSTAL_BIN
	CRYSTAL_BIN := $(shell which crystal)
endif

VERSION := $(shell cat VERSION)

all:
	$(CRYSTAL_BIN) build -o bin/shards src/shards.cr

release:
	$(CRYSTAL_BIN) build --release -o bin/shards src/shards.cr --link-flags "-static -L/opt/crystal/embedded/lib"
	tar zcf shards-$(VERSION)_linux_amd64.tar.gz -C bin shards

.PHONY: test
test: test_unit test_integration

.PHONY: test_unit
test_unit:
	$(CRYSTAL_BIN) run test/*_test.cr

.PHONY: test_integration
test_integration: all
	$(CRYSTAL_BIN) run test/integration/*_test.cr

