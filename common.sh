#!/bin/bash

# Other Environment Variable
export XZ_DEFAULTS="-T 0"

check_var() {
    local name=$1
    local value=$2
    if [ "$value" == "" ]; then
        echo "Missing var: $name"
        exit 1
    fi
}

check_path() {
    local name=$1
    local path=$2
    if [ ! -e "$path" ]; then
        echo "Missing file/dir: $name"
        exit 1
    fi
}
