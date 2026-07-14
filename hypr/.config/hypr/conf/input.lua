-- ══════════════════════════════════════════
--   Ashen — Input
-- ══════════════════════════════════════════

hl.config({
    input = {
        -- latam is first, so it stays the default at login.
        -- Switching is done from Settings (hyprctl switchxkblayout), not a keybind.
        kb_layout = "latam,us",
        kb_variant = "",
        kb_model = "",
        kb_options = "",
        follow_mouse = 1,
        sensitivity = 0,
        touchpad = {
            natural_scroll = true,
            disable_while_typing = true,
            tap_to_click = true,
            scroll_factor = 0.5,
        },
    },
})

hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })
