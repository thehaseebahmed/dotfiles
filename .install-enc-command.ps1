function Install-Rage {
    # Check if 'rage' is already installed
    if (Get-Command rage -ErrorAction SilentlyContinue) {
        Write-Host "[WARN] rage already installed."
        exit 0
    }

    Write-Host "Installing rage..."

    if (Get-Command winget -ErrorAction SilentlyContinue) {
                winget install str4d.rage -e --accept-source-agreements --accept-package-agreements
            }
            else {
                Write-Host "[ERROR] No supported package manager found (winget required)."
                exit 1
            }

    Write-Host "[OK] rage installed."
}


Install-Rage
