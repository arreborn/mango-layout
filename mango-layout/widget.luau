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

local layoutBySym = {}
for _, entry in ipairs(layoutList) do
	layoutBySym[entry.sym] = entry
end

local ok, name = pcall(function() return barWidget.outputName() end)
local ownOutput = if ok then name else nil
if ownOutput == nil then
	ownOutput = noctalia.focusedOutputName()
end

local lastSym = nil

local function applyGlyph(sym)
	local entry = layoutBySym[sym]
	barWidget.setGlyph(if entry then entry.glyph else "layout-filled")
	barWidget.setTooltip(if entry then "Mango Layout: " .. entry.label else "Mango Layout")
end

local function onMonitorStreamLine(line)
	local data = noctalia.json.decode(line)
	if data == nil or data.monitors == nil then return end

	for _, monitor in ipairs(data.monitors) do
		if monitor.name == ownOutput then
			local sym = monitor.layout_symbol
			if sym ~= lastSym then
				lastSym = sym
				applyGlyph(sym)
			end
		end
	end
end

applyGlyph(nil)
noctalia.runStream("mmsg watch all-monitors", onMonitorStreamLine)

function update()
	noctalia.setUpdateInterval(0)
end

function onClick()
	noctalia.runAsync("mmsg dispatch switch_layout")
end
