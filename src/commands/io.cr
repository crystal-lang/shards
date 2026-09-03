module Shards
  module Commands
    def self.read_shard_yml : Array(String)
      begin
        File.read_lines("shard.yml")
      rescue
        Log.error{"No shard.yml was found in the current directory."}
        exit 1
      end
    end

    def self.write_shard_yml(lines : Array(String))
      File.write("shard.yml", lines.join("\n"))
    end 

    def self.git_url_to_dependency(url : String) : NamedTuple(name: String, repo: String, provider: String)
      hosts = {
        "github.com"   => "github",
        "gitlab.com"   => "gitlab",
        "codeberg.org" => "codeberg"
      }

      uri       = URI.parse(url)
      provider  = hosts[uri.host]?
      parts     = uri.path.split("/").reject(&.empty?)

      if parts.size < 2
        raise Error.new("Invalid git URL format")
      end
      if !provider
        provider = "github"
      end
      
      return {
        name: parts.last.gsub(".git", "").downcase, 
        repo: "#{parts[0]}/#{parts[1]}", 
        provider: provider
      }
    end
  end
end
