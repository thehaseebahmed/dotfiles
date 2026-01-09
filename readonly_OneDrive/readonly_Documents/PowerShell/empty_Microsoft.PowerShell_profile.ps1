# Directory navigation
function .. { Set-Location .. }
function ... { Set-Location ../.. }

# Chezmoi
function cza { chezmoi apply -v }
function czd { chezmoi diff }

# Docker Compose
function dcd { docker compose down }
function dcr { docker compose down; docker compose up -d }
function dcu { docker compose up -d }

# Homelab SSH
function hl1 { ssh tha@homelab-001.lykoi-mark.ts.net }
function hl2 { ssh tha@homelab-002.lykoi-mark.ts.net }
function hl3 { ssh tha@homelab-003.lykoi-mark.ts.net }