require "./command"

module Shards
  module Commands
    class Remove < Command
      def self.run(*dependencies)
        new_deps = {} of String => Hash(String, String)
        new_deps = deps_hash.reject(args.packages)
        compiled_deps = {dep_type => new_deps}
        output = YAML.dump(parsed_shard_file.as_h.merge(compiled_deps)).gsub("---\n", "")
        File.write(detect_shard_file, output)
        FileUtils.rm_rf(dependencies.map! { |deps| "lib/" + pkgs })
      end
    end
  end
end
