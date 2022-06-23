{ pkgs, rev, tech }:
  with pkgs; buildGoPackage rec {
    name = "go-datasource-${tech}-${version}";
    version = rev;
    goPackagePath = "bitbucket.lab.dynatrace.org/datasource-go";
    subPackages = [ "${tech}/dtsource${tech}" ];
    src = builtins.fetchGit {
      url = "ssh://git@bitbucket.lab.dynatrace.org/one/datasource-go.git";
      inherit rev;
    };
    goDeps = ./go-deps.nix;
  }
