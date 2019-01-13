module Shards
  SPEC_FILENAME = "shard.yml"
  LOCK_FILENAME = "shard.lock"

  DEFAULT_COMMAND = "install"
  DEFAULT_VERSION = "0"

  VERSION_REFERENCE = /^v?\d+[-.][-.a-zA-Z\d]+$/
  VERSION_TAG = /^v(\d+[-.][-.a-zA-Z\d]+)$/

  class_property(cache_path : String) { find_or_create_cache_path }

  class_property(install_path : String) do
    warn_about_legacy_libs_path
    ENV.fetch("SHARDS_INSTALL_PATH") { File.join(Dir.current, "lib") }
  end

  class_property(bin_path : String) do
    ENV.fetch("SHARDS_BIN_PATH") { File.join(Dir.current, "bin") }
  end

  class_property? production = false

  private def self.find_or_create_cache_path
    candidates = [
      ENV["SHARDS_CACHE_PATH"]?,
      ENV["XDG_CACHE_HOME"]?.try { |cache| File.join(cache, "shards") },
      ENV["HOME"]?.try { |home| File.join(home, ".cache", "shards") },
      ENV["HOME"]?.try { |home| File.join(home, ".cache", ".shards") },
      File.join(Dir.current, ".shards"),
    ]

    candidates.each do |candidate|
      next unless candidate

      path = File.expand_path(candidate)
      return path if File.exists?(path)

      begin
        Dir.mkdir_p(path)
        return path
      rescue Errno
      end
    end

    raise Error.new("Failed to find or create cache directory")
  end

  private def self.warn_about_legacy_libs_path
    # TODO: drop me in a future release

    legacy_install_path = if path = ENV["SHARDS_INSTALL_PATH"]?
                            File.join(File.dirname(path), "libs")
                          else
                            File.join(Dir.current, "libs")
                          end

    if File.exists?(legacy_install_path)
      Shards.logger.warn "Shards now installs dependencies into the 'lib' folder. You may delete the legacy 'libs' folder."
    end
  end
end
