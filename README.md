# MongoDB Generic Extension
Extension targeting [MongoDB database](https://docs.mongodb.com/)

## Usage
For now go for [dev](#dev)

## TMP
- please fill docker_container in Makefile
- please fill companion port in Makefile
- plase fill upstream repo if you want to publish and github CI is not done yet
- please fill remote and local activation with port and address
- please fill remote and local activation after dividing features into featuresets
- please remove this entry

## Dev

### Prerequisites
- [nix](https://nixos.org/nix/manual/#chap-installation)
- `direnv` (`nix-env -iA nixpkgs.direnv`)
- [configured direnv shell hook ](https://direnv.net/docs/hook.html), yup in your `.bashrc`
- some form of `make` (`nix-env -iA nixpkgs.gnumake`)
- Docker

Hint: if something doesn't work because of missing package please add the package to `default.nix` instead of installing on your computer. Why solve the problem for one if you can solve the problem for all? ;)

### One-time setup
```
make init
```

### Everything
```
make help
```
