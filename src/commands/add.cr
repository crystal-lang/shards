require "./command"
require "../dependency"
require "../ext/yaml"

module Shards
  module Commands
    class Add < Command
      def run(*args)
        new_deps = {} of String => Hash(String, String)
        dep_type = Shards.dev? ? "development_dependencies" : "dependencies"

        new_deps = scan(args[0], dep_type)
        # compiled = {dep_type => spec.development_dependencies[0].merge(new_deps)}
        # puts compiled
        puts spec.development_dependencies
        # output = YAML.dump()
      end

      private def scan(path_set, dep_type : String)
        deps_set = {} of String => Hash(String, String)
        path_regex = /^((github|gitlab|bitbucket):)?((.+):)?([^\/]+)\/([^#]+)(#(.+))?$/
        version_regex = /([^@]+)(@(.+))/

        path_set.map do |path|
          if deps_info = path.match(path_regex).not_nil!
            platform = deps_info[2]? || "github"
            origin = deps_info[4]? || nil
            owner = deps_info[5]

            if name_version_match = deps_info[6].match(version_regex)
              deps_name = name_version_match[1]
              version = name_version_match[3]
            else
              deps_name = deps_info[6]
              version = nil
            end

            if deps_info[8]?
              if branch_ver = deps_info[8].match(version_regex)
                branch = branch_ver[1] || nil
                version = branch_ver[3] || nil
              end
            else
              branch = nil
              version = nil
            end

            repo = "#{owner}/#{deps_name}"
            deps_detail = {platform => repo, "branch" => branch, "version" => version}.compact

            if [owner, deps_name].includes?(nil)
              platform = "git"
              path = origin
            end

            if spec.development_dependencies[0].has_key?(deps_name)
              puts "#{deps_name} was already added to shards file."
            end

            deps_set = deps_set.merge({deps_name => deps_detail}).compact
          else
            puts "No match found."
          end
        end

        return deps_set
      end
    end
  end
end
