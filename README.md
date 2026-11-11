# arreborn's Noctalia plugins

A small collection of plugins for Noctalia v5:

- [`removable-drives`](removable-drives/README.md): bar icon and panel for
  mounting/unmounting removable drives.

## Disclaimer

AI has been used to generate a fair bit of the code in this repository. These
plugins are only meant for personal use, and are only public to allow for
declarative configuration of multiple hosts through NixOS.

## Usage

Add this repository as a source and activate the plugins you want. See
[Using Plugins](https://docs.noctalia.dev/v5/plugins/) for more detailed
information.

### NixOS

Assuming you are configuring Noctalia through `homeManager`:

```nix
programs.noctalia = {
    plugins = {
        source = {
            name = "arreborn";
            kind = "git";
            location = "https://github.com/arreborn/mango-layout";
            enabled = true;
        };
        enabled = [ "arreborn/removable-drives" ];
    };
};
```

### GUI

Open **Settings -> Plugins**, click **Add source**, and enter:

```text
https://github.com/arreborn/mango-layout
```

### Shell-commands

```sh
noctalia msg plugins source add arreborn git https://github.com/arreborn/mango-layout
noctalia msg plugins list
noctalia msg plugins enable arreborn/removable-drives
```
