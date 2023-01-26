require "./lock"

class Shards::Info
  getter install_path : String
  getter installed = Hash(String, Package).new

  def initialize(@install_path = Shards.install_path)
    reload
  end

  def reload
    path = info_path
    if File.exists?(path)
      @installed = Lock.from_file(path).shards.index_by &.name
    else
      @installed.clear
    end
  end

  def save
    Dir.mkdir_p(@install_path)

    unless File.exists?(info_path)
      Dir.each_child(@install_path) do |name|
        if name.ends_with?(".sha1")
          File.delete(File.join(@install_path, name))
        end
      end
    end

    File.open(info_path, "w") do |file|
      YAML.build(file) do |yaml|
        yaml.mapping do
          yaml.scalar "version"
          yaml.scalar "1.0"

          yaml.scalar "shards"
          yaml.mapping do
            installed.each do |_, dep|
              dep.to_yaml(yaml)
            end
          end
        end
      end
    end
  end

  def info_path
    File.join(@install_path, ".shards.info")
  end
end
