#!/usr/bin/env bash

if [[ ! -e vars.source ]]; then
	echo "'vars.source' not found\n"
	exit 1
fi

. ./vars.source

source_pathfile="$source_path"/objects

[[ ! -e $source_pathfile ]] && ./build-objects.sh

grep '.Init()' "$source_pathfile" | sort
