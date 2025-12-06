#!/bin/sh

install_rage() {
    if eval "type rage >/dev/null 2>&1"; then
        echo "[WARN] rage already installed."
        exit 0
    fi

    info "Installing rage..."
    case "$(uname -s)" in
    Darwin)
        brew install rage
        ;;
    Linux)
        sudo pacman -S rage-encryption
        ;;
    *)
        echo "[ERROR] rage install failed! unsupported os"
        exit 1
        ;;
    esac

    echo "[OK] rage installed."
}