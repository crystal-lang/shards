ENV["PATH"] = "#{ File.expand_path("../bin", __DIR__) }:#{ ENV["PATH"] }"

require "minitest/autorun"
require "../src/config"
require "../src/lock"
require "../src/spec"
require "./support/factories"
require "./support/cli"

class Minitest::Test
  def self.created_repositories?
    @@created_repositories
  end

  def self.created_repositories!
    @@created_repositories = true
  end

  def before_setup
    super

    unless Minitest::Test.created_repositories?
      run "rm -rf #{tmp_path}/*"
      setup_repositories
    end
  end

  def setup_repositories
    create_git_repository "web", "1.0.0", "1.1.0", "1.1.1", "1.1.2", "1.2.0", "2.0.0", "2.1.0"
    create_git_repository "pg", "0.1.0", "0.2.0", "0.2.1", "0.3.0"
    create_git_repository "optional", "0.2.0", "0.2.1", "0.2.2"
    create_git_repository "shoulda", "0.1.0"
    create_git_repository "minitest", "0.1.0", "0.1.1", "0.1.2", "0.1.3"

    create_git_repository "mock"
    create_git_release "mock", "0.1.0", "name: mock\nversion: 0.1.0\n" +
      "dependencies:\n  shoulda:\n    git: #{ git_path("shoulda") }\n    version: < 0.3.0\n" +
      "development_dependencies:\n  minitest:\n    git: #{ git_path("minitest") }\n"

    create_git_repository "orm", "0.1.0", "0.2.0", "0.3.0", "0.3.1", "0.3.2", "0.4.0"
    create_git_release "orm", "0.5.0", "name: orm\nversion: 0.5.0\ndependencies:\n  pg:\n    git: #{ git_path("pg") }\n    version: < 0.3.0\n"

    create_git_repository "release", "0.2.0", "0.2.1", "0.2.2"
    create_git_release "release", "0.3.0", "name: release\nversion: 0.3.0\ncustom_dependencies:\n  pg:\n    git: #{ git_path("optional") }\n"

    create_git_repository "empty"
    create_git_commit "empty", "initial release"

    create_git_repository "post"
    create_file "post", "Makefile", "all:\n\ttouch made.txt\n"
    create_git_release "post", "0.1.0", "name: post\nversion: 0.1.0\nscripts:\n  postinstall: make\n"

    create_git_repository "fails"
    create_file "fails", "Makefile", "all:\n\ttest -n ''\n"
    create_git_release "fails", "0.1.0", "name: fails\nversion: 0.1.0\nscripts:\n  postinstall: make\n"

    create_path_repository "foo"

    Minitest::Test.created_repositories!
  end

  def assert_installed(name, version = nil)
    assert Dir.exists?(install_path(name)), "expected #{name} dependency to have been installed"

    if version
      assert File.exists?(install_path(name, "shard.yml")), "expected shard.yml for installed #{name} dependency was not found"
      spec = Shards::Spec.from_file(install_path(name, "shard.yml"))

      if spec.version == "0" && File.exists?(cache_path("#{ name }.sha1"))
        assert_equal version, File.read(cache_path("#{ name }.sha1"))
      else
        assert_equal version, spec.version
      end
    end
  end

  def refute_installed(name, version = nil)
    if version
      if Dir.exists?(install_path(name))
        assert File.exists?(install_path(name, "shard.yml")), "expected shard.yml for installed #{name} dependency was not found"
        spec = Shards::Spec.from_file(install_path(name, "shard.yml"))
        refute_equal version, spec.version
      end
    else
      refute Dir.exists?(install_path(name)), "expected #{name} dependency to not have been installed"
    end
  end

  def assert_locked(name, version = nil)
    path = File.join(application_path, "shard.lock")
    assert File.exists?(path), "expected shard.lock to have been generated"
    locks = Shards::Lock.from_file(path)
    assert lock = locks.find { |d| d.name == name }, "expected #{name} dependency to have been locked"

    if lock && version
      if version =~ /^[\d.]+$/
        assert_equal version, lock.version, "expected #{name} dependency to have been locked at version #{version}"
      else
        assert_equal version, lock.refs, "expected #{name} dependency to have been locked at commit #{version}"
      end
    end
  end

  def refute_locked(name, version = nil)
    path = File.join(application_path, "shard.lock")
    assert File.exists?(path), "expected shard.lock to have been generated"
    locks = Shards::Lock.from_file(path)
    refute locks.find { |d| d.name == name }, "expected #{name} dependency to not have been locked"
  end

  def cache_path(*path_names)
    File.join(application_path, ".shards", *path_names)
  end

  def install_path(project, *path_names)
    File.join(application_path, "lib", project, *path_names)
  end

  def debug(command)
    run "#{ command } --verbose"
  rescue ex : FailedCommand
    puts
    puts ex.stdout
    puts ex.stderr
  end
end
