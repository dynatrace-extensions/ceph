# Ceph Extension

This extension provides ability to monitor usage of [Ceph](https://ceph.io/en/) storage system. It covers both client side and host level in-depth data.

## This is intended for users, who: 

- Would like to monitor usage and performance of their Ceph platform

- Require constant ability to have live information about host resources and data flow.

- Aim to shorten analysis time, required to find out root cause of possible system failures, to the minimum.

## This enables you to: 

- Monitor host resources usage and its capacity levels.

- Collect data regarding active and inactive Ceph object storage daemons.

- Observe system data flow in terms of write/read operations, for the cluster as a whole, and for the osd's in particular.

### This extension contains

- Dashboard template,
- Unified Analysis screen template,
- Topology definition and entity extraction rules.

## Dev

### Prerequisites
- Nix-capable environment, for Windows that means [installing WSL](https://docs.microsoft.com/en-us/learn/modules/get-started-with-windows-subsystem-for-linux/2-enable-and-install)
- [nix](https://nixos.org/download.html) / [**nix for WSL**](https://nixos.org/download.html#nix-install-windows)
- Docker (available in the same environment as nix, required for running companions)

Hint: if something doesn't work because of missing package please add the package to `default.nix` instead of installing on your computer. Why solve the problem for one if you can solve the problem for all? ;)

### Everything
```
nix-shell
# caution! if this is your first pull of first extension ever this might take some time
# depending on your network connection
# after it completes: inside the shell
make help
```

### Resources
- [Extension yaml docs](https://www.dynatrace.com/support/help/extend-dynatrace/extensions20/extension-yaml)
- [Extension knowledge base](https://www.dynatrace.com/support/help/extend-dynatrace/extensions20)

### Convinience
This section is entirely **optional**. The repository contains additional amenities, but they're not so straightforward, so we don't recommend them for begginers.  Anyway, you might also like:
- [`direnv`](https://direnv.net/) (which can be installed easily via `nix-env -iA nixpkgs.direnv`)

### Internal tooling
If you're a **Dynatrace employee** you can follow [this link](https://github.com/dynatrace-extensions/precious-toolz-internal) to enable internal tooling
