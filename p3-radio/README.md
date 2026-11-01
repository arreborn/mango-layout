# P3 Radio

A Noctalia v5 bar toggle for the live [Sveriges Radio P3](https://www.sverigesradio.se/p3)
stream. Click to start or stop; hover for the current (or last played) track.

## Requirements

- A `p3` command on `PATH` supporting `p3 toggle`. It starts the stream as a
  transient systemd user unit named `p3-radio` (or stops it if running); the
  widget mirrors that unit's state.

## Disclaimer

AI has been used to generate a fair bit of the code in this repository. This
plugin is only meant for personal use, and is only public to allow for
declarative configuration of multiple hosts through NixOS.
