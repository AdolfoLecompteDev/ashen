-- ══════════════════════════════════════════
--   Ashen — Window Rules
-- ══════════════════════════════════════════

-- Special Workspaces
hl.window_rule({ match = { class = "brave-cinhimbnkkaeohfgghhklpknlkffjgod-Default" }, workspace = "special:music"   })
hl.window_rule({ match = { class = "discord"        }, workspace = "special:discord" })

-- Floating
hl.window_rule({ match = { class = "nwg-displays"    }, float = true })
hl.window_rule({ match = { class = "pavucontrol"     }, float = true })

-- Opacity: global active/inactive_opacity from decoration.lua drives every
-- window, except browsers: their content is dense enough that the frosted
-- glass made it unreadable, so they get a bump.
-- brave.* also catches the PWAs (whatsapp, youtube music...), whose class is
-- brave-<app-id>-Default. Steam's UI is CEF-based and just as dense.
hl.window_rule({ match = { class = "^(brave.*|firefox|chromium|google-chrome|steam)$" }, opacity = "0.96 0.92" })

-- Bar blur
hl.layer_rule({ match = { namespace = "quickshell:.*" }, blur = true })
hl.layer_rule({ match = { namespace = "quickshell:.*" }, ignore_alpha = 0.05 })
