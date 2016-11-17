require "./command"
require "ecr/macros"

module Shards
  module Commands
    class Init < Command
      def run(*args)
        if File.exists?(shard_path)
          raise Error.new("#{ SPEC_FILENAME } already exists")
        end

        File.write(shard_path, String.build do |__str__|
          ECR.embed "#{ __DIR__ }/../templates/shard.yml.ecr", "__str__"
        end)

        Shards.logger.info "Created #{ SPEC_FILENAME }"
      end

      private def name
        File.basename(path)
          .gsub(/[^-_a-zA-Z0-9]+/, '-')
          .gsub("crystal", "")
          .gsub(/[-_]{2,}/, '-')
          .gsub(/^[-_]|[-_]$/, "")
      end

      private def version
        "0.1.0"
      end

      private def shard_path
        File.join(path, Shards::SPEC_FILENAME)
      end
    end
  end
end
