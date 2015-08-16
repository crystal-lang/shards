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
test:
	$(CRYSTAL_BIN) run test/*_test.cr

