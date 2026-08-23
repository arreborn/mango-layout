# Removable Drives

A small plugin for Noctalia v5 that shows a bar icon when a removable,
mountable partition is plugged in, and lets you mount or unmount it from a
panel — no auto-mounting, you stay in control.

## Requirements

- [`udisks2`](https://www.freedesktop.org/wiki/Software/udisks/) — provides
  `udisksctl`, used to mount/unmount
- `util-linux` — provides `lsblk`, used to detect removable partitions
- `libnotify` — provides `notify-send`, used for mount/unmount notifications

## Disclaimer

AI has been used to generate a fair bit of the code in this repository. This
plugin is only meant for personal use, and is only public to allow for
declarative configuration of multiple hosts through NixOS.

## Usage

**Bar widget**: hidden until a removable, mountable partition (e.g. a USB
stick or external drive) is detected. Once one is present the icon appears;
clicking it opens the panel.

**Panel**: lists every detected removable partition by its filesystem label
(falling back to its device path if unlabeled), each with a Mount/Unmount
button. Plugging a drive in never mounts it automatically — press Mount to
mount it. Once mounted, the drive's label is also clickable and opens the
mount path in a terminal. Unmounting only unmounts the filesystem (no
power-off/eject); the drive stays listed so it can be remounted without
unplugging it, until it is physically removed.

**Settings**: the terminal command used when opening a mounted drive's
folder (`terminal_command`, default `ghostty -e`) can be changed from the
plugin's settings page.

## Install

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

    # optional: add the icon declaratively to your bar (change bar names to fit)

    widget.drives.type = "arreborn/removable-drives";

    bar.default.end = [
        "drives"
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
noctalia msg plugins enable arreborn/removable-drives
```
