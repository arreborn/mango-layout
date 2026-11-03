-- Removable Drives — mount/unmount panel.
--
-- The device list comes from service.luau through noctalia.state (this
-- script never runs lsblk itself). Mount/unmount goes
-- through udisksctl, with the local copy of the clicked device updated
-- optimistically so the row flips state immediately instead of waiting for
-- the next poll; the next state update from the service reconciles it with
-- reality either way, so an unmount never makes a device disappear from this
-- list on its own — only lsblk no longer reporting it does that.

local ICON_UNMOUNT = "media-eject"
local ICON_ERROR = "dialog-error"

-- Per-row glyph by service.luau's `category`: "rm" for a confirmed removable
-- device (flash drive), "usb" for one that only qualified via TRAN=="usb".
local GLYPH_RM = "usb"
local GLYPH_USB = "server-2"

local devicesByPath = {} -- path -> { path, label, mounted, mountpoint }
local order = {} -- paths, in the order lsblk reported them
local busyPaths = {} -- path -> true while a mount/unmount is in flight

local render

local function shellQuote(value)
	return "'" .. tostring(value):gsub("'", "'\\''") .. "'"
end

local function trim(value)
	return (tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

local function displayName(device)
	if type(device.label) == "string" and device.label ~= "" then
		return device.label
	end
	return device.path
end

local function notifySend(icon, title, body, timeoutMs)
	noctalia.runAsync({
		"notify-send",
		"-u",
		"low",
		"-t",
		tostring(timeoutMs or 5000),
		"-a",
		"Noctalia",
		"-i",
		icon,
		title,
		body or "",
	})
end

local function applyDeviceList(list)
	if type(list) ~= "table" then
		list = {}
	end
	local newByPath, newOrder = {}, {}
	for _, entry in ipairs(list) do
		if type(entry) == "table" and type(entry.path) == "string" and entry.path ~= "" then
			newByPath[entry.path] = {
				path = entry.path,
				label = entry.label,
				mounted = entry.mounted == true,
				mountpoint = entry.mountpoint,
				category = entry.category,
			}
			table.insert(newOrder, entry.path)
		end
	end
	devicesByPath = newByPath
	order = newOrder
	-- A device that vanished (unplugged) can no longer be "in flight".
	for path in pairs(busyPaths) do
		if devicesByPath[path] == nil then
			busyPaths[path] = nil
		end
	end
	render()
end

-- runInTerminal runs the command through `sh -lc` in $TERMINAL, so the mount
-- point is quoted exactly once, for that shell.
local function openTerminal(mountpoint)
	if type(mountpoint) ~= "string" or mountpoint == "" then
		return
	end
	noctalia.runInTerminal("cd " .. shellQuote(mountpoint) .. ' && exec "${SHELL:-sh}"')
end

local function mountDevice(path)
	local device = devicesByPath[path]
	if device == nil or busyPaths[path] then
		return
	end
	if not noctalia.commandExists("udisksctl") then
		notifySend(ICON_ERROR, "Removable Drives", "udisksctl was not found; install udisks2 to mount drives.", 8000)
		return
	end
	busyPaths[path] = true
	render()
	noctalia.runAsync({ "udisksctl", "mount", "-b", path, "--no-user-interaction" }, function(result)
		busyPaths[path] = nil
		local current = devicesByPath[path]
		if current == nil then
			render()
			return
		end
		if not result.timedOut and result.exitCode == 0 then
			local mountpoint = (result.stdout or ""):match("at%s+(.-)%.?%s*$")
			current.mounted = true
			current.mountpoint = mountpoint
		else
			local reason = trim(result.stderr)
			if reason == "" then
				reason = "unknown error"
			end
			notifySend(ICON_ERROR, "Mount failed", displayName(current) .. ": " .. reason, 8000)
		end
		render()
	end, 20000)
end

local function unmountDevice(path)
	local device = devicesByPath[path]
	if device == nil or busyPaths[path] then
		return
	end
	if not noctalia.commandExists("udisksctl") then
		notifySend(ICON_ERROR, "Removable Drives", "udisksctl was not found; install udisks2 to unmount drives.", 8000)
		return
	end
	busyPaths[path] = true
	render()
	noctalia.runAsync({ "udisksctl", "unmount", "-b", path }, function(result)
		busyPaths[path] = nil
		local current = devicesByPath[path]
		if current == nil then
			render()
			return
		end
		if not result.timedOut and result.exitCode == 0 then
			local name = displayName(current)
			current.mounted = false
			current.mountpoint = nil
			notifySend(ICON_UNMOUNT, "Drive unmounted", "You can now safely unplug " .. name .. ".")
		else
			local reason = trim(result.stderr)
			if reason == "" then
				reason = "unknown error"
			end
			notifySend(ICON_ERROR, "Unmount failed!", displayName(current) .. ": " .. reason, 8000)
		end
		render()
	end, 20000)
end

local function deviceLabelNode(device)
	local text = displayName(device)
	if device.mounted and type(device.mountpoint) == "string" and device.mountpoint ~= "" then
		return ui.button({
			key = "label-" .. device.path,
			text = text,
			variant = "ghost",
			contentAlign = "start",
			flexGrow = 1,
			onClick = function()
				openTerminal(device.mountpoint)
				panel.close()
			end,
		})
	end
	return ui.label({
		key = "label-" .. device.path,
		text = text,
		flexGrow = 1,
	})
end

local function toggleButtonNode(device)
	local path = device.path
	local mounted = device.mounted
	return ui.button({
		key = "toggle-" .. path,
		glyph = mounted and "plug-off" or "plug-connected",
		text = mounted and "Unmount" or "Mount",
		variant = "ghost",
		onClick = function()
			if mounted then
				unmountDevice(path)
			else
				mountDevice(path)
			end
		end,
	})
end

local function deviceGlyphNode(device)
	return ui.glyph({
		key = "glyph-" .. device.path,
		name = device.category == "rm" and GLYPH_RM or GLYPH_USB,
		size = 16,
	})
end

local function deviceRow(device)
	return ui.row({ key = "row-" .. device.path, gap = 8, align = "center" }, {
		deviceGlyphNode(device),
		deviceLabelNode(device),
		toggleButtonNode(device),
	})
end

render = function()
	local rows = {}
	for _, path in ipairs(order) do
		local device = devicesByPath[path]
		if device ~= nil then
			table.insert(rows, deviceRow(device))
		end
	end
	if #rows == 0 then
		table.insert(
			rows,
			ui.label({
				key = "empty",
				text = "No removable drives connected.",
				color = "on_surface_variant",
			})
		)
	end

	panel.render(ui.column({ flexGrow = 1, gap = 8, align = "stretch" }, {
		ui.scroll({ key = "devices", flexGrow = 1, gap = 4 }, rows),
	}))
end

noctalia.state.watch("devices", applyDeviceList)

function onOpen(_context)
	applyDeviceList(noctalia.state.get("devices"))
end

function onClosePanel()
	panel.close()
end
