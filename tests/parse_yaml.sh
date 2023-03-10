#!/usr/bin/env bash

# might need this to parse pyLoad config file

parse_yaml()
	{

	# source: https://stackoverflow.com/a/21189044

	local prefix=$2
	local s='[[:space:]]*' w='[a-zA-Z0-9_]*' fs=$(echo @|tr @ '\034')

	/bin/sed -ne "s|^\($s\):|\1|" \
		-e "s|^\($s\)\($w\)$s:$s[\"']\(.*\)[\"']$s\$|\1$fs\2$fs\3|p" \
		-e "s|^\($s\)\($w\)$s:$s\(.*\)$s\$|\1$fs\2$fs\3|p"  $1 |
	/bin/awk -F$fs '{
		indent = length($1)/2;
		vname[indent] = $2;
		for (i in vname) {if (i > indent) {delete vname[i]}}
			if (length($3) > 0) {
			vn=""; for (i=0; i<indent; i++) {vn=(vn)(vname[i])("_")}
			printf("%s%s%s=\"%s\"\n", "'$prefix'",vn, $2, $3);
			}
		}'
	}

parse_yaml test.yml
