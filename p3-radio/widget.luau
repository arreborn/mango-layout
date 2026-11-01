-- P3 Radio — bar toggle.
--
-- Playback is owned by the `p3` CLI (`p3 toggle` starts/stops a transient
-- systemd user unit, p3-radio). This widget only toggles it and mirrors the
-- unit's state, so the radio keeps playing across shell restarts.
local UNIT = "p3-radio"
local NOW_PLAYING_URL = "https://api.sr.se/api/v2/playlists/rightnow?channelid=164&format=json"
local TICK_MS = 3000
local NOW_PLAYING_EVERY_TICKS = 10 -- ~30s

local playing = false
local ticksSinceFetch = NOW_PLAYING_EVERY_TICKS
local nowPlaying = "P3"

local function songText(song)
	if type(song) ~= "table" or type(song.title) ~= "string" then
		return nil
	end
	if type(song.artist) == "string" and song.artist ~= "" then
		return song.artist .. " – " .. song.title
	end
	return song.title
end

local function render()
	barWidget.setGlyph(if playing then "radio" else "radio-off")
	barWidget.setGlyphColor(if playing then "tertiary" else "on_surface")
	barWidget.setTooltip(if playing then nowPlaying else "P3 (off)")
end

local function fetchNowPlaying()
	noctalia.http({ url = NOW_PLAYING_URL, follow_redirects = true }, function(response)
		if not response.ok or response.status ~= 200 then
			return
		end
		local data = noctalia.json.decode(response.body)
		local playlist = data and data.playlist
		if type(playlist) ~= "table" then
			return
		end
		local current = songText(playlist.song)
		local previous = songText(playlist.previoussong)
		if current then
			nowPlaying = "P3 — " .. current
		elseif previous then
			nowPlaying = "P3 — last played: " .. previous
		else
			nowPlaying = "P3"
		end
		render()
	end)
end

local function refresh()
	noctalia.runAsync("systemctl --user is-active --quiet " .. UNIT, function(result)
		local nowActive = result.exitCode == 0
		if nowActive and not playing then
			ticksSinceFetch = NOW_PLAYING_EVERY_TICKS
		end
		playing = nowActive
		if playing then
			ticksSinceFetch += 1
			if ticksSinceFetch >= NOW_PLAYING_EVERY_TICKS then
				ticksSinceFetch = 0
				fetchNowPlaying()
			end
		end
		render()
	end, 2000)
end

render()
refresh()
noctalia.setUpdateInterval(TICK_MS)

function update()
	refresh()
end

function onClick()
	noctalia.runAsync("p3 toggle", function()
		refresh()
	end, 5000)
end
