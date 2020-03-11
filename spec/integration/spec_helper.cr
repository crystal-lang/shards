ENV["PATH"] = "#{File.expand_path("../../bin", __DIR__)}:#{ENV["PATH"]}"
ENV["SHARDS_CACHE_PATH"] = ".shards"

require "spec"
require "../../src/config"
require "../../src/lock"
require "../../src/spec"
require "../support/factories"
require "../support/cli"

Spec.before_suite do
  run "rm -rf #{tmp_path}/*"
  setup_repositories
end

private def setup_repositories
  # git dependencies for testing version resolution:
  create_git_repository "web", "1.0.0", "1.1.0", "1.1.1", "1.1.2", "1.2.0", "2.0.0", "2.1.0"
  create_git_repository "pg", "0.1.0", "0.2.0", "0.2.1", "0.3.0"
  create_git_repository "optional", "0.2.0", "0.2.1", "0.2.2"
  create_git_repository "shoulda", "0.1.0"
  create_git_repository "minitest", "0.1.0", "0.1.1", "0.1.2", "0.1.3"

  create_git_repository "mock"
  create_git_release "mock", "0.1.0", "name: mock\nversion: 0.1.0\n" +
                                      "dependencies:\n  shoulda:\n    git: #{git_path("shoulda")}\n    version: < 0.3.0\n" +
                                      "development_dependencies:\n  minitest:\n    git: #{git_path("minitest")}\n"

  create_git_repository "orm", "0.1.0", "0.2.0", "0.3.0", "0.3.1", "0.3.2", "0.4.0"
  create_git_release "orm", "0.5.0", "name: orm\nversion: 0.5.0\ndependencies:\n  pg:\n    git: #{git_path("pg")}\n    version: < 0.3.0\n"

  create_git_repository "release", "0.2.0", "0.2.1", "0.2.2"
  create_git_release "release", "0.3.0", "name: release\nversion: 0.3.0\ncustom_dependencies:\n  pg:\n    git: #{git_path("optional")}\n"

  # git dependencies with prereleases:
  create_git_repository "unstable", "0.1.0", "0.2.0", "0.3.0.alpha", "0.3.0.beta"
  create_git_repository "preview", "0.1.0", "0.2.0", "0.3.0.a", "0.3.0.b", "0.3.0", "0.4.0.a"

  # path dependency:
  create_path_repository "foo", "0.1.0"

  # dependency with neither a shard.yml and/or version tags:
  # create_git_repository "empty"
  # create_git_commit "empty", "initial release"

  create_git_repository "missing"
  create_shard "missing", "name: missing\nversion: 0.1.0\n"
  create_git_commit "missing", "initial release"

  # dependencies with postinstall scripts:
  create_git_repository "post"
  create_file "post", "Makefile", "all:\n\ttouch made.txt\n"
  create_git_release "post", "0.1.0", "name: post\nversion: 0.1.0\nscripts:\n  postinstall: make\n"

  create_git_repository "fails"
  create_file "fails", "Makefile", "all:\n\ttest -n ''\n"
  create_git_release "fails", "0.1.0", "name: fails\nversion: 0.1.0\nscripts:\n  postinstall: make\n"

  # transitive dependencies in postinstall scripts:
  create_git_repository "version"
  create_file "version", "src/version.cr", %(module Version; STRING = "version @ 0.1.0"; end)
  create_git_release "version", "0.1.0"

  create_git_repository "renamed"
  create_git_release "renamed", "0.1.0", "name: old_name\nversion: 0.1.0"
  create_git_release "renamed", "0.2.0", "name: new_name\nversion: 0.2.0"

  create_git_repository "transitive"
  create_file "transitive", "src/version.cr", %(require "version"; puts Version::STRING)
  create_git_release "transitive", "0.2.0", <<-YAML
    name: transitive
    version: 0.2.0
    dependencies:
      version:
        git: #{git_path(:version)}
    scripts:
      postinstall: crystal build src/version.cr
    YAML

  # dependencies with executables:
  create_git_repository "binary"
  create_file "binary", "bin/foobar", "#! /usr/bin/env sh\necho 'OK'", perm: 0o755
  create_file "binary", "bin/baz", "#! /usr/bin/env sh\necho 'KO'", perm: 0o755
  create_git_release "binary", "0.1.0", "name: binary\nversion: 0.1.0\nexecutables:\n  - foobar\n  - baz\n"
  create_file "binary", "bin/foo", "echo 'FOO'", perm: 0o755
  create_git_release "binary", "0.2.0", "name: binary\nversion: 0.2.0\nexecutables:\n  - foobar\n  - baz\n  - foo"
end

private def assert(value, message, file, line)
  fail(message, file, line) unless value
end

private def refute(value, message, file, line)
  fail(message, file, line) if value
end

def assert_installed(name, version = nil, file = __FILE__, line = __LINE__)
  assert Dir.exists?(install_path(name)), "expected #{name} dependency to have been installed", file, line

  if version
    assert File.exists?(install_path(name, "shard.yml")), "expected shard.yml for installed #{name} dependency was not found", file, line
    spec = Shards::Spec.from_file(install_path(name, "shard.yml"))

    if spec.version == "0" && File.exists?(install_path("#{name}.sha1"))
      File.read(install_path("#{name}.sha1")).should eq(version), file, line
    else
      spec.version.should eq(version), file, line
    end
  end
end

def refute_installed(name, version = nil, file = __FILE__, line = __LINE__)
  if version
    if Dir.exists?(install_path(name))
      assert File.exists?(install_path(name, "shard.yml")), "expected shard.yml for installed #{name} dependency was not found", file, line
      spec = Shards::Spec.from_file(install_path(name, "shard.yml"))
      spec.version.should_not eq(version), file, line
    end
  else
    refute Dir.exists?(install_path(name)), "expected #{name} dependency to not have been installed", file, line
  end
end

def assert_installed_file(path, file = __FILE__, line = __LINE__)
  assert File.exists?(File.join(install_path(name), path)), "Expected #{path} to have been installed", file, line
end

def assert_locked(name, version = nil, file = __FILE__, line = __LINE__)
  path = File.join(application_path, "shard.lock")
  assert File.exists?(path), "expected shard.lock to have been generated", file, line
  locks = Shards::Lock.from_file(path)
  assert lock = locks.find { |d| d.name == name }, "expected #{name} dependency to have been locked", file, line

  if lock && version
    if version =~ Shards::VERSION_REFERENCE
      assert version == lock.version, "expected #{name} dependency to have been locked at version #{version}", file, line
    else
      assert version == lock.refs, "expected #{name} dependency to have been locked at commit #{version}", file, line
    end
  end
end

def refute_locked(name, version = nil, file = __FILE__, line = __LINE__)
  path = File.join(application_path, "shard.lock")
  assert File.exists?(path), "expected shard.lock to have been generated", file, line
  locks = Shards::Lock.from_file(path)
  refute locks.find { |d| d.name == name }, "expected #{name} dependency to not have been locked", file, line
end

def install_path(project, *path_names)
  File.join(application_path, "lib", project, *path_names)
end

def debug(command)
  run "#{command} --verbose"
rescue ex : FailedCommand
  puts
  puts ex.stdout
  puts ex.stderr
end
