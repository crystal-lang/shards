module Shards
  class PathResolver < Resolver
    def read_spec(version = nil)
      File.read(File.join(local_path, SPEC_FILENAME))
    end

    def available_versions
      [spec.version]
    end

    def local_path
      dependency["path"].to_s
    end
  end

  register_resolver :path, PathResolver
end
