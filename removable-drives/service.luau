-- Removable Drives — detection service.
--
-- The single place that watches for drives: snapshots `lsblk -J`, publishes
-- the removable, mountable partitions as noctalia.state "devices", and sends
-- the "New drive detected" notification. Bar widgets (one per bar) and the
-- panel only read that state. Nothing here ever mounts a drive.
--
-- Detection is event-driven via `udevadm monitor -u -s block`. `-u` limits it
-- to UDEV-tagged lines, emitted after udev's rules have populated properties
-- like the filesystem label; the KERNEL-tagged line for the same event would
-- race lsblk into reading a not-yet-populated label. runStream does not
-- respawn a dead subprocess, so a slow poll stays on as a safety net, and
-- plain polling is used when udevadm is unavailable.
local POLL_INTERVAL_MS = 4000
local EVENT_FALLBACK_POLL_INTERVAL_MS = 45000
local LSBLK_CMD = "lsblk -J -o NAME,PATH,TYPE,FSTYPE,LABEL,RM,MOUNTPOINT,TRAN,PARTTYPE"
local UDEV_MONITOR_CMD = "udevadm monitor -u -s block"

-- GPT partition-type GUID of the EFI System Partition. Matched by GUID rather
-- than label, since a user's own vfat partition may legitimately be "EFI".
local ESP_PARTTYPE_GUID = "c12a7328-f81f-11d2-ba4b-00a0c93ec93b"

-- freedesktop icon name, resolved by the notification daemon's icon theme.
local ICON_DETECTED = "drive-removable-media"

local function isNonEmptyString(value)
	return type(value) == "string" and value ~= ""
end

local function isEsp(part)
	local partType = part.parttype
	return isNonEmptyString(partType) and string.lower(partType) == ESP_PARTTYPE_GUID
end

-- A partition counts as removable when it or its parent disk reports RM, or is
-- attached over USB: many external drive bridge chips answer RM=0 despite
-- being hot-pluggable. `category` is "rm" when RM was confirmed (flash-drive
-- like) and "usb" when only TRAN qualified it; the panel picks a glyph by it.
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

-- Drives already present when the service starts are not "new": the first
-- snapshot only seeds knownPaths.
local knownPaths = {}
local sawInitialSnapshot = false

local function notifyNewDevices(devices)
	local currentPaths = {}
	for _, device in ipairs(devices) do
		currentPaths[device.path] = true
		if sawInitialSnapshot and not knownPaths[device.path] then
			noctalia.runAsync({
				"notify-send",
				"-u",
				"low",
				"-t",
				"5000",
				"-a",
				"Noctalia",
				"-i",
				ICON_DETECTED,
				"New drive detected",
				(device.label or device.path) .. " detected!",
			})
		end
	end
	knownPaths = currentPaths
	sawInitialSnapshot = true
end

local function refresh()
	if not noctalia.commandExists("lsblk") then
		noctalia.state.set("devices", {})
		return
	end
	noctalia.runAsync(LSBLK_CMD, function(result)
		if result.timedOut or result.exitCode ~= 0 then
			return
		end
		local devices = parseDevices((noctalia.json.decode(result.stdout or "")))
		notifyNewDevices(devices)
		noctalia.state.set("devices", devices)
	end, 5000)
end

-- Event lines look like "UDEV  [12345.678] add ... (block)"; the "%[" skips
-- udevadm's startup banner, which also begins with "UDEV".
local function onUdevLine(line)
	if type(line) == "string" and line:match("^UDEV%s+%[") then
		refresh()
	end
end

refresh()

if noctalia.commandExists("udevadm") and noctalia.runStream(UDEV_MONITOR_CMD, onUdevLine) then
	noctalia.setUpdateInterval(EVENT_FALLBACK_POLL_INTERVAL_MS)
else
	noctalia.log("removable-drives: udevadm monitor unavailable; falling back to interval polling")
	noctalia.setUpdateInterval(POLL_INTERVAL_MS)
end

function update()
	refresh()
end
