local config = wezterm.config_builder()

config.audible_bell = 'Disabled'
config.font_size = 12
config.font = wezterm.font('Iosevka Custom')
config.color_scheme = 'ayu'

-- Tweak the `ayu` theme to match `neovim-ayu`:
local scheme = wezterm.get_builtin_color_schemes()['ayu']
-- https://github.com/Shatur/neovim-ayu/blob/e5a9f0fa2918d6b5f57c21b3ac014314ee5e41c8/lua/ayu/colors.lua#L56C20-L56C27
scheme.background = '#0B0E14'
config.color_schemes = { ['ayu'] = scheme }

return config
