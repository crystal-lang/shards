{ pkgs, lib, config, inputs, ... }:

{
  packages = with pkgs; [
    # build deps
    gnumake
    asciidoctor

    # test deps
    git
    fossil
    mercurial
  ];

  languages.crystal.enable = true;

  git-hooks.hooks = {
    shellcheck.enable = true;
    crystal.enable = true;
  };
}
