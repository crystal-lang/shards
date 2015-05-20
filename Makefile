CRYSTAL_BIN = crystal

all:
	$(CRYSTAL_BIN) build -o bin/shards src/shards.cr

release:
	$(CRYSTAL_BIN) build --release -o bin/shards src/shards.cr
