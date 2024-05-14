{ pkgs, lib, config, inputs, ... }:

{
  # https://devenv.sh/packages/
  packages = with pkgs; [
    # build deps
    gnumake
    asciidoctor

    # test deps
    git
    fossil
    mercurial
  ];
  enterShell = ''
    crystal --version
  '';

  languages.crystal.enable = true;

  # https://devenv.sh/pre-commit-hooks/
  pre-commit.hooks.shellcheck.enable = true;
  pre-commit.hooks.crystal.enable = true;
}
