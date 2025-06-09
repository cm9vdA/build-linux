#!/bin/bash

# Other Environment Variable
export XZ_DEFAULTS="-T 0"

# ========= Color Output =========
COLOR_RED='\033[0;31m'
COLOR_GREEN='\033[0;32m'
COLOR_YELLOW='\033[1;33m'
COLOR_BLUE='\033[1;34m'
COLOR_PURPLE='\033[1;35m'
COLOR_CYAN='\033[1;36m'
COLOR_WHITE='\033[1;37m'
COLOR_NC='\033[0m' # No Color

echo_info() { echo -e "${COLOR_GREEN}[INFO]${COLOR_NC} $1"; }
echo_warn() { echo -e "${COLOR_YELLOW}[WARN]${COLOR_NC} $1"; }
echo_error() { echo -e "${COLOR_RED}[ERROR]${COLOR_NC} $1"; }

echo_title() { echo -e "${COLOR_BLUE}$1${COLOR_NC}"; }
echo_menu() { echo -e "\t${COLOR_YELLOW}[$1]${COLOR_NC} $2"; }
echo_item() { printf "${COLOR_CYAN}%-18s${COLOR_NC} %s\n" "${1}:" "${2}"; }

check_param() {
	local name="$1"
	local value="${!name}"
	if [ -z "$value" ]; then
		echo "Missing Parameter [$name]"
		exit 1
	fi
}

check_var() {
	local name=$1
	local value=$2
	if [ "$value" == "" ]; then
		echo "Missing var: $name"
		exit 1
	fi
}

check_dependency() {
	local cmds=($1)
	local cmd
	for cmd in "${cmds[@]}"; do
		command -v "$cmd" >/dev/null || {
			echo_error "Command \"$cmd\" not found. Please install it."
			exit 1
		}
	done
}

link_file() {
	local path=$1
	local target=$2

	if [ ! -e "$path" ] && [ ! -e "$target" ]; then
		echo "Missing file/dir: $path or $target" >&2
		exit 1
	fi

	if [ -e "$path" ]; then
		ln -nfs "$path" "$target"
	fi
}

# compare version
# return:
#   -1: version1 < version2
#    0: version1 == version2
#    1: version1 > version2
compare_versions() {
	local version1="$1"
	local version2="$2"

	# sort -V 会自动按版本号比较
	local sorted
	sorted=$(printf "%s\n%s" "$version1" "$version2" | sort -V)

	if [ "$version1" = "$version2" ]; then
		echo 0
		return 0
	elif [ "$(echo "$sorted" | head -n1)" = "$version1" ]; then
		echo -1
		return 1
	else
		echo 1
		return 2
	fi
}
