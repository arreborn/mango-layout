local layoutList = {
	{ sym = "T",  name = "tile",             label = "Tile",               glyph = "layout-sidebar-right" },
	{ sym = "S",  name = "scroller",         label = "Scroller",           glyph = "carousel-horizontal" },
	{ sym = "M",  name = "monocle",          label = "Monocle",            glyph = "square" },
	{ sym = "G",  name = "grid",             label = "Grid",               glyph = "layout-grid" },
	{ sym = "F",  name = "fair",             label = "Fair",               glyph = "layout-board-split" },
	{ sym = "D",  name = "deck",             label = "Deck",               glyph = "layers-difference" },
	{ sym = "DW", name = "dwindle",          label = "Dwindle",            glyph = "layout-2" },
	{ sym = "CT", name = "center_tile",      label = "Center Tile",        glyph = "layout-distribute-vertical" },
	{ sym = "VT", name = "vertical_tile",    label = "Vertical Tile",      glyph = "layout-rows" },
	{ sym = "RT", name = "right_tile",       label = "Right Tile",         glyph = "layout-sidebar" },
	{ sym = "VS", name = "vertical_scroller",label = "Vertical Scroller",  glyph = "carousel-vertical" },
	{ sym = "VG", name = "vertical_grid",    label = "Vertical Grid",      glyph = "grid-dots" },
	{ sym = "VD", name = "vertical_deck",    label = "Vertical Deck",      glyph = "chart-funnel" },
	{ sym = "VF", name = "vertical_fair",    label = "Vertical Fair",      glyph = "layout-board" },
}

local currentSym = nil

local function render()
	local rows = {}
	for _, entry in ipairs(layoutList) do
		table.insert(rows, ui.button({
			key = "layout-" .. entry.sym,
			glyph = entry.glyph,
			text = entry.label,
			variant = "ghost",
			contentAlign = "start",
			selected = entry.sym == currentSym,
			onClick = function()
				currentSym = entry.sym
				noctalia.runAsync(`mmsg dispatch "setlayout, {entry.name}"`)
				panel.close()
			end,
		}))
	end

	panel.render(ui.column({ flexGrow = 1, gap = 8, align = "stretch" }, {
		ui.row({ key = "header", gap = 6, align = "center" }, {
			ui.label({ key = "title", text = "Mango Layout", fontSize = 16, fontWeight = "bold", color = "on_surface" }),
			ui.spacer({ key = "gap", flexGrow = 1 }),
			ui.button({ key = "close", glyph = "close", variant = "ghost", onClick = "onClosePanel" }),
		}),
		ui.scroll({ key = "layouts", flexGrow = 1, gap = 2 }, rows),
	}))
end

local function refreshCurrent()
	noctalia.runAsync("mmsg get all-monitors", function(result)
		if result.exitCode ~= 0 or result.timedOut then return end
		local data = noctalia.json.decode(result.stdout or "")
		if data == nil or data.monitors == nil then return end
		for _, monitor in ipairs(data.monitors) do
			if monitor.active then
				currentSym = monitor.layout_symbol
				break
			end
		end
		render()
	end, 5000)
end

function onOpen(_context)
	render()
	refreshCurrent()
end

function onClosePanel()
	panel.close()
end
