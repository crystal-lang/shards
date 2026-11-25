require "./spec_helper"

private def assert_no_directory_cycles(path, ancestors = [] of String)
  ancestors.any? { |ancestor| File.same?(ancestor, path, follow_symlinks: true) }.should be_false
  Dir.each_child(path) do |entry|
    child = File.join(path, entry)
    assert_no_directory_cycles(child, ancestors + [path]) if Dir.exists?(child)
  end
end

%w[install update].each do |command|
  describe "#{command} dependency links" do
    it "allows transitive requires without recursive directory links" do
      with_shard({dependencies: {transitive_2: "*", web: "*"}}) do
        run "shards #{command}"

        lib_path = install_path("transitive_2", "lib")
        File.symlink?(lib_path).should be_false
        File.same?(File.join(lib_path, "transitive"), install_path("transitive"), follow_symlinks: true).should be_true
        File.same?(File.join(lib_path, "version"), install_path("version"), follow_symlinks: true).should be_true
        File.exists?(File.join(lib_path, "transitive_2")).should be_false
        File.exists?(File.join(lib_path, "web")).should be_false
        File.exists?(install_path("version", "lib")).should be_false
        assert_no_directory_cycles(Shards.install_path)

        Dir.cd(install_path("transitive_2")) do
          code = %(require "version"; puts Version::STRING)
          run("#{Shards.crystal_bin} eval #{Process.quote(code)}").chomp.should eq("version @ 0.1.0")
        end

        # Reusing installed sources must keep the dependency view usable.
        run "shards #{command}"
        assert_no_directory_cycles(Shards.install_path)

        File.rename("lib", "moved_lib")
        File.same?("moved_lib/transitive_2/lib/version", "moved_lib/version", follow_symlinks: true).should be_true
        assert_no_directory_cycles("moved_lib")
      end
    end

    it "refreshes transitive links without reinstalling the parent" do
      child = "link_child_#{command}"
      parent = "link_parent_#{command}"
      create_git_repository child, "0.1.0"
      create_git_repository parent
      create_git_release parent, "0.1.0", {dependencies: {child => {git: git_url(child)}}}

      with_shard({dependencies: {parent => "*"}}) do
        run "shards #{command}"
        File.write(install_path(parent, "keep.txt"), "local change")

        create_git_release child, "0.2.0", {dependencies: {web: {git: git_url("web")}}}
        File.delete("shard.lock") if command == "install"
        run "shards #{command}"
        File.same?(install_path(parent, "lib", "web"), install_path("web"), follow_symlinks: true).should be_true

        create_git_release child, "0.3.0", {dependencies: {pg: {git: git_url("pg")}}}
        File.delete("shard.lock") if command == "install"
        run "shards #{command}"
        File.exists?(install_path(parent, "lib", "web")).should be_false
        File.symlink?(install_path(parent, "lib", "web")).should be_false
        File.same?(install_path(parent, "lib", "pg"), install_path("pg"), follow_symlinks: true).should be_true
        File.read(install_path(parent, "keep.txt")).should eq("local change")
        assert_no_directory_cycles(Shards.install_path)
      end
    end

    it "uses the dependency graph selected by overrides" do
      fork = "link_override_#{command}"
      create_git_repository fork
      create_git_release fork, "0.5.0", {name: "orm", dependencies: {web: {git: git_url("web")}}}

      with_shard({dependencies: {orm: "*"}}, nil, {dependencies: {orm: {git: git_url(fork)}}}) do
        run "shards #{command}"
        File.same?(install_path("orm", "lib", "web"), install_path("web"), follow_symlinks: true).should be_true
        File.exists?(install_path("orm", "lib", "pg")).should be_false
        assert_no_directory_cycles(Shards.install_path)
      end
    end
  end
end
