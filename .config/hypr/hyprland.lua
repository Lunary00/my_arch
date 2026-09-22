-- ============================================================================
-- hyprland.lua - Configuracao do Hyprland
-- Wiki: https://wiki.hypr.land/Configuring/Start/
-- ============================================================================
-- LAYOUTS DE MONITOR (aplicados automaticamente):
--   TRABALHO : eDP-1 (notebook) + 2 Dell (5MJ7XT3 esquerda, 5K97XT3 direita)
--   CASA     : eDP-1 (notebook, esquerda) + ultrawide LG 25UM58G (direita)
-- Os monitores sao identificados por desc: (imutavel entre reinicios).
-- O layout dinamico e aplicado por ~/.config/hypr/scripts/monitores.sh,
-- disparado no autostart e a cada hotplug/reload por monitor-watch.py.
-- ============================================================================
-- Dica: da pra dividir esta config em varios arquivos e carregar com
-- require("nome_do_arquivo").

------------------
---- MONITORS ----
------------------

-- See https://wiki.hypr.land/Configuring/Basics/Monitors/
-- Identificacao por DESCRICAO (desc:) - nao muda quando o nome da porta
-- (DP-1, HDMI-A-1, DVI-I-1...) trocar entre reinicios.
-- IMPORTANTE: o desc: precisa ser a DESCRICAO COMPLETA (nao so o serial).
--
-- Estes blocos abaixo sao o layout padrao (TRABALHO). O layout dinamico
-- (CASA = notebook + ultrawide LG) e aplicado automaticamente pelo script
-- ~/.config/hypr/scripts/monitores.sh, chamado no autostart e a cada evento
-- de hotplug/reload pelo watcher monitor-watch.py.
-- Projetor casa
hl.monitor({
	output = "desc:In Focus Systems Inc Projector crhp13400067",
	mode = "1366x766",
	position = "1366x0",
	scale = "1.0",
})
-- Notebook (padrao trabalho)
hl.monitor({
	output = "desc:BOE NV153WUM-N41",
	mode = "preferred",
	position = "1280x1080",
	scale = "1.5",
})

-- Dell da ESQUERDA (serial 5MJ7XT3)
hl.monitor({
	output = "desc:Dell Inc. DELL E2222HS 5MJ7XT3",
	mode = "1920x1080@60",
	position = "0x0",
	scale = "1.0",
})

-- Dell da DIREITA (serial 5K97XT3)
hl.monitor({
	output = "desc:Dell Inc. DELL E2222HS 5K97XT3",
	mode = "1920x1080@60",
	position = "1920x0",
	scale = "1.0",
})

---------------------
---- MY PROGRAMS ----
---------------------

-- Set programs that you use
local terminal = "kitty"
local fileManager = "dolphin"
local menu = "hyprlauncher"

-------------------
---- AUTOSTART ----
-------------------
-- See https://wiki.hypr.land/Configuring/Basics/Autostart/
hl.on("hyprland.start", function()
	hl.exec_cmd(terminal)
	-- Layout de monitores (trabalho/casa) + watcher de hotplug
	hl.exec_cmd("~/.config/hypr/scripts/monitores.sh")
	hl.exec_cmd("python3 ~/.config/hypr/scripts/monitor-watch.py")
	-- hl.exec_cmd("nm-applet")
end)

-------------------------
---- ENVIRONMENT VARS ----
-------------------------

-- See https://wiki.hypr.land/Configuring/Advanced-and-Cool/Environment-variables/

hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")

-----------------------
----- PERMISSIONS -----
-----------------------

-- See https://wiki.hypr.land/Configuring/Advanced-and-Cool/Permissions/
-- Please note permission changes here require a Hyprland restart and are not applied on-the-fly
-- for security reasons

-- hl.config({
--   ecosystem = {
--     enforce_permissions = true,
--   },
-- })

-- hl.permission("/usr/(bin|local/bin)/grim", "screencopy", "allow")
-- hl.permission("/usr/(lib|libexec|lib64)/xdg-desktop-portal-hyprland", "screencopy", "allow")
-- hl.permission("/usr/(bin|local/bin)/hyprpm", "plugin", "allow")

-----------------------
---- LOOK AND FEEL ----
-----------------------

-- Refer to https://wiki.hypr.land/Configuring/Basics/Variables/
hl.config({
	general = {
		gaps_in = 3,
		gaps_out = 2,

		border_size = 2,

		-- col = {
		--     active_border   = { colors = {"rgba(33ccffee)", "rgba(00ff99ee)"}, angle = 45 },
		--     inactive_border = "rgba(595959aa)",
		--},
		col = {
			active_border = "rgba(22, 64, 92, 1.0)",
			inactive_border = "rgb(10, 28, 46)",
		},

		-- Set to true to enable resizing windows by clicking and dragging on borders and gaps
		resize_on_border = false,

		-- Please see https://wiki.hypr.land/Configuring/Advanced-and-Cool/Tearing/ before you turn this on
		allow_tearing = false,

		layout = "dwindle",
	},

	decoration = {
		rounding = 10,
		rounding_power = 2,

		-- Change transparency of focused and unfocused windows
		active_opacity = 1.0,
		inactive_opacity = 1.0,

		shadow = {
			enabled = true,
			range = 5,
			render_power = 100,
			color = 0x44000000,
		},

		blur = {
			enabled = true,
			size = 3,
			passes = 1,
			--vibrancy  = 0.1696,
			vibrancy = 0.0,
		},
	},

	animations = {
		enabled = true,
	},
})

-- Default curves and animations, see https://wiki.hypr.land/Configuring/Advanced-and-Cool/Animations/
hl.curve("easeOutQuint", { type = "bezier", points = { { 0.23, 1 }, { 0.32, 1 } } })
hl.curve("easeInOutCubic", { type = "bezier", points = { { 0.65, 0.05 }, { 0.36, 1 } } })
hl.curve("linear", { type = "bezier", points = { { 0, 0 }, { 1, 1 } } })
hl.curve("almostLinear", { type = "bezier", points = { { 0.5, 0.5 }, { 0.75, 1 } } })
hl.curve("quick", { type = "bezier", points = { { 0.15, 0 }, { 0.1, 1 } } })

-- Default springs
hl.curve("easy", { type = "spring", mass = 1, stiffness = 71.2633, dampening = 15.8273644 })

hl.animation({ leaf = "global", enabled = true, speed = 10, bezier = "default" })
hl.animation({ leaf = "border", enabled = true, speed = 5.39, bezier = "easeOutQuint" })
hl.animation({ leaf = "windows", enabled = true, speed = 4.79, spring = "easy" })
hl.animation({ leaf = "windowsIn", enabled = true, speed = 4.1, spring = "easy", style = "popin 87%" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 1.49, bezier = "linear", style = "popin 87%" })
hl.animation({ leaf = "fadeIn", enabled = true, speed = 1.73, bezier = "almostLinear" })
hl.animation({ leaf = "fadeOut", enabled = true, speed = 1.46, bezier = "almostLinear" })
hl.animation({ leaf = "fade", enabled = true, speed = 3.03, bezier = "quick" })
hl.animation({ leaf = "layers", enabled = true, speed = 3.81, bezier = "easeOutQuint" })
hl.animation({ leaf = "layersIn", enabled = true, speed = 4, bezier = "easeOutQuint", style = "fade" })
hl.animation({ leaf = "layersOut", enabled = true, speed = 1.5, bezier = "linear", style = "fade" })
hl.animation({ leaf = "fadeLayersIn", enabled = true, speed = 1.79, bezier = "almostLinear" })
hl.animation({ leaf = "fadeLayersOut", enabled = true, speed = 1.39, bezier = "almostLinear" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 1.94, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "workspacesIn", enabled = true, speed = 1.21, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "workspacesOut", enabled = true, speed = 1.94, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "zoomFactor", enabled = true, speed = 7, bezier = "quick" })

-- Ref https://wiki.hypr.land/Configuring/Basics/Workspace-Rules/
-- "Smart gaps" / "No gaps when only"
-- uncomment all if you wish to use that.
-- hl.workspace_rule({ workspace = "w[tv1]", gaps_out = 0, gaps_in = 0 })
-- hl.workspace_rule({ workspace = "f[1]",   gaps_out = 0, gaps_in = 0 })
-- hl.window_rule({
--     name  = "no-gaps-wtv1",
--     match = { float = false, workspace = "w[tv1]" },
--     border_size = 0,
--     rounding    = 0,
-- })
-- hl.window_rule({
--     name  = "no-gaps-f1",
--     match = { float = false, workspace = "f[1]" },
--     border_size = 0,
--     rounding    = 0,
-- })

-- See https://wiki.hypr.land/Configuring/Layouts/Dwindle-Layout/ for more
hl.config({
	dwindle = {
		preserve_split = true, -- You probably want this
	},
})

-- See https://wiki.hypr.land/Configuring/Layouts/Master-Layout/ for more
hl.config({
	master = {
		new_status = "master",
	},
})

-- See https://wiki.hypr.land/Configuring/Layouts/Scrolling-Layout/ for more
hl.config({
	scrolling = {
		fullscreen_on_one_column = true,
	},
})

----------------
----  MISC  ----
----------------

hl.config({
	misc = {
		force_default_wallpaper = 0, -- Set to 0 or 1 to disable the anime mascot wallpapers
		disable_hyprland_logo = true, -- If true disables the random hyprland logo / anime girl background. :(
	},
})

hl.config({
	xwayland = {
		force_zero_scaling = true,
	},
})

---------------
---- INPUT ----
---------------

hl.config({
	input = {
		-- Dois layouts: indice 0 = br (trabalho), indice 1 = us (casa).
		-- A troca automatica e feita pelo monitores.sh; ha tambem um atalho
		-- (Super + K) para alternar manualmente.
		kb_layout = "br,us",
		kb_variant = "",
		kb_model = "",
		kb_options = "",
		kb_rules = "",

		follow_mouse = 1,

		sensitivity = 0, -- -1.0 - 1.0, 0 means no modification.

		touchpad = {
			natural_scroll = false,
		},
	},
})

hl.gesture({
	fingers = 3,
	direction = "horizontal",
	action = "workspace",
})

-- Example per-device config
-- See https://wiki.hypr.land/Configuring/Advanced-and-Cool/Devices/ for more
hl.device({
	name = "epic-mouse-v1",
	sensitivity = -0.5,
})

---------------------
---- KEYBINDINGS ----
---------------------

local mainMod = "SUPER" -- Sets "Windows" key as main modifier

-- Example binds, see https://wiki.hypr.land/Configuring/Basics/Binds/ for more
hl.bind(mainMod .. " + Q", hl.dsp.exec_cmd(terminal))
local closeWindowBind = hl.bind(mainMod .. " + W", hl.dsp.window.close())
-- closeWindowBind:set_enabled(false)
hl.bind(
	mainMod .. "+ SHIFT + P",
	hl.dsp.exec_cmd("command -v hyprshutdown >/dev/null 2>&1 && hyprshutdown || hyprctl dispatch 'hl.dsp.exit()'")
)
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd(fileManager))
hl.bind(mainMod .. " + V", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + SPACE", hl.dsp.exec_cmd(menu))
hl.bind(mainMod .. " + P", hl.dsp.window.pseudo())
hl.bind(mainMod .. " + J", hl.dsp.layout("togglesplit")) -- dwindle only
hl.bind(mainMod .. " + F", hl.dsp.window.fullscreen({ action = "toggle" }))
hl.bind(
	mainMod .. " + L",
	hl.dsp.exec_cmd("sh -c 'hyprlock; sleep 0.5; hyprctl dispatch dpms on desc:Dell Inc. DELL E2222HS 5K97XT3'")
)

-- Alternar layout de teclado manualmente (br <-> us)
hl.bind(mainMod .. " + K", hl.dsp.exec_cmd("hyprctl switchxkblayout all next"))

-- Move focus with mainMod + arrow keys
hl.bind(mainMod .. " + left", hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + up", hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + down", hl.dsp.focus({ direction = "down" }))

-- Trocar a janela atual com a janela vizinha na direção da seta
hl.bind(mainMod .. " + SHIFT + left", hl.dsp.window.swap({ direction = "left" }))
hl.bind(mainMod .. " + SHIFT + right", hl.dsp.window.swap({ direction = "right" }))
hl.bind(mainMod .. " + SHIFT + up", hl.dsp.window.swap({ direction = "up" }))
hl.bind(mainMod .. " + SHIFT + down", hl.dsp.window.swap({ direction = "down" }))

-- Print

hl.bind(
	"Print",
	hl.dsp.exec_cmd(
		"mkdir -p ~/4_Media/screenshot && file=~/4_Media/screenshot/screenshot-$(date +'%Y%m%d-%H%M%S').png && if region=$(slurp); then grim -g \"$region\" \"$file\" && wl-copy < \"$file\" && notify-send 'Screenshot' 'Salvo e copiado para área de transferência'; fi"
	)
)
--hl.bind("Print", hl.dsp.exec_cmd("mkdir -p ~/4_Media/screenshot && file=~/4_Media/screenshot/screenshot-$(date +'%Y%m%d-%H%M%S').png && grim \"$file\" && wl-copy < \"$file\" && notify-send 'Screenshot' 'Salvo e copiado para área de transferência'"))

-- Switch workspaces with mainMod + [0-9]
-- Move active window to a workspace with mainMod + SHIFT + [0-9]
for i = 1, 10 do
	local key = i % 10 -- 10 maps to key 0
	hl.bind(mainMod .. " + " .. key, hl.dsp.focus({ workspace = i }))
	hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }))
end

-- Example special workspace (scratchpad)
hl.bind(mainMod .. " + S", hl.dsp.workspace.toggle_special("magic"))
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.window.move({ workspace = "special:magic" }))

-- Scroll through existing workspaces with mainMod + scroll
hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + mouse_up", hl.dsp.focus({ workspace = "e-1" }))

-- Move/resize windows with mainMod + LMB/RMB and dragging
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Laptop multimedia keys for volume and LCD brightness
hl.bind(
	"XF86AudioRaiseVolume",
	hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"),
	{ locked = true, repeating = true }
)
hl.bind(
	"XF86AudioLowerVolume",
	hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),
	{ locked = true, repeating = true }
)
hl.bind(
	"XF86AudioMute",
	hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),
	{ locked = true, repeating = true }
)
hl.bind(
	"XF86AudioMicMute",
	hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),
	{ locked = true, repeating = true }
)
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%+"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%-"), { locked = true, repeating = true })

-- Requires playerctl
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true })

--------------------------------
---- WINDOWS AND WORKSPACES ----
-------------------------------
-- See https://wiki.hypr.land/Configuring/Basics/Workspace-Rules/
-- Regras dos DOIS layouts podem coexistir: regras apontando para um monitor
-- ausente sao simplesmente ignoradas.
-- O script monitores.sh reaplica as regras do layout ativo (via eval) para
-- MOVER workspaces ja existentes e restaurar a persistencia ao trocar de local.

-- ===== Layout TRABALHO =====
-- Workspaces no monitor do laptop (desc:BOE NV153WUM-N41)
hl.workspace_rule({ workspace = "1", monitor = "desc:BOE NV153WUM-N41", persistent = true })
hl.workspace_rule({ workspace = "2", monitor = "desc:BOE NV153WUM-N41", persistent = true })

-- Workspaces no monitor Dell da esquerda (desc:Dell Inc. DELL E2222HS 5MJ7XT3)
hl.workspace_rule({ workspace = "3", monitor = "desc:Dell Inc. DELL E2222HS 5MJ7XT3", persistent = true })
hl.workspace_rule({ workspace = "4", monitor = "desc:Dell Inc. DELL E2222HS 5MJ7XT3", persistent = true })

-- Workspaces no monitor Dell da direita (desc:Dell Inc. DELL E2222HS 5K97XT3)
hl.workspace_rule({ workspace = "5", monitor = "desc:Dell Inc. DELL E2222HS 5K97XT3", persistent = true })
hl.workspace_rule({ workspace = "6", monitor = "desc:Dell Inc. DELL E2222HS 5K97XT3", persistent = true })

-- ===== Layout CASA =====
-- Workspaces 3,4,5 no ultrawide LG (desc:LG Electronics 25UM58G 0x000445DD)
hl.workspace_rule({ workspace = "3", monitor = "desc:LG Electronics 25UM58G 0x000445DD", persistent = true })
hl.workspace_rule({ workspace = "4", monitor = "desc:LG Electronics 25UM58G 0x000445DD", persistent = true })
hl.workspace_rule({ workspace = "5", monitor = "desc:LG Electronics 25UM58G 0x000445DD", persistent = true })

-- Example window rules that are useful

local suppressMaximizeRule = hl.window_rule({
	-- Ignore maximize requests from all apps. You'll probably like this.
	name = "suppress-maximize-events",
	match = { class = ".*" },

	suppress_event = "maximize",
})
--suppressMaximizeRule:set_enabled(false)

hl.window_rule({
	-- Fix some dragging issues with XWayland
	name = "fix-xwayland-drags",
	match = {
		class = "^$",
		title = "^$",
		xwayland = true,
		float = true,
		fullscreen = false,
		pin = false,
	},

	no_focus = true,
})

-- Layer rules also return a handle.
-- local overlayLayerRule = hl.layer_rule({
--     name  = "no-anim-overlay",
--     match = { namespace = "^my-overlay$" },
--     no_anim = true,
-- })
-- overlayLayerRule:set_enabled(false)

-- Hyprland-run windowrule
hl.window_rule({
	name = "move-hyprland-run",
	match = { class = "hyprland-run" },

	move = "20 monitor_h-120",
	float = true,
})

-- Hyprlock - desabilita animações para evitar tela fantasma
hl.window_rule({
	name = "disable-anim-hyprlock",
	match = { class = "hyprlock" },
	no_anim = true,
})
