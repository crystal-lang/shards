ifndef CRYSTAL_BIN
	CRYSTAL_BIN = crystal
endif

all:
	$(CRYSTAL_BIN) build -o bin/shards src/shards.cr

release:
	$(CRYSTAL_BIN) build --release -o bin/shards src/shards.cr --link-flags "-static -L/opt/crystal/embedded/lib"
