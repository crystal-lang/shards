ENV["PATH"] = "#{ File.expand_path("../bin", __DIR__) }:#{ ENV["PATH"] }"

require "minitest/autorun"
require "../src/config"
require "../src/lock"
require "../src/spec"
require "./support/factories"
require "./support/cli"

class Minitest::Test
  def setup
    unless @created_repositories
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

    @created_repositories = true
  end

  def assert_installed(name, version = nil)
    assert Dir.exists?(install_path(name)), "expected #{name} dependency to have been installed"

    if version
      assert File.exists?(install_path(name, "shard.yml")), "expected shard.yml for installed #{name} dependency was not found"
      spec = Shards::Spec.from_file(install_path(name, "shard.yml"))
      assert_equal version, spec.version
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
      assert_equal version, lock.version, "expected #{name} dependency to have been locked at version #{version}"
    end
  end

  def refute_locked(name, version = nil)
    path = File.join(application_path, "shard.lock")
    assert File.exists?(path), "expected shard.lock to have been generated"
    locks = Shards::Lock.from_file(path)
    refute locks.find { |d| d.name == name }, "expected #{name} dependency to not have been locked"
  end

  def install_path(project, *path_names)
    File.join(application_path, "libs", project, *path_names)
  end
end
