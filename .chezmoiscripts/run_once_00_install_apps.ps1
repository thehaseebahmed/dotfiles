function Main {
    Check-PackageManagers

    Install-Cargo
    Install-Metapac
}

function Check-PackageManagers {
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        return
    }

    Write-Host "[ERROR] No supported package manager found (winget required)."
    exit 1
}

function Clean-Bloatware {
    Write-Host "Cleaning bloatware..."
    winget uninstall "Microsoft Sticky Notes" "Microsoft Solitaire Collection" "Microsoft People" "Outlook for Windows" "Power Automate" "Microsoft Whiteboard" "Windows Maps" "Microsoft Family" "Mail and Calendar"
    Write-Host "[OK] bloatware cleaned."
}

function Install-Cargo {
    if (Get-Command cargo -ErrorAction SilentlyContinue) {
        Write-Host "[WARN] cargo already installed."
        return
    }

    Write-Host "Installing cargo..."
    winget install Rustlang.Rustup Rustlang.Rust.MSVC -e --accept-source-agreements --accept-package-agreements
    Write-Host "[OK] cargo installed."
}

function Install-Metapac {
    if (Get-Command metapac -ErrorAction SilentlyContinue) {
        Write-Host "[WARN] metapac already installed.."
        return
    }

    Write-Host "Installing metapac..."

    winget install Microsoft.VisualStudio.2022.BuildTools -e --accept-source-agreements --accept-package-agreements
    cargo install metapac

    Write-Host "[OK] metapac installed."
}


Main