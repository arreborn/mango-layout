# mango-layout

A Noctalia launcher provider and bar widget for switching
[Mango](https://github.com/mangowm/mango) window manager layouts.

## Requirements

- [`mango`](https://github.com/mangowm/mango) — window manager

## Usage

**Launcher**: open Noctalia's launcher and type `/layout` followed by a layout
name (or symbol), e.g. `/layout tile`. Since global search is enabled, typing a
layout name directly (without the `/layout` prefix) also works. Select a result
to apply that layout instantly.

**Bar widget**: shows the active layout's icon for its monitor, updating live
regardless of how the layout was changed (launcher, WM keybind, etc). Clicking
it cycles to the next layout (mango's native `switch_layout`).
