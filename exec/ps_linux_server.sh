#!/bin/sh
echo -ne '\033c\033]0;ProblemSolvers\a'
base_path="$(dirname "$(realpath "$0")")"
"$base_path/ps_linux_server.x86_64" "$@"
