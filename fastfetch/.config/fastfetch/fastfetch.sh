#!/bin/bash
# Ashen — fastfetch. Runs when a new terminal opens and on every `clear`
# (see the precmd hook in ~/.zshrc).
# --pipe false: during p10k instant prompt stdout is redirected, so fastfetch
# would auto-disable colour (renders white) on the first open until `clear`.
# Forcing pipe off keeps colour even when it thinks it isn't a tty.
exec fastfetch --pipe false --config "$HOME/.config/fastfetch/config.jsonc"
