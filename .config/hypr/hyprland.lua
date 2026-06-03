-- Modules in hyprland-lua/

-- Add hyprland-lua to package path
package.path = package.path .. ";" .. os.getenv("HOME") .. "/.config/hypr/hyprland/?.lua"

-- Load programs first for use in other modules
_G.programs = require("programs")

require("monitors")
require("autostart")
require("env")
require("permissions")
require("appearance")
require("inputs")
require("keybinds")
require("rules")
require("animations")
