module Shards
  SPEC_FILENAME = "shard.yml"
  LOCK_FILENAME = "shard.lock"

  DEFAULT_COMMAND = "install"
  DEFAULT_VERSION = "0"

  def self.cache_path
    @@cache_path ||= ENV.fetch("SHARDS_CACHE_PATH") { File.join(Dir.current, ".shards") }
  end

  def self.cache_path=(@@cache_path : String)
  end

  def self.install_path
    @@install_path ||= begin
      warn_about_legacy_libs_path
      ENV.fetch("SHARDS_INSTALL_PATH") { File.join(Dir.current, "lib") }
    end
  end

  def self.install_path=(@@install_path : String)
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

  def self.bin_path
    @@bin_path ||= ENV.fetch("SHARDS_BIN_PATH") { File.join(Dir.current, "bin") }
  end

  def self.bin_path=(@@bin_path : String)
  end

  @@production = false

  def self.production?
    @@production
  end

  def self.production=(@@production)
  end
end
