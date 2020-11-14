Spec.before_each do
  path = application_path

  if File.exists?(path)
    Shards::Helpers::Files.rm_rf_children(path)
  else
    Dir.mkdir_p(path)
  end
end

def with_shard(metadata, lock = nil, override = nil)
  Dir.cd(application_path) do
    File.write "shard.yml", to_shard_yaml(metadata)
    File.write "shard.lock", to_lock_yaml(lock) if lock
    File.write "shard.override.yml", to_override_yaml(override) if override
    yield
  end
end

def to_shard_yaml(metadata)
  String.build do |yml|
    yml << "name: " << (metadata[:name]? || "test").inspect << '\n'
    yml << "version: " << (metadata[:version]? || "0.0.0").inspect << '\n'

    metadata.each do |key, value|
      if key.to_s.ends_with?("dependencies")
        write_dependencies(yml, key, value)
      elsif key.to_s == "targets"
        yml << "targets:\n"
        if value.responds_to?(:each)
          value.each do |target, info|
            yml << "  " << target.to_s << ":\n"
            if info.responds_to?(:each)
              info.each do |main, src|
                yml << "    main: " << src.inspect << '\n'
              end
            end
          end
        end
      end
    end
  end
end

def to_override_yaml(metadata)
  String.build do |yml|
    metadata.each do |key, value|
      if key.to_s == "dependencies"
        write_dependencies(yml, key, value)
      end
    end
  end
end

# This is used for dependencies and development_dependencies
private def write_dependencies(yml, key, value)
  yml << key << ':'

  if value.responds_to?(:each)
    yml << '\n'
    value.each do |name, version|
      yml << "  " << name << ":\n"

      case version
      when String
        yml << "    git: " << git_url(name).inspect << '\n'
        yml << "    version: " << version.inspect << '\n' unless version == "*"
        # when Hash
        #  version.each do |k, v|
        #    yml << "    " << k << ": " << v.inspect << '\n'
        #  end
      when NamedTuple
        version.each do |k, v|
          yml << "    " << k.to_s << ": " << v.inspect << '\n'
        end
      else
        yml << "    git: " << git_url(name).inspect << '\n'
      end
    end
  else
    yml << value
  end
end

def to_lock_yaml(lock)
  return unless lock

  YAML.dump({
    version: Shards::Lock::CURRENT_VERSION,
    shards:  lock.to_a.to_h do |name, data|
      if data.is_a?(NamedTuple)
        git = data[:git]
        version = data[:version]
      else
        git = git_url(name)
        version = data
      end
      {name, {git: git, version: version}}
    end,
  })
end

module Shards::Specs
  @@application_path : String?

  def self.application_path
    @@application_path ||= File.expand_path("../../tmp/integration", __DIR__).tap do |path|
      if File.exists?(path)
        Shards::Helpers::Files.rm_rf_children(path)
      else
        Dir.mkdir_p(path)
      end
    end
  end
end

def application_path
  Shards::Specs.application_path
end
