#!/bin/bash

# Other Environment Variable
export XZ_DEFAULTS="-T 0"

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
