class FailedCommand < Exception
  getter stdout : String
  getter stderr : String

  def initialize(message, @stdout, @stderr)
    super message
  end
end

def create_path_repository(project, version = nil)
  Dir.mkdir_p(File.join(git_path(project), "src"))
  File.write(File.join(git_path(project), "src", "#{project}.cr"), "module #{project.capitalize}\nend")
  create_shard project, "name: #{project}\nversion: #{version}\n" if version
end

def create_git_repository(project, *versions)
  Dir.cd(tmp_path) do
    run "git init #{project}"
  end

  Dir.mkdir(File.join(git_path(project), "src"))
  File.write(File.join(git_path(project), "src", "#{project}.cr"), "module #{project.capitalize}\nend")

  Dir.cd(git_path(project)) do
    run "git add src/#{project}.cr"
  end

  versions.each { |version| create_git_release project, version }
end

def create_git_version_commit(project, version, shard = true)
  Dir.cd(git_path(project)) do
    if shard
      contents = shard.is_a?(String) ? shard : "name: #{project}\nversion: #{version}\n"
      create_shard project, contents
    end
    Dir.cd(git_path(project)) do
      run "git add src/#{project}.cr"
    end
    create_git_commit project, "release: v#{version}"
  end
end

def create_git_release(project, version, shard = true)
  create_git_version_commit(project, version, shard)
  create_git_tag(project, "v#{version}")
end

def create_git_tag(project, version)
  Dir.cd(git_path(project)) do
    run "git tag #{version}"
  end
end

def create_git_commit(project, message = "new commit")
  Dir.cd(git_path(project)) do
    run "git add ."
    run "git commit --allow-empty --no-gpg-sign -m '#{message}'"
  end
end

def checkout_new_git_branch(project, branch)
  Dir.cd(git_path(project)) do
    run "git checkout -b #{branch}"
  end
end

def checkout_git_branch(project, branch)
  Dir.cd(git_path(project)) do
    run "git checkout #{branch}"
  end
end

def create_shard(project, contents)
  create_file project, "shard.yml", contents
end

def create_file(project, filename, contents, perm = nil)
  path = File.join(git_path(project), filename)
  parent = File.dirname(path)
  Dir.mkdir_p(parent) unless Dir.exists?(parent)
  File.write(path, contents)
  File.chmod(path, perm) if perm
end

def git_commits(project, rev = "HEAD")
  Dir.cd(git_path(project)) do
    run("git log --format='%H' #{rev}").strip.split('\n')
  end
end

def git_url(project)
  "file://#{git_path(project)}"
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
end

def tmp_path
  Shards::Specs.tmp_path
end

def run(command)
  # puts command
  output, error = IO::Memory.new, IO::Memory.new
  status = Process.run("/bin/sh", input: IO::Memory.new(command), output: output, error: error)

  if status.success?
    output.to_s
  else
    raise FailedCommand.new("command failed: #{command}", output.to_s, error.to_s)
  end
end
