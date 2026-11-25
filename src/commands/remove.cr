require "./command"
require "./io"

module Shards
  module Commands
    class Remove < Command
      def run(url : String)
        dep = Commands.git_url_to_dependency(url)
        Log.info{"Removing dependency: #{dep[:name]}"}

        lines = Commands.read_shard_yml
        dependencies_index = -1

        lines.each_with_index do |line, index|
          if line =~ /^(\s*)dependencies\s*:/
            dependencies_index = index
            break
          end
        end

        if dependencies_index == -1
          Log.warn{"Dependency #{dep[:name]} not found, nothing to remove."}
          return
        end

        dep_name = dep[:name]
        dep_start_index = -1
        dep_end_index = -1
        dep_indentation = nil

        (dependencies_index + 1).upto(lines.size - 1) do |i|
            break if i >= lines.size || (lines[i] =~ /^\S/ && !lines[i].starts_with?("#"))

            if lines[i] =~ /^(\s+)#{Regex.escape(dep_name)}\s*:/
                dep_start_index = i
                dep_indentation = $1.size

                j = i + 1
                while j < lines.size
                    if !lines[j].empty? && !lines[j].starts_with?("#") && lines[j] =~ /^(\s*)\S/
                        current_indent = $1.size
                        if current_indent <= dep_indentation
                            break
                        end
                        dep_end_index = j
                    end
                    j += 1
                end

                break
            end
        end

        if dep_start_index != -1
          if dep_end_index != -1
            lines.delete_at(dep_start_index..dep_end_index)
          else
            lines.delete_at(dep_start_index)
          end

          has_other_deps = false
          (dependencies_index + 1).upto(lines.size - 1) do |i|
            break if i >= lines.size || (lines[i] =~ /^\S/ && !lines[i].starts_with?("#"))
            if lines[i] =~ /^\s+\S+\s*:/
              has_other_deps = true
              break
            end
          end

          if !has_other_deps
            lines.delete_at(dependencies_index)
          end

          Commands.write_shard_yml(lines)
          Commands::Prune.new(path).run

          Log.info{"Removed dependency #{dep[:name]}."}
        else
          Log.warn{"Dependency: #{dep[:name]} not found, nothing to remove."}
        end
      end
    end
  end
end