# MangoWM Layout Plugin

A small plugin for Noctalia v5 that provides a small icon showing the currently
selected layout mode, and provides launcher commands to swap between them.

## Usage

Add this repository as a source and activate the plugin. See
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
        enabled = [ "arreborn/mango-layout" ];
    };

    # optional: add the icon declaratively to your bar (change bar names to fit)
    bar.default.end = [
        "arreborn/mango-layout:picker"
    ];
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
noctalia msg plugins enable arreborn/mango-layout
```

## Credits

`mango-layout` started as a fork of
[yogaeru/noctalia-plugins](https://github.com/yogaeru/noctalia-plugins), but
diverged in purpose and functionality quite quickly. Thanks for the inspiration
and code this was based on!
