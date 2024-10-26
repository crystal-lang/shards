require "./spec_helper"

module Shards
  describe Spec do
    it "parse minimal shard" do
      spec = Spec.from_yaml("name: shards\nversion: 0.1.0\n")
      spec.name.should eq("shards")
      spec.version.should eq(version "0.1.0")
      spec.description.should be_nil
      spec.license.should be_nil
      spec.authors.should be_empty
      spec.read_from_yaml?.should be_true
    end

    it "create without yaml" do
      spec = Spec.new("name", version "0.1.0")
      spec.version.should eq(version "0.1.0")
      spec.read_from_yaml?.should be_false
    end

    it "parse description" do
      spec = Spec.from_yaml("name: shards\nversion: 0.1.0\ndescription: short description")
      spec.description.should eq("short description")

      spec = Spec.from_yaml("name: shards\nversion: 0.1.0\ndescription: |\n slightly longer description")
      spec.description.should eq("slightly longer description")
    end

    it "parse license" do
      spec = Spec.from_yaml("name: shards\nversion: 0.1.0\nlicense: BSD-2-Clause")
      spec.license.should eq("BSD-2-Clause")
      spec.license_url.should eq("https://spdx.org/licenses/BSD-2-Clause")

      spec = Spec.from_yaml("name: shards\nversion: 0.1.0\nlicense: http://example.com/LICENSE")
      spec.license.should eq("http://example.com/LICENSE")
      spec.license_url.should eq("http://example.com/LICENSE")
    end

    it "parse crystal" do
      spec = Spec.from_yaml("name: shards\nversion: 0.7.0\ncrystal: 0.20.0")
      spec.crystal.should eq("0.20.0")
    end

    it "parse authors" do
      spec = Spec.from_yaml("name: shards\nversion: 0.1.0\nauthors:\n  - Julien Portalier <julien@portalier.com>\n  - Ary")
      spec.authors.size.should eq(2)

      spec.authors[0].name.should eq("Julien Portalier")
      spec.authors[0].email.should eq("julien@portalier.com")

      spec.authors[1].name.should eq("Ary")
      spec.authors[1].email.should be_nil
    end

    it "parse dependencies" do
      spec = Spec.from_yaml <<-YAML
      name: orm
      version: 1.0.0
      dependencies:
        repo:
          github: user/repo
          version: 1.2.3
        example:
          git: https://example.com/example-crystal.git
          branch: master
        local:
          path: /var/clones/local
      YAML

      spec.dependencies.size.should eq(3)

      spec.dependencies[0].name.should eq("repo")
      spec.dependencies[0].resolver.should eq(GitResolver.new("repo", "https://github.com/user/repo.git"))
      spec.dependencies[0].requirement.should eq(version_req "1.2.3")

      spec.dependencies[1].name.should eq("example")
      spec.dependencies[1].resolver.should eq(GitResolver.new("example", "https://example.com/example-crystal.git"))
      spec.dependencies[1].requirement.should eq(branch "master")

      spec.dependencies[2].name.should eq("local")
      spec.dependencies[2].resolver.should eq(PathResolver.new("local", "/var/clones/local"))
      spec.dependencies[2].requirement.should eq(Any)
    end

    it "parses empty mappings/sequences" do
      spec = Spec.from_yaml <<-YAML
        name: orm
        version: 1.0.0
        authors:
        dependencies:
        development_dependencies:
        targets:
        executables:
        libraries:
        scripts:
        YAML
      spec.dependencies.empty?.should be_true
    end

    it "fails dependency with duplicate resolver" do
      expect_raises Shards::ParseError, %(Duplicate resolver mapping for dependency "foo" at line 6, column 5) do
        Spec.from_yaml <<-YAML
          name: orm
          version: 1.0.0
          dependencies:
            foo:
              github: user/repo
              gitlab: user/repo
          YAML
      end
    end

    it "fails dependency with missing resolver" do
      expect_raises Shards::ParseError, %(Missing resolver for dependency "foo" at line 4, column 3) do
        Spec.from_yaml <<-YAML
          name: orm
          version: 1.0.0
          dependencies:
            foo:
              branch: master
          YAML
      end
    end

    it "accepts dependency with extra attributes" do
      spec = Spec.from_yaml <<-YAML
        name: orm
        version: 1.0.0
        dependencies:
          foo:
            github: user/repo
            extra: foobar
        YAML
      dep = Dependency.new("foo", GitResolver.new("foo", "https://github.com/user/repo.git"), Any)
      spec.dependencies[0].should eq dep
    end

    it "parse development dependencies" do
      spec = Spec.from_yaml <<-YAML
      name: orm
      version: 1.0.0
      development_dependencies:
        minitest:
          github: ysbaddaden/minitest.cr
          version: 0.1.4
        webmock:
          git: https://github.com/manastech/webcmok-crystal.git
          branch: master
      YAML

      spec.development_dependencies.size.should eq(2)

      spec.development_dependencies[0].name.should eq("minitest")
      spec.development_dependencies[0].resolver.should eq(GitResolver.new("minitest", "https://github.com/ysbaddaden/minitest.cr.git"))
      spec.development_dependencies[0].requirement.should eq(version_req "0.1.4")

      spec.development_dependencies[1].name.should eq("webmock")
      spec.development_dependencies[1].resolver.should eq(GitResolver.new("webmock", "https://github.com/manastech/webcmok-crystal.git"))
      spec.development_dependencies[1].requirement.should eq(branch "master")
    end

    it "parse targets" do
      spec = Spec.from_yaml <<-YAML
      name: shards
      version: 0.7.0
      targets:
        shards:
          main: src/shards.cr
        cli:
          main: src/command/cli.cr
      YAML

      spec.targets.size.should eq(2)

      spec.targets[0].name.should eq("shards")
      spec.targets[0].main.should eq("src/shards.cr")

      spec.targets[1].name.should eq("cli")
      spec.targets[1].main.should eq("src/command/cli.cr")
    end

    it "fails target missing main" do
      expect_raises Shards::ParseError, %(Missing property "main" for target "foo" at line 4, column 3) do
        Spec.from_yaml <<-YAML
          name: orm
          version: 1.0.0
          targets:
            foo:
              foo: bar
          YAML
      end
    end

    it "parse executables" do
      spec = Spec.from_yaml <<-YAML
      name: test
      version: 1.0.0
      executables:
        - micrate
        - icr
      YAML
      spec.executables.should eq(%w(micrate icr))

      expect_raises(Error) do
        spec = Spec.from_yaml <<-YAML
        name: test
        version: 1.0.0
        executables:
          micrate: src/micrate.cr
        YAML
      end
    end

    it "parse libraries" do
      spec = Spec.from_yaml <<-YAML
      name: sqlite3
      version: 1.0.0
      libraries:
        libsqlite3: 3.8.0
        libfoo: "*"
      YAML

      spec.libraries.size.should eq(2)
      spec.libraries[0].soname.should eq("libsqlite3")
      spec.libraries[0].version.should eq("3.8.0")

      spec.libraries[1].soname.should eq("libfoo")
      spec.libraries[1].version.should eq("*")
    end

    it "fails to parse invalid library" do
      empty_version = <<-YAML
      name: sqlite3
      version: 1.0.0
      libraries:
        libsqlite3:
      YAML

      expect_raises(Error) { Spec.from_yaml(empty_version) }

      list = <<-YAML
      name: sqlite3
      version: 1.0.0
      libraries:
        - libsqlite3
        - libfoo
      YAML

      expect_raises(ParseError) { Spec.from_yaml(list) }
    end

    it "skips unknown attributes" do
      spec = Spec.from_yaml("\nanme: test\ncustom:\n  test: more\nname: test\nversion: 1\n")
      spec.name.should eq("test")
      spec.version.should eq(version "1")

      spec = Spec.from_yaml("\nanme:\nname: test\nversion: 1\n")
      spec.name.should eq("test")
      spec.version.should eq(version "1")
    end

    it "raises on unknown attributes if validating" do
      expect_raises(ParseError, "unknown attribute: anme") { Spec.from_yaml("anme:", validate: true) }
    end

    it "raises when required attributes are missing" do
      expect_raises(ParseError, "missing required attribute: name") { Spec.from_yaml("license: MIT") }

      expect_raises(ParseError, "missing required attribute: version") { Spec.from_yaml("name: test") }
    end

    it "fails to parse dependencies" do
      str = <<-YAML
      name: amethyst
      version: 0.1.7
      dependencies:
        github: spalger/crystal-mime
        branch: master
      YAML
      expect_raises(ParseError) { Spec.from_yaml(str) }
    end

    it "errors on duplicate attributes" do
      expect_raises(ParseError, %(duplicate attribute "name")) do
        Spec.from_yaml <<-YAML
          name: foo
          name: foo
        YAML
      end
      expect_raises(ParseError, %(duplicate attribute "version")) do
        Spec.from_yaml <<-YAML
          name: foo
          version: 1.0.0
          version: 1.0.0
        YAML
      end
      expect_raises(ParseError, %(duplicate attribute "dependencies")) do
        Spec.from_yaml <<-YAML
          name: foo
          version: 1.0.0

          dependencies:
            bar:
              github: foo/bar
          dependencies:
            baz:
              github: foo/baz
        YAML
      end
      expect_raises(ParseError, %(duplicate attribute "development_dependencies")) do
        Spec.from_yaml <<-YAML
          name: foo
          version: 1.0.0

          development_dependencies:
            bar:
              github: foo/bar
          development_dependencies:
            baz:
              github: foo/baz
        YAML
      end
    end
  end
end
