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
    Dir.cd(git_path(project)) do
      run "git checkout --orphan master"

      run "git config user.email author@example.com"
      run "git config user.name Author"
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

    Dir.cd(git_path(project)) do
      run "git config user.email fork@example.com"
      run "git config user.name Fork"
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

def create_hg_repository(project, *versions)
  Dir.cd(tmp_path) do
    run "hg init #{Process.quote(project)}"
  end

  Dir.mkdir(File.join(hg_path(project), "src"))
  File.write(File.join(hg_path(project), "src", "#{project}.cr"), "module #{project.capitalize}\nend")

  Dir.cd(hg_path(project)) do
    run "hg add #{Process.quote("src/#{project}.cr")}"
  end

  versions.each { |version| create_hg_release project, version }
end

def create_fork_hg_repository(project, upstream)
  Dir.cd(tmp_path) do
    run "hg clone #{Process.quote(hg_url(upstream))} #{Process.quote(project)}"
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
      run "hg add #{Process.quote("src/#{name}.cr")}"
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
    run "hg tag -u #{Process.quote("Your Name <you@example.com>")} #{Process.quote(version)}"
  end
end

def create_hg_commit(project, message = "new commit")
  Dir.cd(hg_path(project)) do
    File.write("src/#{project}.cr", "# #{message}", mode: "a")
    run "hg commit -u #{Process.quote("Your Name <you@example.com>")} -A -m #{Process.quote(message)}"
  end
end

def checkout_new_hg_bookmark(project, branch)
  Dir.cd(hg_path(project)) do
    run "hg bookmark #{Process.quote(branch)}"
  end
end

def checkout_new_hg_branch(project, branch)
  Dir.cd(hg_path(project)) do
    run "hg branch #{Process.quote(branch)}"
  end
end

def checkout_hg_rev(project, rev)
  Dir.cd(hg_path(project)) do
    run "hg update -C #{Process.quote(rev)}"
  end
end

def create_fossil_repository(project, *versions)
  Dir.cd(tmp_path) do
    run "fossil init #{Process.quote(project)}.fossil"

    # Use a workaround so we don't use --workdir in case the specs are run on a
    # machine with an old Fossil version.  See the #install_sources method in
    # src/resolvers/fossil.cr
    Dir.mkdir(fossil_path(project)) unless Dir.exists?(fossil_path(project))
    Dir.cd(fossil_path(project)) do
      run "fossil open #{Process.quote(File.join(tmp_path, project))}.fossil"
    end
  end

  Dir.mkdir(File.join(fossil_path(project), "src"))
  File.write(File.join(fossil_path(project), "src", "#{project}.cr"), "module #{project.capitalize}\nend")

  Dir.cd(fossil_path(project)) do
    run %|fossil add #{Process.quote("src/#{project}.cr")}|
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
    run "fossil addremove"

    create_fossil_commit project, "release: v#{version}", tag
  end
end

def create_fossil_commit(project, message = "new commit", tag : String? = nil)
  Dir.cd(fossil_path(project)) do
    File.write("src/#{project}.cr", "# #{message}", mode: "a")
    run "fossil addremove"

    # Use --hash here to work around a file that's changed, but the size and
    # mtime are the same.  Depending on the resolution of mtime on the
    # underlying filesystem, shard.yml may fall into this edge case during
    # testing.
    #
    # https://fossil-users.fossil-scm.narkive.com/9ybRAo1U/error-file-is-different-on-disk-compared-to-the-repository-during-commti
    if tag
      run "fossil commit --hash --tag #{Process.quote(tag)} -m #{Process.quote(message)}"
    else
      run "fossil commit --hash -m #{Process.quote(message)}"
    end
  end
end

def create_fork_fossil_repository(project, upstream)
  Dir.cd(tmp_path) do
    run "fossil clone #{Process.quote(fossil_url(upstream))} #{Process.quote(project)}"
  end
end

def create_fossil_tag(project, version)
  Dir.cd(fossil_path(project)) do
    run "fossil tag add #{Process.quote(version)} current"
  end
end

def checkout_new_fossil_branch(project, branch)
  Dir.cd(fossil_path(project)) do
    run "fossil branch new #{Process.quote(branch)} current"
    run "fossil checkout branch"
  end
end

def checkout_fossil_rev(project, rev)
  Dir.cd(fossil_path(project)) do
    run "fossil checkout #{Process.quote(rev)}"
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

def hg_commits(project, rev = ".")
  Dir.cd(hg_path(project)) do
    run("hg log --template=#{Process.quote("{node}\n")} -r #{Process.quote(rev)}").strip.split('\n')
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
    retStr = run("fossil timeline #{Process.quote(rev)} -t ci -W 0").strip.split('\n')
    retLines = retStr.flat_map do |line|
      /^.+ \[(.+)\].*/.match(line).try &.[1]
    end

    retLines.reject! &.nil?
    [/artifact:\s+(.+)/.match(run("fossil whatis #{retLines[0]}")).not_nil!.[1]]
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

def run(command, *, env = nil, clear_env = false)
  cmd_env = {
    "CRYSTAL_PATH" => Shards::Specs.crystal_path,
  }
  cmd_env.merge!(env) if env
  output, error = IO::Memory.new, IO::Memory.new
  {% if flag?(:win32) %}
    # FIXME: Concurrent streams are currently broken on Windows. Need to drop one for now.
    error = nil
  {% end %}

  status = Process.run(command, shell: true, env: cmd_env, clear_env: clear_env, output: output, error: error || Process::Redirect::Close)

  output = output.to_s.gsub("\r\n", "\n")
  error = error.to_s.gsub("\r\n", "\n")

  if status.success?
    output + error
  else
    raise FailedCommand.new("command failed: #{command}", output, error)
  end
end
