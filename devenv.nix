{ pkgs, lib, config, inputs, ... }:

{
  dotenv.enable = true;

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
    check-toml.enable = true;
    check-vcs-permalinks.enable = true;
    crystal.enable = true;
    makefile_both = {
      enable = true;
      name = "Change both Makefile and Makefile.win";
      entry = ''${pkgs.runtimeShell} -c 'test "$#" -ne 1 || (echo "Changes only in $@" && false)' --'';
      files = "^Makefile(\.win)?$";
      pass_filenames = true;
    };
    shellcheck = {
      enable = true;
      excludes = [
        ".*\.zsh$"
      ];
    };
  };
}
