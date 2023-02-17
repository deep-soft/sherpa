#!/usr/bin/env bash

if [[ -e vars.source ]]; then
	. ./vars.source
else
	echo "'vars.source' not found"
	exit 1
fi

source_pathfile="$source_path"/objects

grep '.Init()' "$source_pathfile" | sort
