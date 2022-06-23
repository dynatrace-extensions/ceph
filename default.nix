let
  nixpkgs = builtins.fetchGit {
    url = "https://github.com/nixos/nixpkgs-channels/";
    ref = "refs/heads/nixos-unstable";
    rev = "daaa0e33505082716beb52efefe3064f0332b521";
    # obtain via `git ls-remote https://github.com/nixos/nixpkgs-channels nixos-unstable`
  };
  pkgs = import nixpkgs { config = {}; };
  markdown-table = with pkgs.python38Packages; buildPythonPackage rec {
      pname = "markdown-table";
      version = "2020.12.3";

      src = fetchPypi{
        inherit version;
        inherit pname;
        sha256 = "0gqr46rh7m6b5qcdmpbxrbvzi0yniaksbak1mcfkn60ldplfh3fz";
      };
  };
  click-aliases = with pkgs.python38Packages; buildPythonPackage rec {
      pname = "click-aliases";
      version = "1.0.1";

      src = fetchPypi{
        inherit version;
        inherit pname;
        sha256 = "18q5wya46mdlm2g8x6bcxhzqf09nxy7lbvpqyh1fp207gq3i507l";
      };

      buildInputs = [ click ];
  };
  dtcli = with pkgs.python38Packages; buildPythonPackage rec {
      pname = "dt-cli";
      version = "0.0.9a0";

      src = fetchPypi{
        inherit version;
        inherit pname;
        sha256 = "17v90ykiph88dz1pxl801dpv6lc2ajsxns460zjjwbqpi9x2p1bv";
      };

      propagatedBuildInputs = [ pyyaml asn1crypto click click-aliases cryptography ];
  };
  pythonPkgs = python-packages: with python-packages; [
      ptpython # used for dev
      markdown-table # for building docs
      dtcli # set of devtools
      pyyaml
    ];
  prometheusDatasource = import ./go-datasource.nix {
    tech = "prometheus";
    rev = "45a7d0e795ee9dc039adfd0ceafeb5b15fa3333e";
    inherit pkgs;
  };
  pythonCore = pkgs.python38;
  myPython = pythonCore.withPackages pythonPkgs;
  env = pkgs.buildEnv {
    name = "extension-dev-env";
    paths =
    with pkgs;
    [
      git
      gnugrep
      gnumake
      yq
      curl
      zip
      bzip2
      jq
      openssl
      myPython
      entr

      # datasources
      prometheusDatasource

      # extension-specific
    ];
  };
in
{
  docker = { image = pkgs.dockerTools.buildImage {
    name = "extension-env";
    tag = "builded";

    created = "now";

    contents = [ env ];

    runAsRoot = ''
      #!${pkgs.runtimeShell}
      mkdir -p /workdir
      ln -s ${pkgs.runtimeShell} /bin/sh
    '';

    config = {
      Cmd = [ "${pkgs.runtimeShell}" ];
      WorkingDir = "/workdir";
    };
  };};
  shell = pkgs.mkShell {
    buildInputs = [ env ];
  };
}