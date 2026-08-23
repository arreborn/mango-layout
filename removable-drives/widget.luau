-- Removable Drives — bar icon.
--
-- Snapshots `lsblk -J` and keeps the icon hidden until at least one
-- removable, mountable partition is present. The full device list is
-- published through noctalia.state so the panel (a separate script) can read
-- and react to it without running lsblk itself. This plugin never auto-mounts
-- anything — plugging a drive in only makes it known.
--
-- Detection is event-driven, not polled: `udevadm monitor -u -s block`
-- (following the same noctalia.runStream pattern mango-layout/widget.luau
-- uses for `mmsg watch all-monitors`) re-runs the lsblk snapshot whenever a
-- real block-device add/remove/change event arrives, instead of on a fixed
-- timer. `-u` (--udev, without --kernel) means udevadm only ever emits
-- UDEV-tagged lines — the ones printed *after* udev's rule processing has
-- populated properties like the filesystem label. Confirmed live with
-- `udevadm monitor -k -u -p -s block` against a loop-mounted labeled vfat
-- image: the KERNEL-tagged line for the same event carries no ID_FS_LABEL
-- property at all, while the UDEV-tagged line ~10ms later does. Reacting to
-- an (unwanted) KERNEL line would race a subsequent lsblk snapshot into
-- reading a not-yet-populated label.
--
-- runStream does not auto-restart its subprocess if it dies (confirmed in
-- the host's LuauHost::startStream: the onExit callback only flips an
-- "alive" flag — nothing respawns the command), so a slow fallback poll
-- stays on as a safety net while the event stream is active. If udevadm
-- isn't available at all (or the stream fails to start), this falls back to
-- plain interval polling instead of doing nothing.
local POLL_INTERVAL_MS = 4000 -- pure polling fallback, used only if udevadm/runStream is unavailable
local EVENT_FALLBACK_POLL_INTERVAL_MS = 45000 -- safety-net poll alongside the udev event stream
local LSBLK_CMD = "lsblk -J -o NAME,PATH,TYPE,FSTYPE,LABEL,RM,MOUNTPOINT,TRAN,PARTTYPE"
local UDEV_MONITOR_CMD = "udevadm monitor -u -s block"

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

-- Bar glyph color when at least one known device is mounted. Verified live
-- against the C++ role table (src/ui/palette.h, kColorRoleTokens): the
-- palette only has primary/secondary/tertiary (+ their "on_" counterparts),
-- surface variants, outline, shadow, and hover/on_hover — there is no
-- dedicated "success"/"positive" role. `tertiary` is Material Design 3's
-- role for "a contrasting accent that draws attention to an element" (per
-- Google's M3 spec), which is the closest semantic fit here, and it's the
-- same pattern already used by other bundled/community plugins (e.g.
-- file-search's setGlyphColor("primary")/("on_surface") pair) — a plain
-- role token, not a fixed hex. No role renders as green across every
-- bundled palette (e.g. Ayu/Nord's tertiary is blue), which is expected and
-- accepted: a cohesive, theme-derived accent beats a hardcoded hex that
-- clashes with the active palette.
local MOUNTED_GLYPH_COLOR = "tertiary"
local UNMOUNTED_GLYPH_COLOR = "on_surface" -- the documented default/unset role

-- Same freedesktop icon name panel.luau's old mount-success notification used
-- (notify-send resolves icon *names* against the system icon theme, not the
-- tabler glyph font the bar/panel use, so this is unrelated to BAR_GLYPH).
local ICON_DETECTED = "drive-removable-media"

local function isNonEmptyString(value)
	return type(value) == "string" and value ~= ""
end

local function shellQuote(value)
	return "'" .. tostring(value):gsub("'", "'\\''") .. "'"
end

local function notifySend(icon, title, body, timeoutMs)
	local cmd = "notify-send -u low -t "
		.. tostring(timeoutMs or 5000)
		.. " -a "
		.. shellQuote("Noctalia")
		.. " -i "
		.. shellQuote(icon)
		.. " "
		.. shellQuote(title)
		.. " "
		.. shellQuote(body or "")
	noctalia.runAsync(cmd)
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

-- Tracks devices seen on the previous successful refresh so a notification
-- fires only for a path that genuinely just appeared, not for ones already
-- present. sawInitialSnapshot suppresses notifying for every drive that was
-- already plugged in at plugin load/reload — "detected" should mean "just
-- plugged in", not "the shell restarted while this was already connected".
local knownPaths = {}
local sawInitialSnapshot = false

local function notifyNewDevices(devices)
	local currentPaths = {}
	for _, device in ipairs(devices) do
		currentPaths[device.path] = true
		if sawInitialSnapshot and not knownPaths[device.path] then
			notifySend(ICON_DETECTED, "Drive", (device.label or device.path) .. " detected!")
		end
	end
	knownPaths = currentPaths
	sawInitialSnapshot = true
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
		notifyNewDevices(devices)
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

-- Only react to genuine UDEV-tagged event lines, formatted like
-- "UDEV  [12345.678] add ... (block)". `udevadm monitor` also prints a
-- startup banner ("UDEV - the event which udev sends out after rule
-- processing") that also begins with the literal word UDEV but isn't an
-- event — the "%[" after whitespace excludes that.
local function onUdevLine(line)
	if type(line) == "string" and line:match("^UDEV%s+%[") then
		refresh()
	end
end

barWidget.setGlyph(BAR_GLYPH)
barWidget.setVisible(false)
publishTerminalCommand()
refresh() -- initial enumeration always happens at load, independent of any event or timer

local usingEventStream = noctalia.commandExists("udevadm") and noctalia.runStream(UDEV_MONITOR_CMD, onUdevLine)
if usingEventStream then
	noctalia.setUpdateInterval(EVENT_FALLBACK_POLL_INTERVAL_MS)
else
	noctalia.log(
		"removable-drives: udevadm unavailable or monitor stream failed to start; falling back to interval polling"
	)
	noctalia.setUpdateInterval(POLL_INTERVAL_MS)
end

function update()
	publishTerminalCommand()
	refresh()
end

function onClick()
	noctalia.togglePanel("arreborn/removable-drives:panel")
end
