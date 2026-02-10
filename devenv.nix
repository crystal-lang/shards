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

  languages.crystal = {
    enable = true;
    # The Crystal language configuration uses `crystalline` as LSP, but the
    # nix package seems to be temporarily broken.
    lsp.enable = false;
  };

  git-hooks.hooks = {
    shellcheck.enable = true;
    crystal.enable = true;
  };
}
