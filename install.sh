#!/usr/bin/env bash
# Instala as ferramentas usadas pelos cheats e configura o navi no shell.
# Funciona no macOS (Homebrew) e no Linux (apt, dnf ou pacman).
#
# Uso:
#   ./install.sh              instala tudo
#   ./install.sh --skip-node  não instala nvm, Node e pnpm
#
# Pode rodar quantas vezes quiser: o que já existe é mantido.

set -euo pipefail

NVM_VERSION="v0.40.1"
NAVI_INSTALL_URL="https://raw.githubusercontent.com/denisidoro/navi/master/scripts/install"
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHEATS_DIR="$REPO_DIR/cheats"
MARK_BEGIN="# >>> dev-notes >>>"
MARK_END="# <<< dev-notes <<<"

SKIP_NODE=false
for arg in "$@"; do
	case "$arg" in
		--skip-node) SKIP_NODE=true ;;
		-h | --help)
			sed -n '2,9p' "$0" | sed 's/^# \{0,1\}//'
			exit 0
			;;
		*)
			echo "Opção desconhecida: $arg" >&2
			exit 1
			;;
	esac
done

info() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m!!\033[0m %s\n' "$*" >&2; }
has() { command -v "$1" >/dev/null 2>&1; }

sudo_cmd() {
	if [ "$(id -u)" -eq 0 ]; then "$@"; else sudo "$@"; fi
}

# ---------------------------------------------------------------------------
# Pacotes do sistema
# ---------------------------------------------------------------------------

install_macos() {
	if ! has brew; then
		info "Instalando o Homebrew"
		/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
		# Apple Silicon instala em /opt/homebrew; Intel em /usr/local.
		for prefix in /opt/homebrew /usr/local; do
			[ -x "$prefix/bin/brew" ] && eval "$("$prefix/bin/brew" shellenv)"
		done
	fi

	info "Instalando pacotes com o Homebrew"
	# git, curl e dig já vêm com o macOS.
	brew install navi fzf ripgrep jq
}

install_linux() {
	if has apt-get; then
		info "Instalando pacotes com o apt"
		sudo_cmd apt-get update
		sudo_cmd apt-get install -y git curl fzf ripgrep jq dnsutils
	elif has dnf; then
		info "Instalando pacotes com o dnf"
		sudo_cmd dnf install -y git curl fzf ripgrep jq bind-utils
	elif has pacman; then
		info "Instalando pacotes com o pacman"
		sudo_cmd pacman -Sy --needed --noconfirm git curl fzf ripgrep jq bind navi
	else
		warn "Gerenciador de pacotes não suportado. Instale manualmente: git curl fzf ripgrep jq dig"
	fi

	if ! has navi; then
		info "Instalando o navi em ~/.local/bin"
		mkdir -p "$HOME/.local/bin"
		BIN_DIR="$HOME/.local/bin" bash <(curl -fsSL "$NAVI_INSTALL_URL")
		export PATH="$HOME/.local/bin:$PATH"
	fi
}

# ---------------------------------------------------------------------------
# Node (nvm + LTS + pnpm)
# ---------------------------------------------------------------------------

install_node() {
	export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"

	if [ ! -s "$NVM_DIR/nvm.sh" ]; then
		info "Instalando o nvm $NVM_VERSION"
		# PROFILE=/dev/null: a configuração do shell é feita abaixo, num bloco só.
		PROFILE=/dev/null bash -c "$(curl -fsSL "https://raw.githubusercontent.com/nvm-sh/nvm/$NVM_VERSION/install.sh")"
	fi

	# shellcheck disable=SC1091
	. "$NVM_DIR/nvm.sh"

	if ! nvm ls --no-colors lts/* >/dev/null 2>&1; then
		info "Instalando o Node LTS"
		nvm install --lts
	fi
	nvm alias default 'lts/*' >/dev/null

	if ! has pnpm; then
		info "Instalando o pnpm"
		npm install -g pnpm
	fi
}

# ---------------------------------------------------------------------------
# Configuração do shell
# ---------------------------------------------------------------------------

detect_rc_file() {
	case "$(basename "${SHELL:-}")" in
		zsh) echo "$HOME/.zshrc" ;;
		bash) [ "$(uname -s)" = Darwin ] && echo "$HOME/.bash_profile" || echo "$HOME/.bashrc" ;;
		*) echo "" ;;
	esac
}

configure_shell() {
	local rc shell_name
	rc="$(detect_rc_file)"
	shell_name="$(basename "${SHELL:-}")"

	if [ -z "$rc" ]; then
		warn "Shell '$shell_name' não suportado. Adicione manualmente ao seu rc:"
		warn "  export NAVI_PATH=\"$CHEATS_DIR\""
		return
	fi

	touch "$rc"

	# Remove uma configuração antiga feita à mão (as duas linhas do README antigo).
	if grep -q 'dev-notes/cheats' "$rc" && ! grep -q "$MARK_BEGIN" "$rc"; then
		info "Removendo a configuração manual antiga do navi em $rc"
		cp "$rc" "$rc.dev-notes.bak"
		grep -v -e 'NAVI_PATH=.*dev-notes/cheats' -e 'navi widget' "$rc.dev-notes.bak" >"$rc"
	fi

	# Recria o bloco gerenciado (atualiza o caminho se o repo mudou de lugar).
	if grep -q "$MARK_BEGIN" "$rc"; then
		local tmp
		tmp="$(mktemp)"
		awk -v b="$MARK_BEGIN" -v e="$MARK_END" '
			$0 == b { skip = 1; next }
			$0 == e { skip = 0; next }
			!skip
		' "$rc" >"$tmp"
		cat "$tmp" >"$rc"
		rm -f "$tmp"
	fi

	# O rc pode já carregar o nvm por conta própria (instalação anterior).
	local load_nvm=false
	if [ "$SKIP_NODE" = false ] && ! grep -q 'nvm.sh' "$rc"; then
		load_nvm=true
	fi

	info "Configurando o navi em $rc"
	{
		[ -n "$(tail -n 1 "$rc")" ] && echo ""
		echo "$MARK_BEGIN"
		echo "export PATH=\"\$HOME/.local/bin:\$PATH\""
		echo "export NAVI_PATH=\"$CHEATS_DIR\""
		echo "eval \"\$(navi widget $shell_name)\"  # Ctrl+G abre o navi"
		if [ "$load_nvm" = true ]; then
			echo "export NVM_DIR=\"\$HOME/.nvm\""
			echo "[ -s \"\$NVM_DIR/nvm.sh\" ] && . \"\$NVM_DIR/nvm.sh\""
		fi
		echo "$MARK_END"
	} >>"$rc"
}

# ---------------------------------------------------------------------------

main() {
	case "$(uname -s)" in
		Darwin) install_macos ;;
		Linux) install_linux ;;
		*)
			warn "Sistema não suportado: $(uname -s)"
			exit 1
			;;
	esac

	if [ "$SKIP_NODE" = false ]; then
		install_node
	fi

	configure_shell

	info "Pronto. Abra um novo terminal (ou rode: source $(detect_rc_file)) e use Ctrl+G."
}

main
