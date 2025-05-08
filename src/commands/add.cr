require "./command"
require "./io"

module Shards
  module Commands
    class Add < Command
      def run(urls : Array(String), version : String? = nil)
        spec_path = File.join(path, SPEC_FILENAME)
        raise Error.new("#{SPEC_FILENAME} not found") unless File.exists?(spec_path)
      
        urls.each do |url|
          dep = Commands.git_url_to_dependency(url)
          Log.info { "Adding dependency: #{dep[:name]} from #{dep[:provider]}: #{dep[:repo]}" }
          
          lines = File.read_lines(spec_path)
          dependencies_index = -1
          dependencies_indentation = ""

          lines.each_with_index do |line, index|
            if line =~ /^(\s*)dependencies\s*:/
              dependencies_index = index
              dependencies_indentation = $1
              break
            end
          end

          if dependencies_index == -1
            lines << "" if lines.last != ""
            lines << "dependencies:"
            dependencies_index = lines.size - 1
            dependencies_indentation = ""
          end

          dep_name = dep[:name]
          dep_start_index = -1
          dep_end_index = -1

          (dependencies_index + 1).upto(lines.size - 1) do |i|
            break if i >= lines.size || lines[i] =~ /^\S/ && !lines[i].starts_with?("#")
            if lines[i] =~ /^\s+#{Regex.escape(dep_name)}\s*:/
              dep_start_index = i

              j = i + 1
              while j < lines.size && (lines[j].empty? || lines[j].starts_with?("#") || lines[j] =~ /^\s+/)
                if lines[j] =~ /^(\s+)/ && $1.size > lines[i].index(/\S/).not_nil!
                  dep_end_index = j
                end
                j += 1
              end

              break
            end
          end

          dep_indentation   = "#{dependencies_indentation}  "
          prop_indentation  = "#{dependencies_indentation}    "
          dep_lines         = ["#{dep_indentation}#{dep_name}:"]

          dep_lines << "#{prop_indentation}#{dep[:provider]}: #{dep[:repo]}"
          dep_lines << "#{prop_indentation}version: #{version}" if version

          if dep_start_index != -1
            lines.delete_at(dep_start_index..dep_end_index)
            dep_lines.each_with_index do |line, idx|
              lines.insert(dep_start_index + idx, line)
            end
          else
            insert_index = dependencies_index + 1

            while insert_index < lines.size &&
                  (lines[insert_index].empty? ||
                  lines[insert_index].starts_with?("#") ||
                  lines[insert_index] =~ /^\s+/)
              insert_index += 1
            end

            dep_lines.each_with_index do |line, idx|
              lines.insert(insert_index + idx, line)
            end
          end

          File.write(spec_path, lines.join("\n"))
          Log.info { "Added dependency #{dep[:name]} from #{dep[:provider]}: #{dep[:repo]}#{version ? " with version #{version}" : ""}" }
        end
        
        Commands::Lock.new(path).run([] of String)
        Commands::Install.new(path).run
      end

    end
  end
end