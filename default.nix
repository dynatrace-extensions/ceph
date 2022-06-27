let
  nixpkgs = builtins.fetchGit {
    url = "https://github.com/nixos/nixpkgs/";
    ref = "refs/heads/nixos-unstable";
    rev = "f2537a505d45c31fe5d9c27ea9829b6f4c4e6ac5"; # 27-06-2022
    # obtain via `git ls-remote https://github.com/nixos/nixpkgs nixos-unstable`
  };
  pkgs = import nixpkgs { config = {}; };
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
      dtcli # set of devtools
      pyyaml
    ];
  prometheusDatasource = import ./go-datasource.nix {
    tech = "prometheus";
    rev = "45a7d0e795ee9dc039adfd0ceafeb5b15fa3333e";
    inherit pkgs;
  };
  pythonCore = pkgs.python39;
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
