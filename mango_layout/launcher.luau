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

local function matches(entry, text)
	if text == "" then return true end
	return entry.label:lower():find(text, 1, true) ~= nil
		or entry.name:find(text, 1, true) ~= nil
		or entry.sym:lower():find(text, 1, true) ~= nil
end

-- `query` is the launcher text after this provider's prefix, or the raw global
-- search text (include_in_global_search is set), leading space trimmed.
function onQuery(query)
	local text = noctalia.string.trim(query):lower()
	local rows = {}
	for _, entry in ipairs(layoutList) do
		if matches(entry, text) then
			table.insert(rows, {
				id = entry.sym,
				title = entry.label,
				subtitle = "Mango Layout",
				glyph = entry.glyph,
			})
		end
	end
	if #rows == 0 then
		rows[1] = { id = "", title = "No matching layout", glyph = "mood-empty" }
	end
	launcher.setResults(query, rows)
end

function onActivate(id)
	local entry = layoutBySym[id]
	if entry == nil then return end
	noctalia.runAsync(`mmsg dispatch "setlayout, {entry.name}"`)
end
