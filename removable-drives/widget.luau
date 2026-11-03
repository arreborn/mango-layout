-- Removable Drives — bar icon.
--
-- Renders the "devices" state published by service.luau: hidden while no
-- removable partition is present, tinted while any of them is mounted.

-- "usb", not "device-usb": the latter's codepoint (U+FC59) sits in the Arabic
-- Presentation Forms-A block, which HarfBuzz shapes down to zero width.
local BAR_GLYPH = "usb"

-- The palette has no "success" role; tertiary is the closest accent.
local MOUNTED_GLYPH_COLOR = "tertiary"
local UNMOUNTED_GLYPH_COLOR = "on_surface"

local function render(devices)
	if type(devices) ~= "table" or #devices == 0 then
		barWidget.setVisible(false)
		barWidget.clearTooltip()
		return
	end
	local names = {}
	local anyMounted = false
	for _, device in ipairs(devices) do
		table.insert(names, device.label or device.path)
		if device.mounted then
			anyMounted = true
		end
	end
	barWidget.setVisible(true)
	barWidget.setGlyphColor(anyMounted and MOUNTED_GLYPH_COLOR or UNMOUNTED_GLYPH_COLOR)
	barWidget.setTooltip("Removable Drives: " .. table.concat(names, ", "))
end

barWidget.setGlyph(BAR_GLYPH)
noctalia.state.watch("devices", render)
render(noctalia.state.get("devices"))

function onClick()
	noctalia.togglePanel("arreborn/removable-drives:panel")
end
