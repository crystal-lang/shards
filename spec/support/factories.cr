class FailedCommand < Exception
  getter stdout : String
  getter stderr : String

  def initialize(message, @stdout, @stderr)
    super "#{message}: #{stdout} -- #{stderr}"
  end
end

def create_path_repository(project, version = nil)
  Dir.mkdir_p(File.join(git_path(project), "src"))
  File.write(File.join(git_path(project), "src", "#{project}.cr"), "module #{project.capitalize}\nend")
  create_shard project, version if version
end

def create_git_repository(project, *versions)
  Dir.cd(tmp_path) do
    run "git init #{Process.quote(project)}"
    Dir.cd(Process.quote(project)) do
       run "git checkout --orphan master"
    end
  end

  Dir.mkdir(File.join(git_path(project), "src"))
  File.write(File.join(git_path(project), "src", "#{project}.cr"), "module #{project.capitalize}\nend")

  Dir.cd(git_path(project)) do
    run "git add #{Process.quote("src/#{project}.cr")}"
  end

  versions.each { |version| create_git_release project, version }
end

def create_fork_git_repository(project, upstream)
  Dir.cd(tmp_path) do
    run "git clone #{Process.quote(git_url(upstream))} #{Process.quote(project)}"
  end
end

def create_git_version_commit(project, version, shard : Bool | NamedTuple = true)
  Dir.cd(git_path(project)) do
    if shard
      contents = shard.is_a?(NamedTuple) ? shard : nil
      create_shard project, version, contents
    end
    Dir.cd(git_path(project)) do
      name = shard[:name]? if shard.is_a?(NamedTuple)
      name ||= project
      File.touch "src/#{name}.cr"
      run "git add #{Process.quote("src/#{name}.cr")}"
    end
    create_git_commit project, "release: v#{version}"
  end
end

def create_git_release(project, version, shard : Bool | NamedTuple = true)
  create_git_version_commit(project, version, shard)
  create_git_tag(project, "v#{version}")
end

def create_git_tag(project, version)
  Dir.cd(git_path(project)) do
    run "git tag --no-sign #{Process.quote(version)}"
  end
end

def create_git_commit(project, message = "new commit")
  Dir.cd(git_path(project)) do
    run "git add ."
    run "git commit --allow-empty --no-gpg-sign -m #{Process.quote(message)}"
  end
end

def checkout_new_git_branch(project, branch)
  Dir.cd(git_path(project)) do
    run "git checkout -b #{Process.quote(branch)}"
  end
end

def checkout_git_branch(project, branch)
  Dir.cd(git_path(project)) do
    run "git checkout #{Process.quote(branch)}"
  end
end

def create_shard(project, version, contents : NamedTuple? = nil)
  spec = {name: project, version: version, crystal: Shards.crystal_version}
  spec = spec.merge(contents) if contents
  create_file project, "shard.yml", spec.to_yaml
end

def create_file(project, filename, contents)
  path = File.join(git_path(project), filename)
  parent = File.dirname(path)
  Dir.mkdir_p(parent) unless Dir.exists?(parent)
  File.write(path, contents)
  path
end

def create_executable(project, filename, source)
  path = create_file(project, filename + ".cr", source)
  Dir.cd(File.dirname(path)) do
    run "crystal build #{Process.quote(File.basename(path))}"
  end
  File.delete(path)
end

def git_commits(project, rev = "HEAD")
  Dir.cd(git_path(project)) do
    run("git log --format=%H #{Process.quote(rev)}").strip.split('\n')
  end
end

def git_url(project)
  "file://#{Path[git_path(project)].to_posix}"
end

def git_path(project)
  File.join(tmp_path, project.to_s)
end

def rel_path(project)
  "../../spec/.repositories/#{project}"
end

module Shards::Specs
  @@tmp_path : String?

  def self.tmp_path
    @@tmp_path ||= begin
      path = File.expand_path("../../.repositories", __FILE__)
      Dir.mkdir(path) unless Dir.exists?(path)
      path
    end
  end

  @@crystal_path : String?

  def self.crystal_path
    # Memoize so each integration spec do not need to create this process.
    # If crystal is bin/crystal this also reduce the noise of Using compiled compiler at ...
    @@crystal_path ||= "#{Shards::INSTALL_DIR}#{Process::PATH_DELIMITER}#{`crystal env CRYSTAL_PATH`.chomp}"
  end
end

def tmp_path
  Shards::Specs.tmp_path
end

def run(command, *, env = nil)
  cmd_env = {
    "CRYSTAL_PATH" => Shards::Specs.crystal_path,
  }
  cmd_env.merge!(env) if env
  output, error = IO::Memory.new, IO::Memory.new
  {% if flag?(:win32) %}
    # FIXME: Concurrent streams are currently broken on Windows. Need to drop one for now.
    error = nil
  {% end %}
  status = Process.run(command, shell: true, env: cmd_env, output: output, error: error || Process::Redirect::Close)

  if status.success?
    output.to_s.gsub("\r\n", "\n")
  else
    raise FailedCommand.new("command failed: #{command}", output.to_s.gsub("\r\n", "\n"), error.to_s.gsub("\r\n", "\n"))
  end
end
