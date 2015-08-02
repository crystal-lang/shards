require "option_parser"
require "./commands/*"
require "./groups"

module Shards
  def self.display_help_and_exit(opts)
    puts "shards [options] <command>"
    puts
    puts "Commands:"
    puts "    check"
    #puts "    info <package>"
    puts "    install"
    #puts "    search <query>"
    puts "    update"
    #puts "    update [package package ...]"
    puts
    puts "Options:"
    puts opts
    exit
  end
end

begin
  groups = Shards::Groups.new(Shards::DEFAULT_GROUPS.size)
  groups.with(Shards::DEFAULT_GROUPS)

  OptionParser.parse! do |opts|
    opts.on("--no-colors", "") { Shards.colors = false }
    opts.on("--version", "") { puts Shards.version_string; exit }
    opts.on("-v", "--verbose", "") { Shards.logger.level = Logger::Severity::DEBUG }
    opts.on("-q", "--quiet", "") { Shards.logger.level = Logger::Severity::WARN }
    opts.on("-h", "--help", "") { Shards.display_help_and_exit(opts) }

    opts.on("--without=GROUPS", "comma separated list of groups to skip") { |g| groups.without(g.split(',')) }
    opts.on("--with=GROUPS", "comma separated list of groups to install (defaults to 'development')") { |g| groups.with(g.split(',')) }

    opts.unknown_args do |args, options|
      case args[0]? || Shards::DEFAULT_COMMAND
      when "check"
        Shards::Commands.check(groups: groups)
      #when "info"
      #  Shards.display_help_and_exit(opts) unless args[1]?
      #  Shards::Commands.info(args[1])
      when "install"
        p groups
        Shards::Commands.install(groups: groups)
      when "update"
        Shards::Commands.update(groups: groups)
        #Shards::Commands.update(*args[1 .. -1], groups: groups)
      #when "search"
      #  Shards.display_help_and_exit(opts) unless args[1]?
      #  Shards::Commands.search(args[1])
      else
        Shards.display_help_and_exit(opts)
      end
    end
  end

rescue ex : OptionParser::InvalidOption
  Shards.logger.fatal ex.message
  exit -1

rescue ex : Shards::Error
  Shards.logger.error ex.message
  exit -1
end
