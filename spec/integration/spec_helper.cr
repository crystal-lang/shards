ENV["PATH"] = "#{File.expand_path("../../bin", __DIR__)}:#{ENV["PATH"]}"
ENV["SHARDS_CACHE_PATH"] = ".shards"

require "spec"
require "../../src/config"
require "../../src/lock"
require "../../src/spec"
require "../support/factories"
require "../support/cli"
require "../support/requirement"

Spec.before_suite do
  run "rm -rf #{tmp_path}/*"
  setup_repositories
end

Spec.before_each do
  Shards::Resolver.clear_resolver_cache
end

private def setup_repositories
  # git dependencies for testing version resolution:
  create_git_repository "web", "1.0.0", "1.1.0", "1.1.1", "1.1.2", "1.2.0", "2.0.0", "2.1.0"
  create_git_repository "pg", "0.1.0", "0.2.0", "0.2.1", "0.3.0"
  create_git_repository "optional", "0.2.0", "0.2.1", "0.2.2"
  create_git_repository "shoulda", "0.1.0"
  create_git_repository "minitest", "0.1.0", "0.1.1", "0.1.2", "0.1.3"

  create_git_repository "mock"
  create_git_release "mock", "0.1.0", {
    dependencies:             {shoulda: {git: git_path("shoulda"), version: "< 0.3.0"}},
    development_dependencies: {minitest: {git: git_path("minitest")}},
  }

  create_git_repository "orm", "0.1.0", "0.2.0", "0.3.0", "0.3.1", "0.3.2", "0.4.0"
  create_git_release "orm", "0.5.0", {
    dependencies: {pg: {git: git_path("pg"), version: "< 0.3.0"}},
  }

  create_git_repository "release", "0.2.0", "0.2.1", "0.2.2"
  create_git_release "release", "0.3.0", {
    ncustom_dependencies: {pg: {git: git_path("optional")}},
  }

  # git dependencies with prereleases:
  create_git_repository "unstable", "0.1.0", "0.2.0", "0.3.0.alpha", "0.3.0.beta"
  create_git_repository "preview", "0.1.0", "0.2.0", "0.3.0.a", "0.3.0.b", "0.3.0", "0.4.0.a"

  # path dependency:
  create_path_repository "foo", "0.1.0"

  # dependency with neither a shard.yml and/or version tags:
  # create_git_repository "empty"
  # create_git_commit "empty", "initial release"

  create_git_repository "missing"
  create_shard "missing", "0.1.0"
  create_git_commit "missing", "initial release"

  create_git_repository "noshardyml"
  create_git_release "noshardyml", "0.1.0", false
  create_git_release "noshardyml", "0.2.0"

  # dependencies with postinstall scripts:
  create_git_repository "post"
  create_file "post", "Makefile", "all:\n\ttouch made.txt\n"
  create_git_release "post", "0.1.0", {scripts: {postinstall: "make"}}

  create_git_repository "fails"
  create_file "fails", "Makefile", "all:\n\ttest -n ''\n"
  create_git_release "fails", "0.1.0", {scripts: {postinstall: "make"}}

  # transitive dependencies in postinstall scripts:
  create_git_repository "version"
  create_file "version", "src/version.cr", %(module Version; STRING = "version @ 0.1.0"; end)
  create_git_release "version", "0.1.0"

  create_git_repository "renamed"
  create_git_release "renamed", "0.1.0", {name: "old_name"}
  create_git_release "renamed", "0.2.0", {name: "new_name"}
  create_git_version_commit "renamed", "0.3.0", {name: "another_name"}

  create_git_repository "version_mismatch"
  create_git_release "version_mismatch", "0.1.0"
  create_git_release "version_mismatch", "0.2.0", {version: "0.1.0"}
  create_git_release "version_mismatch", "0.2.1"

  create_git_repository "inprogress"
  create_git_version_commit "inprogress", "0.1.0"
  create_git_version_commit "inprogress", "0.1.0"

  create_git_repository "transitive"
  create_file "transitive", "src/version.cr", %(require "version"; puts Version::STRING)
  create_git_release "transitive", "0.2.0", {
    dependencies: {version: {git: git_url(:version)}},
    scripts:      {
      postinstall: "crystal build src/version.cr",
    },
  }

  create_git_repository "transitive_2"
  create_git_release "transitive_2", "0.1.0", {
    dependencies: {
      transitive: {git: git_url(:transitive)},
    },
    scripts: {
      postinstall: "../transitive/version",
    },
  }

  # dependencies with executables:
  create_git_repository "binary"
  create_file "binary", "bin/foobar", "#! /usr/bin/env sh\necho 'OK'", perm: 0o755
  create_file "binary", "bin/baz", "#! /usr/bin/env sh\necho 'KO'", perm: 0o755
  create_git_release "binary", "0.1.0", {executables: ["foobar", "baz"]}
  create_file "binary", "bin/foo", "echo 'FOO'", perm: 0o755
  create_git_release "binary", "0.2.0", {executables: ["foobar", "baz", "foo"]}

  create_git_repository "c"
  create_git_release "c", "0.1.0", {dependencies: {d: {git: git_url(:d), version: "0.1.0"}}}
  create_git_release "c", "0.2.0", {dependencies: {d: {git: git_url(:d), version: "0.2.0"}}}
  create_git_repository "d"
  create_git_release "d", "0.1.0"
  create_git_release "d", "0.2.0"

  create_git_repository "incompatible"
  create_git_release "incompatible", "0.1.0", {crystal: "0.1.0"}
  create_git_release "incompatible", "0.2.0", {crystal: "0.2.0"}
  create_git_release "incompatible", "0.3.0", {crystal: "0.4"}
  create_git_release "incompatible", "1.0.0", {crystal: "1.0.0"}

  create_git_repository "awesome"
  create_git_release "awesome", "0.1.0", {
    dependencies: {d: {git: git_url(:d)}},
  }
  # Release v0.1.0 is the same in awesome and forked_awesome
  create_fork_git_repository "forked_awesome", "awesome"
  # But v0.2.0 is not, they might be different
  create_git_release "forked_awesome", "0.2.0", {
    name:         "awesome",
    dependencies: {d: {git: git_url(:d)}},
  }
  create_git_release "awesome", "0.2.0", {
    dependencies: {d: {git: git_url(:d)}},
  }
  # Release v0.3.0 is only available in the original
  create_git_release "awesome", "0.3.0", {
    dependencies: {d: {git: git_url(:d)}},
  }
  checkout_new_git_branch "forked_awesome", "feature/super"
  create_git_commit "forked_awesome", "Starting super feature"
end

private def assert(value, message, file, line)
  fail(message, file, line) unless value
end

private def refute(value, message, file, line)
  fail(message, file, line) if value
end

def assert_installed(name, version = nil, file = __FILE__, line = __LINE__, *, git = nil, source = nil)
  assert Dir.exists?(install_path(name)), "expected #{name} dependency to have been installed", file, line
  Shards::Resolver.clear_resolver_cache # Parsing Shards::Info might use cache of resolvers. Avoid it
  info = Shards::Info.new(install_path)
  dependency = info.installed[name]?
  assert dependency, "expected #{name} to be present in the shards.info file", file, line

  if dependency && version
    expected_version = git ? "#{version}+git.commit.#{git}" : version
    dependency.requirement.should eq(version expected_version), file, line
  end

  if dependency && source
    expected_source = source_from_named_tuple(source)
    actual_source = source_from_resolver(dependency.resolver)
    assert expected_source == actual_source, "expected #{name} dependency to have been installed using #{expected_source}", file, line
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

def assert_locked(name, version = nil, file = __FILE__, line = __LINE__, *, git = nil, source = nil)
  path = File.join(application_path, "shard.lock")
  assert File.exists?(path), "expected shard.lock to have been generated", file, line
  Shards::Resolver.clear_resolver_cache # Parsing Shards::Lock might use cache of resolvers. Avoid it
  locks = Shards::Lock.from_file(path)
  assert lock = locks.shards.find { |d| d.name == name }, "expected #{name} dependency to have been locked", file, line

  if lock && version
    expected_version = git ? "#{version}+git.commit.#{git}" : version
    actual_value = lock.requirement.as(Shards::Version).value
    assert expected_version == actual_value, "expected #{name} dependency to have been locked at version #{version} instead of #{actual_value}", file, line
  end

  if lock && source
    expected_source = source_from_named_tuple(source)
    actual_source = source_from_resolver(lock.resolver)
    assert expected_source == actual_source, "expected #{name} dependency to have been locked using #{expected_source} instead of #{actual_source}", file, line
  end
end

private def source_from_named_tuple(source : NamedTuple)
  source.to_yaml.lines.last
end

private def source_from_resolver(resolver : Shards::Resolver)
  resolver.yaml_source_entry
end

def refute_locked(name, version = nil, file = __FILE__, line = __LINE__)
  path = File.join(application_path, "shard.lock")
  assert File.exists?(path), "expected shard.lock to have been generated", file, line
  locks = Shards::Lock.from_file(path)
  refute locks.shards.find { |d| d.name == name }, "expected #{name} dependency to not have been locked", file, line
end

def install_path(*path_names)
  File.join(application_path, Shards::INSTALL_DIR, *path_names)
end

def debug(command)
  run "#{command} --verbose"
rescue ex : FailedCommand
  puts
  puts ex.stdout
  puts ex.stderr
end
