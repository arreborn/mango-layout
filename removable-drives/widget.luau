-- Removable Drives — bar icon.
--
-- Polls `lsblk -J` on a timer and keeps the icon hidden until at least one
-- removable, mountable partition is present. The full device list is
-- published through noctalia.state so the panel (a separate script) can read
-- and react to it without polling lsblk itself. This plugin never auto-mounts
-- anything — plugging a drive in only makes it known.

local POLL_INTERVAL_MS = 4000
local LSBLK_CMD = "lsblk -J -o NAME,PATH,TYPE,FSTYPE,LABEL,RM,MOUNTPOINT,TRAN,PARTTYPE"

-- Bar glyph: "usb" (a plain USB-trident icon, tabler codepoint U+F00C), not
-- "device-usb". Verified live: "device-usb" is present in the tabler font and
-- its metadata (assets/fonts/tabler.json), but its codepoint (U+FC59) falls
-- inside the Arabic Presentation Forms-A Unicode block (U+FB50-FDFF); the
-- host's HarfBuzz-based text shaping applies Arabic contextual-joining rules
-- to that range, which silently drops the glyph to zero-width when rendered
-- standalone in a bar widget — confirmed by rendering it live (invisible,
-- zero width, no error) versus "usb"/"star" (both outside that range,
-- render correctly). "usb" was re-confirmed as the right icon after the fix.
local BAR_GLYPH = "usb"

-- GPT partition-type GUID for the EFI System Partition (standardized by the
-- UEFI spec, not vendor- or distro-specific). Excluded by this GUID rather
-- than by FSTYPE/LABEL matching, since a user's own removable vfat partition
-- could legitimately be labeled "EFI" too — the type GUID is the only robust
-- identifier for "this partition is an ESP, not user data".
local ESP_PARTTYPE_GUID = "c12a7328-f81f-11d2-ba4b-00a0c93ec93b"

-- Bar glyph color when at least one known device is mounted. No palette
-- color *role* renders as green across every bundled theme — cross-checked
-- against every built-in palette in builtin_palettes.cpp, only the default
-- "Noctalia" theme's `tertiary` happens to be green (#9BFECE); e.g. Ayu and
-- Nord's `tertiary` are blue. A fixed hex color is a first-class, supported
-- value for setGlyphColor (resolved the same way as a role, via
-- tryParseHexColor) and is the only way to guarantee "green" regardless of
-- the user's active theme.
local MOUNTED_GLYPH_COLOR = "#4CAF50"
local UNMOUNTED_GLYPH_COLOR = "on_surface" -- the documented default/unset role

local function isNonEmptyString(value)
	return type(value) == "string" and value ~= ""
end

local function isEsp(part)
	local partType = part.parttype
	return isNonEmptyString(partType) and string.lower(partType) == ESP_PARTTYPE_GUID
end

-- A partition counts as removable when it (or its parent disk) reports RM, or
-- when it (or its parent disk) is attached over USB. RM alone misses plenty
-- of real USB enclosures: many external HDD/SSD bridge chips answer RM=0
-- despite being hot-pluggable, so TRAN=="usb" is treated as removable too.
-- Values coming out of noctalia.json.decode are checked by type rather than
-- trusted blindly, since a "null" JSON field may not decode to plain nil.
--
-- Each included device is also tagged with a `category`: "rm" when RM==true
-- was confirmed on the partition or its parent disk (a small flash-drive-like
-- device), or "usb" when it only qualified via TRAN=="usb" with RM==false (a
-- larger external drive whose bridge chip doesn't report itself removable).
-- The panel uses this to pick a distinct glyph per bucket.
local function parseDevices(lsblkTree)
	local devices = {}
	local disks = lsblkTree and lsblkTree.blockdevices
	if type(disks) ~= "table" then
		return devices
	end
	for _, disk in ipairs(disks) do
		local diskRm = disk.rm == true
		local diskRemovable = diskRm or disk.tran == "usb"
		local children = disk.children
		if type(children) == "table" then
			for _, part in ipairs(children) do
				local removable = part.rm == true or part.tran == "usb" or diskRemovable
				if
					part.type == "part"
					and removable
					and isNonEmptyString(part.fstype)
					and isNonEmptyString(part.path)
					and not isEsp(part)
				then
					local label = isNonEmptyString(part.label) and part.label or nil
					local mountpoint = isNonEmptyString(part.mountpoint) and part.mountpoint or nil
					local rmConfirmed = part.rm == true or diskRm
					table.insert(devices, {
						path = part.path,
						label = label,
						mounted = mountpoint ~= nil,
						mountpoint = mountpoint,
						category = rmConfirmed and "rm" or "usb",
					})
				end
			end
		end
	end
	return devices
end

local function anyMounted(devices)
	for _, device in ipairs(devices) do
		if device.mounted then
			return true
		end
	end
	return false
end

local function updateTooltip(devices)
	if #devices == 0 then
		barWidget.clearTooltip()
		return
	end
	local names = {}
	for _, device in ipairs(devices) do
		table.insert(names, device.label or device.path)
	end
	barWidget.setTooltip("Removable Drives: " .. table.concat(names, ", "))
end

local function refresh()
	if not noctalia.commandExists("lsblk") then
		barWidget.setVisible(false)
		return
	end
	noctalia.runAsync(LSBLK_CMD, function(result)
		if result.timedOut or result.exitCode ~= 0 then
			return
		end
		local data = noctalia.json.decode(result.stdout or "")
		local devices = parseDevices(data)
		noctalia.state.set("devices", devices)
		barWidget.setVisible(#devices > 0)
		barWidget.setGlyphColor(anyMounted(devices) and MOUNTED_GLYPH_COLOR or UNMOUNTED_GLYPH_COLOR)
		updateTooltip(devices)
	end, 5000)
end

-- The terminal command setting lives on [[widget.setting]] (this entry), so
-- it is only readable through noctalia.getConfig here (it resolves against
-- the calling entry's own settings context); bridge it through
-- noctalia.state the same way the device list is shared, so panel.luau can
-- read it without assuming its own getConfig sees another entry's settings.
local function publishTerminalCommand()
	local ok, terminalCommand = pcall(function()
		return noctalia.getConfig("terminal_command")
	end)
	if not ok or not isNonEmptyString(terminalCommand) then
		terminalCommand = "ghostty -e"
	end
	noctalia.state.set("terminal_command", terminalCommand)
end

barWidget.setGlyph(BAR_GLYPH)
barWidget.setVisible(false)
noctalia.setUpdateInterval(POLL_INTERVAL_MS)
publishTerminalCommand()
refresh()

function update()
	publishTerminalCommand()
	refresh()
end

function onClick()
	noctalia.togglePanel("arreborn/removable-drives:panel")
end
