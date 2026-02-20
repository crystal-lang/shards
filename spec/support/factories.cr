require "../../src/ext/capture"

def create_path_repository(project, version = nil)
  Dir.mkdir_p(File.join(git_path(project), "src"))
  File.write(File.join(git_path(project), "src", "#{project}.cr"), "module #{project.capitalize}\nend")
  create_shard project, version if version
end

def create_git_repository(project, *versions)
  Dir.cd(tmp_path) do
    capture %w[git init] << project
    Dir.cd(git_path(project)) do
      capture %w[git checkout --orphan master]

      capture %w[git config user.email author@example.com]
      capture %w[git config user.name Author]
    end
  end

  Dir.mkdir(File.join(git_path(project), "src"))
  File.write(File.join(git_path(project), "src", "#{project}.cr"), "module #{project.capitalize}\nend")

  Dir.cd(git_path(project)) do
    capture %w[git add] << "src/#{project}.cr"
  end

  versions.each { |version| create_git_release project, version }
end

def create_fork_git_repository(project, upstream)
  Dir.cd(tmp_path) do
    capture %w[git clone] << git_url(upstream) << project

    Dir.cd(git_path(project)) do
      capture %w[git config user.email fork@example.com]
      capture %w[git config user.name Fork]
    end
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
      capture %w[git add] << "src/#{name}.cr"
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
    capture %w[git tag --no-sign] << version
  end
end

def create_git_commit(project, message = "new commit")
  Dir.cd(git_path(project)) do
    capture %w[git add .]
    capture %w[git commit --allow-empty --no-gpg-sign -m] << message
  end
end

def checkout_new_git_branch(project, branch)
  Dir.cd(git_path(project)) do
    capture %w[git checkout -b] << branch
  end
end

def checkout_git_branch(project, branch)
  Dir.cd(git_path(project)) do
    capture %w[git checkout] << branch
  end
end

def create_hg_repository(project, *versions)
  Dir.cd(tmp_path) do
    capture %w[hg init] << project
  end

  Dir.mkdir(File.join(hg_path(project), "src"))
  File.write(File.join(hg_path(project), "src", "#{project}.cr"), "module #{project.capitalize}\nend")

  Dir.cd(hg_path(project)) do
    capture %w[hg add] << "src/#{project}.cr"
  end

  versions.each { |version| create_hg_release project, version }
end

def create_fork_hg_repository(project, upstream)
  Dir.cd(tmp_path) do
    capture %w[hg clone] << hg_url(upstream) << project
  end
end

def create_hg_version_commit(project, version, shard : Bool | NamedTuple = true)
  Dir.cd(hg_path(project)) do
    if shard
      contents = shard.is_a?(NamedTuple) ? shard : nil
      create_shard project, version, contents
    end
    Dir.cd(hg_path(project)) do
      name = shard[:name]? if shard.is_a?(NamedTuple)
      name ||= project
      File.touch "src/#{name}.cr"
      capture %w[hg add] << "src/#{name}.cr"
    end
    create_hg_commit project, "release: v#{version}"
  end
end

def create_hg_release(project, version, shard : Bool | NamedTuple = true)
  create_hg_version_commit(project, version, shard)
  create_hg_tag(project, "v#{version}")
end

def create_hg_tag(project, version)
  Dir.cd(hg_path(project)) do
    capture %w[hg tag -u] << "Your Name <you@example.com>" << version
  end
end

def create_hg_commit(project, message = "new commit")
  Dir.cd(hg_path(project)) do
    File.write("src/#{project}.cr", "# #{message}", mode: "a")
    capture ["hg", "commit", "-u", "Your Name <you@example.com>", "-A", "-m", message]
  end
end

def checkout_new_hg_bookmark(project, branch)
  Dir.cd(hg_path(project)) do
    capture %w[hg bookmark] << branch
  end
end

def checkout_new_hg_branch(project, branch)
  Dir.cd(hg_path(project)) do
    capture %w[hg branch] << branch
  end
end

def checkout_hg_rev(project, rev)
  Dir.cd(hg_path(project)) do
    capture %w[hg update -C] << rev
  end
end

def create_fossil_repository(project, *versions)
  Dir.cd(tmp_path) do
    capture %w[fossil init] << "#{project}.fossil"

    # Use a workaround so we don't use --workdir in case the specs are capture on a
    # machine with an old Fossil version.  See the #install_sources method in
    # src/resolvers/fossil.cr
    Dir.mkdir(fossil_path(project)) unless Dir.exists?(fossil_path(project))
    Dir.cd(fossil_path(project)) do
      capture %w[fossil open] << "#{File.join(tmp_path, project)}.fossil"
    end
  end

  Dir.mkdir(File.join(fossil_path(project), "src"))
  File.write(File.join(fossil_path(project), "src", "#{project}.cr"), "module #{project.capitalize}\nend")

  Dir.cd(fossil_path(project)) do
    capture %w[fossil add] << "src/#{project}.cr"
  end

  versions.each { |version| create_fossil_release project, version, tag: "v#{version}" }
end

def create_fossil_release(project, version, shard : Bool | NamedTuple = true, tag : String? = nil)
  create_fossil_version_commit(project, version, shard, tag)
end

def create_fossil_version_commit(project, version, shard : Bool | NamedTuple = true, tag : String? = nil)
  Dir.cd(fossil_path(project)) do
    if shard
      contents = shard.is_a?(NamedTuple) ? shard : nil
      create_shard project, version, contents
    end

    name = shard[:name]? if shard.is_a?(NamedTuple)
    name ||= project
    File.touch "src/#{name}.cr"
    capture %w[fossil addremove]

    create_fossil_commit project, "release: v#{version}", tag
  end
end

def create_fossil_commit(project, message = "new commit", tag : String? = nil)
  Dir.cd(fossil_path(project)) do
    File.write("src/#{project}.cr", "# #{message}", mode: "a")
    capture %w[fossil addremove]

    # Use --hash here to work around a file that's changed, but the size and
    # mtime are the same.  Depending on the resolution of mtime on the
    # underlying filesystem, shard.yml may fall into this edge case during
    # testing.
    #
    # https://fossil-users.fossil-scm.narkive.com/9ybRAo1U/error-file-is-different-on-disk-compared-to-the-repository-during-commti
    if tag
      capture %w[fossil commit --hash --tag] << tag << "-m" << message
    else
      capture %w[fossil commit --hash -m] << message
    end
  end
end

def create_fork_fossil_repository(project, upstream)
  Dir.cd(tmp_path) do
    capture %w[fossil clone] << fossil_url(upstream) << project
  end
end

def create_fossil_tag(project, version)
  Dir.cd(fossil_path(project)) do
    capture %w[fossil tag add] << version << "current"
  end
end

def checkout_new_fossil_branch(project, branch)
  Dir.cd(fossil_path(project)) do
    capture %w[fossil branch new] << branch << "current"
    capture %w[fossil checkout branch]
  end
end

def checkout_fossil_rev(project, rev)
  Dir.cd(fossil_path(project)) do
    capture %w[fossil checkout] << rev
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
    capture %w[crystal build] << File.basename(path)
  end
  File.delete(path)
end

def git_commits(project, rev = "HEAD")
  Dir.cd(git_path(project)) do
    capture(%w[git log --format=%H] << rev).lines
  end
end

def git_url(project)
  "file://#{Path[git_path(project)].to_posix}"
end

def git_path(project)
  File.join(tmp_path, project.to_s)
end

def hg_commits(project, rev = ".")
  Dir.cd(hg_path(project)) do
    capture(%w[hg log] << "--template={node}\n" << "-r" << rev).lines
  end
end

def hg_url(project)
  "file://#{Path[hg_path(project)].to_posix}"
end

def hg_path(project)
  File.join(tmp_path, project.to_s)
end

def fossil_commits(project, rev = "trunk")
  # This is using the workaround code in case the machine running the specs is
  # using an old Fossil version.  See the #commit_sha1_at method in
  # src/resolvers/fossil.cr for info.
  Dir.cd(fossil_path(project)) do
    retStr = capture(%w[fossil timeline] << rev << "-t" << "ci" << "-W" << "0").lines
    retLines = retStr.flat_map do |line|
      /^.+ \[(.+)\].*/.match(line).try &.[1]
    end

    retLines.reject! &.nil?
    [/artifact:\s+(.+)/.match(capture(%w[fossil whatis] << retLines[0].to_s)).not_nil!.[1]]
  end
end

def fossil_url(project)
  "file://#{Path[fossil_path(project)].to_posix}"
end

def fossil_path(project)
  File.join(tmp_path, "#{project.to_s}")
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
    @@crystal_path ||= "#{Shards::INSTALL_DIR}#{Process::PATH_DELIMITER}#{`#{Shards.crystal_bin} env CRYSTAL_PATH`.chomp}"
  end
end

def tmp_path
  Shards::Specs.tmp_path
end

private def resolve_command(command_line)
  command, *args = command_line

  # Make sure we use local build for `shards` command in integration specs
  case command
  when "shards"
    command = File.expand_path("../../bin/shards", __DIR__)
  end

  {command, args}
end

def capture_result(command_line : Enumerable(String), *, env = nil, clear_env = false, input = Process::Redirect::Close)
  result = Process.capture_result(*resolve_command(command_line), env: env, clear_env: clear_env, input: input)

  Process::Result.new(result.status, result.stdout.gsub("\r\n", "\n"), result.stderr.try(&.gsub("\r\n", "\n")))
end

def capture(command_line : Enumerable(String), *, env = nil, clear_env = false, input = Process::Redirect::Close)
  Process.capture(*resolve_command(command_line), env: env, clear_env: clear_env, input: input).gsub("\r\n", "\n")
end
