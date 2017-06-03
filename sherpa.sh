#!/bin/bash
############################################################################
# sherpa.sh
#
# (C)opyright 2017 OneCD
#
# So, blame OneCD if it all goes horribly wrong. ;)
#
# for more info:
#	https://forum.qnap.com/viewtopic.php?f=320&t=132373
#
# This program is free software: you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free Software
# Foundation, either version 3 of the License, or (at your option) any later
# version.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
# details.
#
# You should have received a copy of the GNU General Public License along with
# this program. If not, see http://www.gnu.org/licenses/.
############################################################################

LAUNCHED_AS="$0"
debug=false; [ ! -z "$1" ] && [ "$1" == "--debug" ] && debug=true

Init()
	{

	local returncode=0
	local SCRIPT_FILE="sherpa.sh"
	local SCRIPT_VERSION="2017.06.04b"

	# cherry-pick required binaries
	CAT_CMD="/bin/cat"
	CHMOD_CMD="/bin/chmod"
	DATE_CMD="/bin/date"
	GREP_CMD="/bin/grep"
	HOSTNAME_CMD="/bin/hostname"
	LN_CMD="/bin/ln"
	MD5SUM_CMD="/bin/md5sum"
	MKDIR_CMD="/bin/mkdir"
	MV_CMD="/bin/mv"
	CP_CMD="/bin/cp"
	RM_CMD="/bin/rm"
	SED_CMD="/bin/sed"
	TOUCH_CMD="/bin/touch"
	TR_CMD="/bin/tr"
	UNAME_CMD="/bin/uname"
	AWK_CMD="/bin/awk"

	GETCFG_CMD="/sbin/getcfg"
	RMCFG_CMD="/sbin/rmcfg"
	SETCFG_CMD="/sbin/setcfg"

	BASENAME_CMD="/usr/bin/basename"
	CUT_CMD="/usr/bin/cut"
	DIRNAME_CMD="/usr/bin/dirname"
	HEAD_CMD="/usr/bin/head"
	READLINK_CMD="/usr/bin/readlink"
	TAIL_CMD="/usr/bin/tail"
	UNZIP_CMD="/usr/bin/unzip"
	UPTIME_CMD="/usr/bin/uptime"
	WC_CMD="/usr/bin/wc"
	WGET_CMD="/usr/bin/wget"

	OPKG_CMD="/opt/bin/opkg"
	FIND_CMD="/opt/bin/find"

	# paths and files
	QPKG_CONFIG_PATHFILE="/etc/config/qpkg.conf"
	DEFAULT_SHARES_PATHFILE="/etc/config/def_share.info"
	ULINUX_PATHFILE="/etc/config/uLinux.conf"
	ISSUE_PATHFILE="/etc/issue"
	INSTALL_LOG_FILE="install.log"
	DOWNLOAD_LOG_FILE="download.log"
	START_LOG_FILE="start.log"
	STOP_LOG_FILE="stop.log"
	DEBUG_LOG_FILE="${SCRIPT_FILE%.*}.debug.log"

	local DEFAULT_SHARE_DOWNLOAD_PATH="/share/Download"
	local DEFAULT_SHARE_PUBLIC_PATH="/share/Public"
	local DEFAULT_VOLUME="$($GETCFG_CMD SHARE_DEF defVolMP -f "$DEFAULT_SHARES_PATHFILE")"

	if [ -L "$DEFAULT_SHARE_DOWNLOAD_PATH" ]; then
		SHARE_DOWNLOAD_PATH="$DEFAULT_SHARE_DOWNLOAD_PATH"
	else
		SHARE_DOWNLOAD_PATH="/share/$($GETCFG_CMD SHARE_DEF defDownload -d Qdownload -f "$DEFAULT_SHARES_PATHFILE")"
	fi

	if [ -L "$DEFAULT_SHARE_PUBLIC_PATH" ]; then
		SHARE_PUBLIC_PATH="$DEFAULT_SHARE_PUBLIC_PATH"
	else
		SHARE_PUBLIC_PATH="/share/$($GETCFG_CMD SHARE_DEF defPublic -d Qpublic -f "$DEFAULT_SHARES_PATHFILE")"
	fi

	WORKING_PATH="${SHARE_PUBLIC_PATH}/${SCRIPT_FILE%.*}.tmp"
	BACKUP_PATH="${WORKING_PATH}/backup"
	SETTINGS_BACKUP_PATH="${BACKUP_PATH}/config"
	SETTINGS_BACKUP_PATHFILE="${SETTINGS_BACKUP_PATH}/config.ini"
	QPKG_PATH="${WORKING_PATH}/qpkg-downloads"
	IPK_PATH="${WORKING_PATH}/ipk-downloads"
	DEBUG_LOG_PATHFILE="${SHARE_PUBLIC_PATH}/${DEBUG_LOG_FILE}"
	QPKG_BASE_PATH="${DEFAULT_VOLUME}/.qpkg"

	# check required binaries are present
	SysFilePresent "$CAT_CMD" || return
	SysFilePresent "$CHMOD_CMD" || return
	SysFilePresent "$DATE_CMD" || return
	SysFilePresent "$GREP_CMD" || return
	SysFilePresent "$HOSTNAME_CMD" || return
	SysFilePresent "$LN_CMD" || return
	SysFilePresent "$MD5SUM_CMD" || return
	SysFilePresent "$MKDIR_CMD" || return
	SysFilePresent "$MV_CMD" || return
	SysFilePresent "$CP_CMD" || return
	SysFilePresent "$RM_CMD" || return
	SysFilePresent "$SED_CMD" || return
	SysFilePresent "$TOUCH_CMD" || return
	SysFilePresent "$TR_CMD" || return
	SysFilePresent "$UNAME_CMD" || return
	SysFilePresent "$AWK_CMD" || return

	SysFilePresent "$GETCFG_CMD" || return
	SysFilePresent "$RMCFG_CMD" || return
	SysFilePresent "$SETCFG_CMD" || return

	SysFilePresent "$BASENAME_CMD" || return
	SysFilePresent "$CUT_CMD" || return
	SysFilePresent "$DIRNAME_CMD" || return
	SysFilePresent "$HEAD_CMD" || return
	SysFilePresent "$READLINK_CMD" || return
	SysFilePresent "$TAIL_CMD" || return
	SysFilePresent "$UNZIP_CMD" || return
	SysFilePresent "$UPTIME_CMD" || return
	SysFilePresent "$WC_CMD" || return
	SysFilePresent "$WGET_CMD" || return

	# check required system paths are present
	SysSharePresent "$SHARE_DOWNLOAD_PATH" || return
	SysSharePresent "$SHARE_PUBLIC_PATH" || return

	# internals
	secure_web_login=false
	sab_port=0
	SCRIPT_STARTSECONDS=$($DATE_CMD +%s)
	errorcode=0
	queuepaused=false
	FIRMWARE_VERSION="$($GETCFG_CMD System Version -f "$ULINUX_PATHFILE")"
	NAS_ARCH="$($UNAME_CMD -m)"
	TARGET_APP="$($BASENAME_CMD $LAUNCHED_AS)"
	progress_message=""
	previous_length=0
	previous_msg=""

	[ "$TARGET_APP" == "$SCRIPT_FILE" ] && DisplayHelp && errorcode=1

	if [ "$errorcode" -eq "0" ]; then
		DebugFuncEntry
		DebugThickSeparator
		DebugScript "started" "$($DATE_CMD | $TR_CMD -s ' ')"

		[ "$debug" == "false" ] && echo -e "$(ColourTextBrightWhite "$SCRIPT_FILE") ($SCRIPT_VERSION)\n"

		DebugScript "file" "$SCRIPT_FILE"
		DebugScript "version" "$SCRIPT_VERSION"
		DebugScript "launched as" "$LAUNCHED_AS"
		DebugScript "target app" "$TARGET_APP"
		DebugThinSeparator
		DebugInfo "Markers: (**) detected, (II) information, (WW) warning, (EE) error,"
		DebugInfo "         (--) done, (>>) function entry, (<<) function exit,"
		DebugInfo "         (vv) variable name & value, (\$1) positional argument value."
		DebugThinSeparator
		DebugNAS "model" "$($GREP_CMD -v "^$" "$ISSUE_PATHFILE" | $SED_CMD 's|^Welcome to ||;s|(.*||')"
		DebugNAS "firmware version" "$FIRMWARE_VERSION"
		DebugNAS "firmware build" "$($GETCFG_CMD System "Build Number" -f "$ULINUX_PATHFILE")"
		DebugNAS "kernel" "$($UNAME_CMD -mr)"
		DebugNAS "OS uptime" "$($UPTIME_CMD | $SED_CMD 's|.*up.||;s|,.*load.*||;s|^\ *||')"
		DebugNAS "system load" "$($UPTIME_CMD | $SED_CMD 's|.*load average: ||' | $AWK_CMD -F', ' '{print "1 min="$1 ", 5 min="$2 ", 15 min="$3}')"
		DebugNAS "default volume" "$DEFAULT_VOLUME"
		DebugNAS "\$PATH" "${PATH:0:42}"
		DebugNAS "/opt" "$([ -L "/opt" ] && $READLINK_CMD "/opt" || echo "not present")"
		DebugNAS "$SHARE_DOWNLOAD_PATH" "$([ -L "$SHARE_DOWNLOAD_PATH" ] && $READLINK_CMD "$SHARE_DOWNLOAD_PATH" || echo "not present!")"
		DebugThinSeparator
	fi

	if [ "$errorcode" -eq "0" ]; then
		$MKDIR_CMD -p "$WORKING_PATH" 2> /dev/null
		result=$?

		if [ "$result" -ne "0" ]; then
			ShowError "Unable to create working directory ($WORKING_PATH) [$result]"
			errorcode=2
			returncode=1
		else
			cd "$WORKING_PATH"
		fi
	fi

	if [ "$errorcode" -eq "0" ]; then
		$MKDIR_CMD -p "$QPKG_PATH" 2> /dev/null
		result=$?

		if [ "$result" -ne "0" ]; then
			ShowError "Unable to create QPKG download directory ($QPKG_PATH) [$result]"
			errorcode=3
			returncode=1
		fi
	fi

	if [ "$errorcode" -eq "0" ]; then
		$MKDIR_CMD -p "$IPK_PATH" 2> /dev/null
		result=$?

		if [ "$result" -ne "0" ]; then
			ShowError "Unable to create IPK download directory ($IPK_PATH) [$result]"
			errorcode=4
			returncode=1
		fi
	fi

	if [ "$errorcode" -eq "0" ]; then
		if [ "$TARGET_APP" == "SABnzbdplus" ] && QPKGIsInstalled "QSabNZBdPlus" && QPKGIsInstalled "SABnzbdplus"; then
			ShowError "Both (SABnzbdplus) and (QSabNZBdPlus) are installed. This is an unsupported configuration. Please manually uninstall the unused one via the QNAP App Center then re-run this installer."
			errorcode=5
			returncode=1
		fi
	fi

	if [ "$errorcode" -eq "0" ]; then
		if QPKGIsInstalled "Entware-ng" && QPKGIsInstalled "Entware-3x"; then
			ShowError "Both (Entware-ng) and (Entware-3x) are installed. This is an unsupported configuration. Please manually uninstall both of them via the QNAP App Center then re-run this installer."
			errorcode=6
			returncode=1
		fi
	fi

	if [ "$errorcode" -eq "0" ]; then
		CalcStephaneQPKGArch
		CalcEntwareQPKG
	fi

	DebugFuncExit
	return $returncode

	}

DisplayHelp()
	{

	echo -e "\nUse one of the following symlinks to call this script:\n"
	echo "./SABnzbdplus"
	#echo "./NZBGet"
	echo "./SickRage"
	echo "./CouchPotato2"
	echo

	}

PauseDownloaders()
	{

	DebugFuncEntry

	# pause local SAB queue so installer downloads will finish faster
	if QPKGIsInstalled "SABnzbdplus"; then
 		LoadQPKGVars "SABnzbdplus"
 		SabQueueControl pause
	elif QPKGIsInstalled "QSabNZBdPlus"; then
 		LoadQPKGVars "QSabNZBdPlus"
 		SabQueueControl pause
	fi

	DebugFuncExit
	return 0

	}

DownloadQPKGs()
	{

	DebugFuncEntry
	local returncode=0
	local SL=""

	# Entware is always required
 	if ! QPKGIsInstalled "$PREF_ENTWARE"; then
		LoadQPKGDownloadDetails "$PREF_ENTWARE" && DownloadQPKG

	elif [ "$PREF_ENTWARE" == "Entware-3x" ]; then
		local testfile="/opt/etc/passwd"
		[ -e "$testfile" ] && { [ -L "$testfile" ] && ENTWARE_VER="std" || ENTWARE_VER="alt" ;} || ENTWARE_VER="none"

		if [ "$ENTWARE_VER" == "alt" ]; then
			ShowError "Entware-3x (alt) is installed. This configuration has not been tested."
			errorcode=7
			returncode=1

		elif [ "$ENTWARE_VER" == "none" ]; then
			ShowError "Entware appears to be installed but is not visible."
			errorcode=8
			returncode=1
		fi
	fi

	# now choose package(s) to download
	if [ "$errorcode" -eq "0" ]; then
		if [ "$TARGET_APP" == "SABnzbdplus" ]; then
			[ "$STEPHANE_QPKG_ARCH" != "none" ] && ! QPKGIsInstalled "Par2cmdline-MT" && LoadQPKGDownloadDetails "Par2cmdline-MT" && DownloadQPKG
			[ "$errorcode" -eq "0" ] && LoadQPKGDownloadDetails "SABnzbdplus" && DownloadQPKG

		elif [ "$TARGET_APP" == "SickRage" ]; then
			if QPKGIsInstalled "SickRage"; then
				ShowError "Sorry! This installer lacks the ability to re-install SickRage at present. It can only perform a new install."
				errorcode=9
				returncode=1
			else
				LoadQPKGDownloadDetails "SickRage" && DownloadQPKG
			fi

		elif [ "$TARGET_APP" == "CouchPotato2" ]; then
			if QPKGIsInstalled "CouchPotato2"; then
				ShowError "Sorry! This installer lacks the ability to re-install CouchPotato2 at present. It can only perform a new install."
				errorcode=10
				returncode=1
			else
				LoadQPKGDownloadDetails "CouchPotato2" && DownloadQPKG
			fi
		fi
	fi

	DebugFuncExit
	return $returncode

	}

RemovePackageInstallers()
	{

	DebugFuncEntry

	[ "$PREF_ENTWARE" == "Entware-3x" ] && UninstallQPKG "Entware-ng"
	[ "$errorcode" -eq "0" ] && { UninstallQPKG "Optware" || errorcode=0 ;} 	# ignore Optware uninstall errors

	DebugFuncExit
	return 0

	}

RemoveSabs()
	{

	DebugFuncEntry

	[ "$errorcode" -eq "0" ] && UninstallQPKG "SABnzbdplus"
	[ "$errorcode" -eq "0" ] && UninstallQPKG "QSabNZBdPlus"

	DebugFuncExit
	return 0

	}

InstallEntware()
	{

	DebugFuncEntry
	local returncode=0

	if ! QPKGIsInstalled "$PREF_ENTWARE"; then
		# rename original [/opt]
		opt_path="/opt"
		opt_backup_path="/opt.orig"
		[ -d "$opt_path" ] && [ ! -L "$opt_path" ] && [ ! -e "$opt_backup_path" ] && $MV_CMD "$opt_path" "$opt_backup_path"

		LoadQPKGDownloadDetails "$PREF_ENTWARE" && InstallQPKG && ReloadProfile

		# copy all files from original [/opt] into new [/opt]
		[ -L "$opt_path" ] && [ -d "$opt_backup_path" ] && $CP_CMD --recursive "$opt_backup_path"/* --target-directory "$opt_path" && $RM_CMD -r "$opt_backup_path"

	else
		if [ "$PREF_ENTWARE" == "Entware-3x" ]; then
			local testfile="/opt/etc/passwd"
			[ -e "$testfile" ] && { [ -L "$testfile" ] && ENTWARE_VER="std" || ENTWARE_VER="alt" ;} || ENTWARE_VER="none"

			DebugQPKG "version" "$ENTWARE_VER"
			ReloadProfile

			if [ "$ENTWARE_VER" == "alt" ]; then
				ShowError "Entware-3x (alt) is installed. This config has not been tested. Can't continue."
				errorcode=11
				returncode=1
			fi
		fi

		[ "$STEPHANE_QPKG_ARCH" != "none" ] && ($OPKG_CMD list-installed | $GREP_CMD -q "par2cmdline") && $OPKG_CMD remove "par2cmdline" >> /dev/null
	fi

	LoadQPKGVars "$PREF_ENTWARE" && PatchEntwareInit

	DebugFuncExit
	return $returncode

	}

PatchEntwareInit()
	{

	local returncode=0
	local findtext=""
	local inserttext=""

	if [ ! -e "$ent_init_pathfile" ]; then
		ShowError "No init file found [$ent_init_pathfile]"
		errorcode=12
		returncode=1
	else
 		if ($GREP_CMD -q "opt.orig" "$ent_init_pathfile"); then
			DebugInfo "patch: do the \"opt shuffle\" - already done"
		else
			findtext='/bin/rm -rf /opt'
			inserttext='opt_path="/opt"; opt_backup_path="/opt.orig"; [ -d "$opt_path" ] \&\& [ ! -L "$opt_path" ] \&\& [ ! -e "$opt_backup_path" ] \&\& mv "$opt_path" "$opt_backup_path"'
			$SED_CMD -i "s|$findtext|$inserttext\n$findtext|" "$ent_init_pathfile"

			findtext='/bin/ln -sf $QPKG_DIR /opt'
			inserttext=$(echo -e "\t")'[ -L "$opt_path" ] \&\& [ -d "$opt_backup_path" ] \&\& cp "$opt_backup_path"/* --target-directory "$opt_path" \&\& rm -r "$opt_backup_path"'
			$SED_CMD -i "s|$findtext|$findtext\n$inserttext\n|" "$ent_init_pathfile"

			DebugDone "patch: do the \"opt shuffle\""
		fi
	fi

	return $returncode

	}

UpdateEntware()
	{

	DebugFuncEntry
	local returncode=0
	local package_list_file="/opt/var/opkg-lists/packages"
	local package_list_age="60"
	local result=""

	if [ ! -f "$OPKG_CMD" ]; then
		ShowError "Entware opkg binary is missing. [$OPKG_CMD]"
		errorcode=13
		returncode=1
	else
		# if Entware package list was updated less that 1 hour ago, don't run another update

		[ -e "$FIND_CMD" ] && result=$($FIND_CMD "$package_list_file" -mmin +$package_list_age)

		if [ "$result" != "" ] ; then
			ShowProc "updating 'Entware'"

			$OPKG_CMD update > /dev/null
			result=$?

			if [ "$result" -eq "0" ]; then
				ShowDone "updated 'Entware'"
			else
				ShowWarning "'Entware' update failed [$result]"
				# meh, continue anyway...
			fi
		else
			DebugInfo "'Entware' package list was updated less than $package_list_age minutes ago"
		fi
	fi

	DebugFuncExit
	return $returncode

	}

InstallOther()
	{

	DebugFuncEntry

	# cruft - remove previous x41 Par2cmdline-MT package due to wrong arch - this was corrected on 2017-06-03
	[ "$STEPHANE_QPKG_ARCH" == "x41" ] && QPKGIsInstalled "Par2cmdline-MT" && UninstallQPKG "Par2cmdline-MT"

	[ "$TARGET_APP" == "SABnzbdplus" ] && [ "$STEPHANE_QPKG_ARCH" != "none" ] && ! QPKGIsInstalled "Par2cmdline-MT" && LoadQPKGDownloadDetails "Par2cmdline-MT" && InstallQPKG
	[ "$errorcode" -eq "0" ] && InstallIPKs
	[ "$errorcode" -eq "0" ] && InstallPIPs
	[ "$errorcode" -eq "0" ] && CreateWaiter

	DebugFuncExit
	return 0

	}

InstallIPKs()
	{

	DebugFuncEntry
	local returncode=0
	local msgs=""
	local result=""
	local packages=""
	local package_desc=""
	local log_pathfile="${IPK_PATH}/ipks.$INSTALL_LOG_FILE"

	if [ ! -z "$IPK_PATH" ] && [ -d "$IPK_PATH" ]; then
		packages="gcc python python-pip python-cffi python-pyopenssl ca-certificates nano git git-http unrar p7zip ionice ffprobe"
		[ "$STEPHANE_QPKG_ARCH" == "none" ] && packages+=" par2cmdline"
		package_desc="various"

		UpdateEntware
		ShowProc "downloading & installing IPKs ($package_desc)"

		# errors can occur due to incompatible IPKs (tried installing Entware-3x, then Entware-ng), so delete them first
		rm -f "$IPK_PATH"/*.ipk

		cd "$IPK_PATH"
		msgs=$($OPKG_CMD install --force-overwrite $packages --cache . 2>&1)
		result=$?
		echo -e "${msgs}\nresult=[$result]" > "$log_pathfile"

		if [ "$result" -eq "0" ]; then
			ShowDone "downloaded & installed IPKs ($package_desc)"

			packages="python-dev"
			package_desc="python-dev"

			ShowProc "downloading & installing IPK ($package_desc)"
			msgs=$($OPKG_CMD install --force-overwrite $packages --cache . 2>&1)
			result=$?

			echo -e "${msgs}\nresult=[$result]" >> "$log_pathfile"

			if [ "$result" -eq "0" ]; then
				ShowDone "downloaded & installed IPK ($package_desc)"
			else
				ShowError "Download & install IPK failed ($package_desc) [$result]"
				if [ "$debug" == "true" ]; then
					DebugThickSeparator
					$CAT_CMD "$log_pathfile"
					DebugThickSeparator
				fi
				errorcode=14
				returncode=1
			fi
		else
			ShowError "Download & install IPKs failed ($package_desc) [$result]"
			if [ "$debug" == "true" ]; then
				DebugThickSeparator
				$CAT_CMD "$log_pathfile"
				DebugThickSeparator
			fi
			errorcode=15
			returncode=1
		fi

		cd "$WORKING_PATH"
	else
		ShowError "IPK path does not exist [$IPK_PATH]"
		errorcode=16
		returncode=1
	fi

	DebugFuncExit
	return $returncode

	}

InstallPIPs()
	{

	DebugFuncEntry
	local msgs=""
	local returncode=0

	local op="pip setuptools"
	local log_pathfile="${WORKING_PATH}/$(echo "$op" | $TR_CMD " " "_").$INSTALL_LOG_FILE"

	ShowProc "downloading & installing ($op)"

	msgs=$(pip install --upgrade pip setuptools 2>&1)
	result=$?
	echo -e "${msgs}\nresult=[$result]" > "$log_pathfile"

	if [ "$result" -eq "0" ]; then
		ShowDone "installed ($op)"
	else
		ShowError "Download & install failed ($op) [$result]"
# 		if [ "$debug" == "true" ]; then
			DebugThickSeparator
			$CAT_CMD "$log_pathfile"
			DebugThickSeparator
# 		fi
		errorcode=17
		returncode=1
	fi

	if [ "$returncode" == "0" ]; then
		local op="pip sabyenc"
		local log_pathfile="${WORKING_PATH}/$(echo "$op" | $TR_CMD " " "_").$INSTALL_LOG_FILE"

		ShowProc "downloading & installing ($op)"

		msgs=$(pip install sabyenc --upgrade cheetah 2>&1)
		result=$?
		echo -e "${msgs}\nresult=[$result]" > "$log_pathfile"

		if [ "$result" -eq "0" ]; then
			ShowDone "installed ($op)"
		else
			ShowError "Download & install failed ($op) [$result]"
# 			if [ "$debug" == "true" ]; then
				DebugThickSeparator
				$CAT_CMD "$log_pathfile"
				DebugThickSeparator
# 			fi
			errorcode=18
			returncode=1
		fi
	fi

	DebugFuncExit
	return $returncode

	}

InstallSab()
	{

	DebugFuncEntry

	! QPKGIsInstalled "SABnzbdplus" && LoadQPKGDownloadDetails "SABnzbdplus" && InstallQPKG && LoadQPKGVars "SABnzbdplus"


	DebugFuncExit
	return 0

	}

InstallSR()
	{

	DebugFuncEntry

	! QPKGIsInstalled "SickRage" && LoadQPKGDownloadDetails "SickRage" && InstallQPKG && LoadQPKGVars "SickRage"

	DebugFuncExit
	return 0

	}

InstallCP()
	{

	DebugFuncEntry

	! QPKGIsInstalled "CouchPotato2" && LoadQPKGDownloadDetails "CouchPotato2" && InstallQPKG && LoadQPKGVars "CouchPotato2"

	DebugFuncExit
	return 0

	}

InstallNG()
	{

	DebugFuncEntry

	! IPKIsInstalled "nzbget" && {
		local returncode=0
		local msgs=""
		local result=""
		local packages=""
		local package_desc=""

		if [ ! -z "$IPK_PATH" ] && [ -d "$IPK_PATH" ]; then
			packages="nzbget"
			package_desc="nzbget"

			ShowProc "downloading & installing IPK ($package_desc)"

			cd "$IPK_PATH"
			msgs=$($OPKG_CMD install --force-overwrite $packages --cache . 2>&1)
			result=$?
			echo -e "${msgs}\nresult=[$result]" >> "${IPK_PATH}/ipk.$INSTALL_LOG_FILE"

			if [ "$result" -eq "0" ]; then
				ShowDone "downloaded & installed IPK ($package_desc)"
				ShowProc "modifying NZBGet"

				sed -i 's|ConfigTemplate=.*|ConfigTemplate=/opt/share/nzbget/nzbget.conf.template|g' "/opt/share/nzbget/nzbget.conf"
				ShowDone "modified NZBGet"
				/opt/etc/init.d/S75nzbget start
				cat /opt/share/nzbget/nzbget.conf | grep ControlPassword=
				#Go to default router ip address and port 6789 192.168.1.1:6789 and now you should see NZBget interface
			else
				ShowError "Download & install IPK failed ($package_desc) [$result]"
				errorcode=19
				returncode=1
			fi

			cd "$WORKING_PATH"
		else
			ShowError "IPK path does not exist [$IPK_PATH]"
			errorcode=20
			returncode=1
		fi
	} #&& LoadIPKVars "nzbget"

	DebugFuncExit
	return 0

	}

InstallQPKG()
	{

	DebugFuncEntry
	local msgs=""
	local returncode=0
	local target_file=""

	if [ "${qpkg_pathfile##*.}" == "zip" ]; then
		$UNZIP_CMD -nq "$qpkg_pathfile" -d "$QPKG_PATH"
		qpkg_pathfile="${qpkg_pathfile%.*}"
	fi

	local log_pathfile="$qpkg_pathfile.$INSTALL_LOG_FILE"
	target_file=$($BASENAME_CMD "$qpkg_pathfile")
	ShowProc "installing QPKG ($target_file) - this can take a while"
	msgs=$(eval sh "$qpkg_pathfile" 2>&1)
	result=$?

	echo -e "${msgs}\nresult=[$result]" > "$log_pathfile"

	if [ "$result" -eq "0" ] || [ "$result" -eq "10" ]; then
		ShowDone "installed QPKG ($target_file)"
	else
		ShowError "QPKG installation failed ($target_file) [$result]"

		if [ "$debug" == "true" ]; then
			DebugThickSeparator
			$CAT_CMD "$log_pathfile"
			DebugThickSeparator
		fi

		errorcode=21
		returncode=1
	fi

	DebugFuncExit
	return $returncode

	}

BackupSabConfig()
	{

	DebugFuncEntry
	local returncode=0

	if QPKGIsInstalled "QSabNZBdPlus"; then
		LoadQPKGVars "QSabNZBdPlus"
		StopSab

	elif QPKGIsInstalled "SABnzbdplus"; then
		LoadQPKGVars "SABnzbdplus"
 		StopSab
	fi

	SAB_WAS_INSTALLED=$sab_is_installed

	if [ "$sab_is_installed" == "true" ]; then
		if [ -d "$sab_config_path" ]; then
			if [ ! -d "${BACKUP_PATH}/config" ]; then
				$MKDIR_CMD -p "$BACKUP_PATH" 2> /dev/null
				result=$?

				if [ "$result" -eq "0" ]; then
					DebugDone "backup directory created ($BACKUP_PATH)"
				else
					ShowError "Unable to create backup directory ($BACKUP_PATH) [$result]"
					errorcode=22
					returncode=1
				fi
			fi

			if [ "$errorcode" -eq "0" ]; then
				if [ ! -d "${BACKUP_PATH}/config" ]; then
					$MV_CMD "$sab_config_path" "$BACKUP_PATH"
					result=$?

					if [ "$result" -eq "0" ]; then
						ShowDone "created SABnzbd settings backup"
					else
						ShowError "Could not create settings backup of ($sab_config_path) [$result]"
						errorcode=23
						returncode=1
					fi
 				else
 					DebugInfo "a backup set already exists [$BACKUP_PATH]"
 				fi
			fi

			ConvertSabSettings
		fi
	fi

	DebugFuncExit
	return $returncode

	}

ConvertSabSettings()
	{

	DebugFuncEntry

	local OLD_BACKUP_PATH="${BACKUP_PATH}/SAB_CONFIG"
	[ -d "$OLD_BACKUP_PATH" ] && { $MV_CMD "$OLD_BACKUP_PATH" "$SETTINGS_BACKUP_PATH"; DebugDone "renamed backup config path" ;}

	OLD_BACKUP_PATH="${BACKUP_PATH}/Config"
	[ -d "$OLD_BACKUP_PATH" ] && { $MV_CMD "$OLD_BACKUP_PATH" "$SETTINGS_BACKUP_PATH"; DebugDone "renamed backup config path" ;}

	# for converting from Stephane's QPKG and from previous version SAB QPKGs
	local SETTINGS_PREV_BACKUP_PATHFILE="${SETTINGS_BACKUP_PATH}/sabnzbd.ini"

	[ -f "$SETTINGS_PREV_BACKUP_PATHFILE" ] && { $MV_CMD "$SETTINGS_PREV_BACKUP_PATHFILE" "$SETTINGS_BACKUP_PATHFILE"; DebugDone "renamed backup config file" ;}

	if [ -f "$SETTINGS_BACKUP_PATHFILE" ]; then
 		$SED_CMD -i "s|log_dir = logs|log_dir = ${SHARE_DOWNLOAD_PATH}/sabnzbd/logs|" "$SETTINGS_BACKUP_PATHFILE"
		$SED_CMD -i "s|download_dir = Downloads/incomplete|download_dir = ${SHARE_DOWNLOAD_PATH}/incomplete|" "$SETTINGS_BACKUP_PATHFILE"
		$SED_CMD -i "s|complete_dir = Downloads/complete|complete_dir = ${SHARE_DOWNLOAD_PATH}/complete|" "$SETTINGS_BACKUP_PATHFILE"

		if ($GREP_CMD -q '^enable_https = 1' "$SETTINGS_BACKUP_PATHFILE"); then
			sab_port=$($GREP_CMD '^https_port = ' "$SETTINGS_BACKUP_PATHFILE" | $HEAD_CMD -n1 | $CUT_CMD -f3 -d' ')
			secure_web_login=true
		else
			sab_port=$($GREP_CMD '^port = ' "$SETTINGS_BACKUP_PATHFILE" | $HEAD_CMD -n1 | $CUT_CMD -f3 -d' ')
		fi
	fi

	DebugFuncExit
	return 0

	}

ReloadProfile()
	{

 	QPKGIsInstalled "$PREF_ENTWARE" && export PATH="/opt/bin:/opt/sbin:$PATH"

	DebugDone "adjusted \$PATH"
	DebugVar "PATH"

	return 0

	}

CreateWaiter()
	{

	DebugFuncEntry
	local returncode=0
	local WAITER_PATHFILE="${QPKG_BASE_PATH}/wait-for-Entware.sh"
	WAIT_FOR_PATH="/opt/${PREF_ENTWARE}.sh"

	$CAT_CMD > "$WAITER_PATHFILE" << EOF
#!/bin/sh

[ ! -z "\$1" ] && timeout="\$1" || timeout=600
[ ! -z "\$2" ] && testfile="\$2" || testfile="$WAIT_FOR_PATH"
scriptname="\$(/usr/bin/basename \$0)"
waitlog="/var/log/wait-counter-\${scriptname}.log"

if [ ! -e "\$testfile" ]; then
	(
		for ((count=1; count<=timeout; count++)); do
			sleep 1
			[ -e "\$testfile" ] &&
				{
				echo "waited for \$count seconds" >> "\$waitlog"
				true
				exit
				}

		done
		false
	)

	if [ "\$?" -ne "0" ]; then
		echo "timeout exceeded!" >> "\$waitlog"
		/sbin/write_log "[\$scriptname] Could not continue: timeout exceeded." 1
		false
		exit
	fi

	# if here, then testfile has appeared, so reload environment
	. /etc/profile
	. /root/.profile
fi
EOF

	result=$?

	if [ "$result" -eq "0" ]; then
		DebugDone "waiter created"

		if [ -f "$WAITER_PATHFILE" ]; then
			$CHMOD_CMD +x "$WAITER_PATHFILE"
			result=$?

			if [ "$result" -eq "0" ]; then
				DebugDone "set waiter executable"
			else
				ShowError "Unable to set waiter as executable ($WAITER_PATHFILE) [$result]"
				errorcode=24
				returncode=1
			fi
		else
			ShowError "waiter not found ($WAITER_PATHFILE) [$result]"
			errorcode=25
			returncode=1
		fi
	else
		ShowError "Unable to create waiter ($WAITER_PATHFILE) [$result]"
		errorcode=26
		returncode=1
	fi

	DebugFuncExit
	return $returncode

	}

RestoreSabConfig()
	{

	DebugFuncEntry
	local returncode=0

	if [ "$sab_is_installed" == "true" ]; then
		if [ -d "$SETTINGS_BACKUP_PATH" ]; then
			StopSab

			if [ ! -d "$sab_config_path" ]; then
				$MKDIR_CMD -p "$($DIRNAME_CMD "$sab_config_path")" 2> /dev/null
			else
				$RM_CMD -r "$sab_config_path" 2> /dev/null
			fi

			$MV_CMD "$SETTINGS_BACKUP_PATH" "$($DIRNAME_CMD "$sab_config_path")"
			result=$?

			if [ "$result" -eq "0" ]; then
				ShowDone "restored SABnzbd settings backup"

				$SETCFG_CMD "SABnzbdplus" Web_Port $sab_port -f "$QPKG_CONFIG_PATHFILE"
			else
				ShowError "Could not restore settings backup to ($sab_config_path) [$result]"
				errorcode=27
				returncode=1
			fi
		fi

	else
		ShowError "SABnzbd is NOT installed so can't restore backups"
		errorcode=28
		returncode=1
	fi

	DebugFuncExit
	return $returncode

	}

DownloadQPKG()
	{

	DebugFuncEntry
	local returncode=0

	[ "$errorcode" -gt "0" ] && { DebugFuncExit; return 1;}

	if [ -e "$qpkg_pathfile" ]; then
		file_md5=$($MD5SUM_CMD "$qpkg_pathfile" | $CUT_CMD -f1 -d' ')
		result=$?

		if [ "$result" -eq "0" ]; then
			if [ "$file_md5" == "$qpkg_md5" ]; then
				DebugInfo "existing QPKG checksum correct ($qpkg_file)"
			else
				DebugWarning "existing QPKG checksum incorrect ($qpkg_file) [$result]"
				DebugInfo "deleting ($qpkg_pathfile) [$result]"
				$RM_CMD -f "$qpkg_pathfile"
			fi
		else
			ShowError "Problem creating checksum from existing QPKG ($qpkg_file) [$result]"
			errorcode=29
			returncode=1
		fi
	fi

	if [ "$errorcode" -eq "0" ] && [ ! -e "$qpkg_pathfile" ]; then
		ShowProc "downloading QPKG ($qpkg_file)"
		local log_pathfile="$qpkg_pathfile.$DOWNLOAD_LOG_FILE"

		[ -e "$log_pathfile" ] && rm -f "$log_pathfile"

		if [ "$debug" == "true" ]; then
			$WGET_CMD --no-check-certificate -q --show-progress "$qpkg_url" --output-document "$qpkg_pathfile"
		else
			$WGET_CMD --no-check-certificate --output-file "$log_pathfile" "$qpkg_url" --output-document "$qpkg_pathfile"
		fi

		result=$?

		echo -e "\nresult=[$result]" >> "$log_pathfile"

		if [ "$result" -eq "0" ]; then
			file_md5=$($MD5SUM_CMD "$qpkg_pathfile" | $CUT_CMD -f1 -d' ')
			result=$?

			if [ "$result" -eq "0" ]; then
				if [ "$file_md5" == "$qpkg_md5" ]; then
					ShowDone "downloaded QPKG ($qpkg_file)"
				else
					ShowError "Downloaded QPKG checksum incorrect ($qpkg_file) [$result]"
					errorcode=30
					returncode=1
				fi
			else
				ShowError "Problem creating checksum from downloaded QPKG [$result]"
				errorcode=31
				returncode=1
			fi
		else
			ShowError "Download failed ($qpkg_pathfile) [$result]"

			if [ "$debug" == "true" ]; then
				DebugThickSeparator
				$CAT_CMD "$qpkg_pathfile.$DOWNLOAD_LOG_FILE"
				DebugThickSeparator
			fi

			errorcode=32
			returncode=1
		fi
	fi

	DebugFuncExit
	return $returncode

	}

CalcStephaneQPKGArch()
	{

	# reduce NAS architecture down to 3+1 possibilities

	local returncode=0
	STEPHANE_QPKG_ARCH=""

	[ "$NAS_ARCH" == "i686" ] && STEPHANE_QPKG_ARCH="x86"

	if [ "$NAS_ARCH" == "x86_64" ]; then
		echo $FIRMWARE_VERSION | $GREP_CMD -q "4.3." && STEPHANE_QPKG_ARCH="x64" || STEPHANE_QPKG_ARCH="x86"
	fi

	[ "$NAS_ARCH" == "armv7l" ] && STEPHANE_QPKG_ARCH="x41"
	[ "$NAS_ARCH" == "armv5tejl" ] && STEPHANE_QPKG_ARCH="none"
	[ "$NAS_ARCH" == "armv5tel" ] && STEPHANE_QPKG_ARCH="none"

	if [ -z "$STEPHANE_QPKG_ARCH" ]; then
		ShowError "Could not determine suitable ARCH for Stephane's QPKG ($NAS_ARCH)"
		errorcode=33
		returncode=1
	else
		DebugInfo "found a suitable ARCH for Stephane's QPKG ($STEPHANE_QPKG_ARCH)"
	fi

	return $returncode

	}

CalcEntwareQPKG()
	{

	# decide which Entware is suitable for this NAS.
	PREF_ENTWARE="Entware-3x"

	[ "$NAS_ARCH" == "i686" ] && PREF_ENTWARE="Entware-ng"
 	QPKGIsInstalled "Entware-ng" && PREF_ENTWARE="Entware-ng"

	DebugInfo "found a suitable Entware package ($PREF_ENTWARE)"

	return 0

	}

LoadQPKGVars()
	{

	# $1 = installed package name to read variables for

	local returncode=0
	local package_name="$1"

	if [ -z "$package_name" ]; then
		DebugError "QPKG name not specified"
		errorcode=34
		returncode=1
	else

		if [ "$package_name" == "SABnzbdplus" ] || [ "$package_name" == "QSabNZBdPlus" ]; then
			sab_installed_path="$($GETCFG_CMD "$package_name" Install_Path -f "$QPKG_CONFIG_PATHFILE")"
			result=$?

			if [ "$result" -eq "0" ]; then
				sab_is_installed=true
				sab_init_pathfile="$($GETCFG_CMD "$package_name" Shell -f "$QPKG_CONFIG_PATHFILE")"

				if [ "$package_name" == "SABnzbdplus" ]; then
					if [ -d "${sab_installed_path}/Config" ]; then
						sab_config_path="${sab_installed_path}/Config"
					else
						sab_config_path="${sab_installed_path}/config"
					fi

				elif [ "$package_name" == "QSabNZBdPlus" ]; then
					sab_config_path="${sab_installed_path}/SAB_CONFIG"
				fi

				if [ -f "${sab_config_path}/sabnzbd.ini" ]; then
					sab_settings_pathfile="${sab_config_path}/sabnzbd.ini"
				else
					sab_settings_pathfile="${sab_config_path}/config.ini"
				fi

				if [ -e "$SETTINGS_BACKUP_PATHFILE" ]; then
					if ($GREP_CMD -q '^enable_https = 1' "$SETTINGS_BACKUP_PATHFILE"); then
						sab_port=$($GREP_CMD '^https_port = ' "$SETTINGS_BACKUP_PATHFILE" | $HEAD_CMD -n1 | $CUT_CMD -f3 -d' ')
						secure_web_login=true
					else
						sab_port=$($GREP_CMD '^port = ' "$SETTINGS_BACKUP_PATHFILE" | $HEAD_CMD -n1 | $CUT_CMD -f3 -d' ')
					fi
				else
					sab_port="$($GETCFG_CMD "$package_name" Web_Port -f "$QPKG_CONFIG_PATHFILE")"
				fi

				[ -e "$sab_settings_pathfile" ] && sab_api=$($GREP_CMD -e "^api_key" "$sab_settings_pathfile" | $SED_CMD 's|api_key = ||')
				sab_chartranslator_pathfile="$sab_installed_path/Repository/scripts/CharTranslator.py"
			else
				sab_is_installed=false
				sab_installed_path=""
				sab_init_pathfile=""
				sab_config_path=""
				sab_settings_pathfile=""
				sab_port=""
				sab_api=""
				sab_chartranslator_pathfile=""
				returncode=1
			fi

		elif [ "$package_name" == "Entware-3x" ] || [ "$package_name" == "Entware-ng" ]; then
			ent_installed_path="$($GETCFG_CMD "$package_name" Install_Path -f "$QPKG_CONFIG_PATHFILE")"
			result=$?

			if [ "$result" -eq "0" ]; then
				ent_is_installed=true
				ent_init_pathfile="$($GETCFG_CMD "$package_name" Shell -f "$QPKG_CONFIG_PATHFILE")"
			else
				ent_is_installed=false
				ent_installed_path=""
				ent_init_pathfile=""
				returncode=1
			fi
		fi
	fi

	return $returncode

	}

LoadQPKGDownloadDetails()
	{

	# $1 = QPKG name

	local returncode=0
	local target_file=""
	local OneCD_urlprefix="https://github.com/OneCDOnly/sherpa/blob/master/QPKGs"
	local Stephane_urlprefix="http://www.qoolbox.fr/Par2cmdline-MT_0.6.14-MT"

	qpkg_url=""
	qpkg_md5=""
	qpkg_file=""
	qpkg_pathfile=""

	if [ -z "$1" ]; then
		DebugError "QPKG name not specified"
		errorcode=35
		returncode=1
	else
		qpkg_name="$1"
		local base_url=""

		if [ "$1" == "Entware-3x" ]; then
			qpkg_md5="3663c9e4323e694fb25897e276f55623"
			qpkg_url="http://entware-3x.zyxmon.org/binaries/other/Entware-3x_0.99std.qpkg"

		elif [ "$1" == "Entware-ng" ]; then
			qpkg_md5="6c81cc37cbadd85adfb2751dc06a238f"
			qpkg_url="http://entware.zyxmon.org/binaries/other/Entware-ng_0.97.qpkg"

		elif [ "$1" == "SABnzbdplus" ]; then
 			target_file="SABnzbdplus_170604.qpkg"
 			qpkg_md5="ddd3bf36bec34ca65fd12ece0b6b0cd0"
 			qpkg_url="${OneCD_urlprefix}/SABnzbdplus/build/${target_file}?raw=true"
 			qpkg_file=$target_file

		elif [ "$1" == "SickRage" ]; then
			target_file="SickRage_170528.qpkg"
			qpkg_md5="9f42396f4da687abcb69d85de702b94a"
			qpkg_url="${OneCD_urlprefix}/SickRage/build/${target_file}?raw=true"
			qpkg_file=$target_file

		elif [ "$1" == "CouchPotato2" ]; then
			target_file="CouchPotato2_170528.qpkg"
			qpkg_md5="b1c77dae1809b790d5719c50a3e45138"
			qpkg_url="${OneCD_urlprefix}/CouchPotato2/build/${target_file}?raw=true"
			qpkg_file=$target_file

		elif [ "$1" == "Par2cmdline-MT" ]; then
			if [ "$STEPHANE_QPKG_ARCH" == "x86" ]; then
				qpkg_md5="531832a39576e399f646890cc18969bb"
				qpkg_url="${Stephane_urlprefix}_x86.qpkg.zip"

			elif [ "$STEPHANE_QPKG_ARCH" == "x64" ]; then
				qpkg_md5="f3b3dd496289510ec0383cf083a50f8e"
				qpkg_url="${Stephane_urlprefix}_x86_64.qpkg.zip"

			elif [ "$STEPHANE_QPKG_ARCH" == "x41" ]; then
				qpkg_md5="1701b188115758c151f19956388b90cb"
				qpkg_url="${Stephane_urlprefix}_arm-x41.qpkg.zip"
			fi
		else
			DebugError "QPKG name not found"
			errorcode=36
			returncode=1
		fi

		[ -z "$qpkg_file" ] && [ ! -z "$qpkg_url" ] && qpkg_file=$($BASENAME_CMD "$qpkg_url")
		qpkg_pathfile="${QPKG_PATH}/${qpkg_file}"
	fi

	return $returncode

	}

UninstallQPKG()
	{

	# $1 = QPKG name

	local returncode=0

	if [ -z "$1" ]; then
		DebugError "QPKG name not specified"
		errorcode=37
		returncode=1
	else
		qpkg_installed_path="$($GETCFG_CMD "$1" Install_Path -f "$QPKG_CONFIG_PATHFILE")"
		result=$?

		if [ "$result" -eq "0" ]; then
			qpkg_installed_path="$($GETCFG_CMD "$1" Install_Path -f "$QPKG_CONFIG_PATHFILE")"

			if [ -e "${qpkg_installed_path}/.uninstall.sh" ]; then
				ShowProc "uninstalling QPKG '$1'"

				${qpkg_installed_path}/.uninstall.sh > /dev/null
				result=$?

				if [ "$result" -eq "0" ]; then
					ShowDone "uninstalled QPKG '$1'"
				else
					ShowError "Unable to uninstall QPKG \"$1\" [$result]"
					errorcode=38
					returncode=1
				fi
			fi

			$RMCFG_CMD "$1" -f "$QPKG_CONFIG_PATHFILE"
		else
			DebugQPKG "'$1'" "not installed [$result]"
		fi
	fi

	return $returncode

	}

ReinstallSab()
	{

	DebugFuncEntry

	[ "$errorcode" -eq "0" ] && BackupSabConfig
  	[ "$errorcode" -eq "0" ] && RemoveSabs
  	[ "$errorcode" -eq "0" ] && InstallSab
  	[ "$errorcode" -eq "0" ] && RestoreSabConfig
 	[ "$errorcode" -eq "0" ] && StartSab

	DebugFuncExit
	return 0

	}

ReinstallSR()
	{

	DebugFuncEntry

	#[ "$errorcode" -eq "0" ] && BackupSRConfig
	#[ "$errorcode" -eq "0" ] && RemoveSR
	[ "$errorcode" -eq "0" ] && InstallSR
	#[ "$errorcode" -eq "0" ] && RestoreSRConfig

	DebugFuncExit
	return 0

	}

ReinstallCP()
	{

	DebugFuncEntry

	#[ "$errorcode" -eq "0" ] && BackupCPConfig
	#[ "$errorcode" -eq "0" ] && RemoveCP
	[ "$errorcode" -eq "0" ] && InstallCP
	#[ "$errorcode" -eq "0" ] && RestoreCPConfig

	DebugFuncExit
	return 0

	}

DaemonControl()
	{

	# $1 = pathfile of init script
	# $2 = action (start|stop)

	local returncode=0
	local msgs=""
	local target_init_pathfile=""
	local init_file=""

	if [ -z "$1" ]; then
		DebugError "daemon not specified"
		errorcode=39
		returncode=1

	elif [ ! -e "$1" ]; then
		DebugError "daemon init not found [$1]"
		errorcode=40
		returncode=1

	else
		target_init_pathfile="$1"
		target_init_file=$($BASENAME_CMD "$target_init_pathfile")

		case "$2" in
			start)
				ShowProc "starting daemon ($target_init_file) - this can take a while"
				msgs=$("$target_init_pathfile" start)
				result=$?
				echo -e "${msgs}\nresult=[$result]" >> "$qpkg_pathfile.$START_LOG_FILE"

				if [ "$result" -eq "0" ]; then
					ShowDone "daemon started ($target_init_file)"

				else
					ShowWarning "could not start daemon ($target_init_file) [$result]"
					if [ "$debug" == "true" ]; then
						DebugThickSeparator
						$CAT_CMD "$qpkg_pathfile.$START_LOG_FILE"
						DebugThickSeparator
					fi
					errorcode=41
					returncode=1
				fi
				;;
			stop)
				ShowProc "stopping daemon ($target_init_file)"
				msgs=$("$target_init_pathfile" stop)
				result=$?
				echo -e "${msgs}\nresult=[$result]" >> "$qpkg_pathfile.$STOP_LOG_FILE"

				if [ "$result" -eq "0" ]; then
					ShowDone "daemon stopped ($target_init_file)"

				else
					ShowWarning "could not stop daemon ($target_init_file) [$result]"
					if [ "$debug" == "true" ]; then
						DebugThickSeparator
						$CAT_CMD "$qpkg_pathfile.$STOP_LOG_FILE"
						DebugThickSeparator
					fi
					# meh, continue anyway...
					returncode=1
				fi
				;;
			*)
				DebugError "action unrecognised [$2]"
				errorcode=42
				returncode=1
				;;
		esac
	fi

	return $returncode

	}

StopSab()
	{

	DaemonControl "$sab_init_pathfile" stop
	return $?

	}

StartSab()
	{

	DaemonControl "$sab_init_pathfile" start
	return $?

	}

Cleanup()
	{

	DebugFuncEntry

	cd "$SHARE_PUBLIC_PATH"

	[ "$errorcode" -eq "0" ] && [ "$debug" != "true" ] && [ -d "$WORKING_PATH" ] && $RM_CMD -rf "$WORKING_PATH"

	if [ "$queuepaused" == "true" ]; then
		if QPKGIsInstalled "SABnzbdplus"; then
			LoadQPKGVars "SABnzbdplus"
			SabQueueControl resume
		elif QPKGIsInstalled "QSabNZBdPlus"; then
			LoadQPKGVars "QSabNZBdPlus"
			SabQueueControl resume
		fi
	fi

	DebugFuncExit
	return 0

	}

DisplayResult()
	{

	DebugFuncEntry
	local RE=""
	local SL=""

	[ "$SAB_WAS_INSTALLED" == "true" ] && RE="re" || RE=""
	[ "$secure_web_login" == "true" ] && SL="s" || SL=""
	[ "$debug" == "false" ] && echo

	if [ "$errorcode" -eq "0" ]; then
		[ "$debug" == "true" ] && emoticon=":DD" || emoticon=""
		ShowDone "$TARGET_APP has been successfully ${RE}installed! $emoticon"
		[ "$debug" == "false" ] && echo
		#ShowInfo "It should now be accessible on your LAN @ $(ColourTextUnderlinedBlue "http${SL}://$($HOSTNAME_CMD -i | $TR_CMD -d ' '):$sab_port")"
	else
		[ "$debug" == "true" ] && emoticon=":S" || emoticon=""
		ShowError "$TARGET_APP ${RE}install failed! $emoticon [$errorcode]"
	fi

	DebugScript "finished" "$($DATE_CMD)"
	DebugScript "elapsed time" "$(ConvertSecs "$(($($DATE_CMD +%s)-$SCRIPT_STARTSECONDS))")"
	DebugThickSeparator
	DebugFuncExit
	return 0

	}

SabQueueControl()
	{

	# $1 = 'pause' or 'resume'

	local returncode=0

	if [ -z "$1" ]; then
		returncode=1
	elif [ "$1" != "pause" ] && [ "$1" != "resume" ]; then
		returncode=1
	else
		[ "$secure_web_login" == "true" ] && SL="s" || SL=""
		$WGET_CMD --no-check-certificate --quiet "http${SL}://127.0.0.1:${sab_port}/sabnzbd/api?mode=${1}&apikey=${sab_api}" -O - 2>&1 >/dev/null &
		[ "$1" == "pause" ] && queuepaused=true || queuepaused=false
		DebugDone "${1}d existing SABnzbd queue"
	fi

	return $returncode

	}

QPKGIsInstalled()
	{

	# If package has been installed, check that it has also been enabled.
	# If not enabled, then enable it.
	# If not installed, return 1

	# $1 = package name to check/enable

	local returncode=0

	if [ -z "$1" ]; then
		DebugError "QPKG name not specified"
		errorcode=43
		returncode=1
	else
		$GREP_CMD -q -F "[$1]" "$QPKG_CONFIG_PATHFILE"
		result=$?

		if [ "$result" -eq "0" ]; then
			if [ "$($GETCFG_CMD "$1" RC_Number -d 0 -f "$QPKG_CONFIG_PATHFILE")" != "0" ]; then
				DebugQPKG "'$1'" "installed"
				[ "$($GETCFG_CMD "$1" Enable -u -f "$QPKG_CONFIG_PATHFILE")" != "TRUE" ] && $SETCFG_CMD "$1" Enable TRUE -f "$QPKG_CONFIG_PATHFILE"
			else
				DebugQPKG "'$1'" "not installed"
				returncode=1
			fi
		else
			DebugQPKG "'$1'" "not installed"
			returncode=1
		fi
	fi

	return $returncode

	}

IPKIsInstalled()
	{

	# If not installed, return 1

	# $1 = package name to check

	local returncode=0

	if [ -z "$1" ]; then
		DebugError "IPK name not specified"
		errorcode=44
		returncode=1
	else
		$OPKG_CMD list-installed | $GREP_CMD -q -F "$1"
		result=$?

		if [ "$result" -eq "0" ]; then
			DebugQPKG "'$1'" "installed"
		else
			DebugQPKG "'$1'" "not installed"
			returncode=1
		fi
	fi

	return $returncode

	}

SysFilePresent()
	{

	# $1 = pathfile to check

	[ -z "$1" ] && return 1

	if [ ! -e "$1" ]; then
		ShowError "A required NAS system file is missing [$1]"
		errorcode=45
		return 1
	else
		return 0
	fi

	}

SysSharePresent()
	{

	# $1 = symlink path to check

	[ -z "$1" ] && return 1

	if [ ! -L "$1" ]; then
		ShowError "A required NAS system share is missing [$1]. Please re-create it via QNAP Control Panel -> Privilege Settings -> Shared Folders."
		errorcode=46
		return 1
	else
		return 0
	fi

	}

ConvertSecs()
	{

	# http://stackoverflow.com/questions/12199631/convert-seconds-to-hours-minutes-seconds
	# $1 = a time in seconds to convert to 'hh:mm:ss'

	((h=${1}/3600))
	((m=(${1}%3600)/60))
	((s=${1}%60))

	printf "%02dh:%02dm:%02ds\n" $h $m $s

	}

DebugThickSeparator()
	{

	DebugInfo "$(printf '%0.s=' {1..68})"

	}

DebugThinSeparator()
	{

	DebugInfo "$(printf '%0.s-' {1..68})"

	}

DebugScript()
	{

	DebugDetected "SCRIPT" "$1" "$2"

	}

DebugSAB()
	{

	DebugDetected "SAB" "$1" "$2"

	}

DebugNAS()
	{

	DebugDetected "NAS" "$1" "$2"

	}

DebugQPKG()
	{

	DebugDetected "QPKG" "$1" "$2"

	}

DebugFuncEntry()
	{

	DebugThis "(>>) <${FUNCNAME[1]}>"

	}

DebugFuncExit()
	{

	DebugThis "(<<) <${FUNCNAME[1]}> [$errorcode]"

	}

DebugDone()
	{

	DebugThis "(--) $1"

	}

DebugDetected()
	{

	DebugThis "(**) $(printf "%-7s %17s %-s\n" "$1:" "$2:" "$3")"

	}

DebugInfo()
	{

	DebugThis "(II) $1"

	}

DebugWarning()
	{

	DebugThis "(WW) $1"

	}

DebugError()
	{

	DebugThis "(EE) $1!"

	}

DebugVar()
	{

	DebugThis "(vv) $1 [${!1}]"

	}

DebugThis()
	{

	[ "$debug" == "true" ] && ShowDebug "$1"
	SaveDebug "$1"

	}

ShowInfo()
	{

	ShowLogLine_write "$(ColourTextBrightWhite "info")" "$1"
	SaveLogLine "info" "$1"

	}

ShowProc()
	{

	ShowLogLine_write "$(ColourTextBrightOrange "proc")" "$1 ..."
	SaveLogLine "proc" "$1 ..."

	}

ShowDebug()
	{

	ShowLogLine_write "$(ColourTextBlackOnCyan "dbug")" "$1"

	}

ShowDone()
	{

	ShowLogLine_update "$(ColourTextBrightGreen "done")" "$1"
	SaveLogLine "done" "$1"

	}

ShowWarning()
	{

	ShowLogLine_update "$(ColourTextBrightOrange "warn")" "$1"
	SaveLogLine "warn" "$1"

	}

ShowError()
	{

	ShowLogLine_update "$(ColourTextBrightRed "fail")" "$1"
	SaveLogLine "fail" "$1"

	}

SaveDebug()
	{

	SaveLogLine "dbug" "$1"

	}

ShowLogLine_write()
	{

	# writes a new message without newline (unless in debug mode)

	# $1 = pass/fail
	# $2 = message

	previous_msg=$(printf "[ %-10s ] %s" "$1" "$2")

	echo -n "$previous_msg"; [ "$debug" == "true" ] && echo

	return 0

	}

ShowLogLine_update()
	{

	# updates the previous message

	# $1 = pass/fail
	# $2 = message

	new_message=$(printf "[ %-10s ] %s" "$1" "$2")

	if [ "$new_message" != "$previous_msg" ] ; then
		previous_length=$((${#previous_msg}+1))
		new_length=$((${#new_message}+1))

		# jump to start of line, print new msg
		strbuffer=$(echo -en "\r$new_message ")

		# if new msg is shorter then add spaces to end to cover previous msg
		[ "$new_length" -lt "$previous_length" ] && { appended_length=$(($new_length-$previous_length)); strbuffer+=$(printf "%${appended_length}s") ;}

		echo "$strbuffer"
	fi

	return 0

	}

SaveLogLine()
	{

	# $1 = pass/fail
	# $2 = message

	printf "[ %-4s ] %s\n" "$1" "$2" >> "$DEBUG_LOG_PATHFILE"

	}

ColourTextBrightGreen()
	{

	echo -en '\E[1;32m'"$(PrintResetColours "$1")"

	}

ColourTextBrightOrange()
	{

	echo -en '\E[1;38;5;214m'"$(PrintResetColours "$1")"

	}

ColourTextBrightRed()
	{

	echo -en '\E[1;31m'"$(PrintResetColours "$1")"

	}

ColourTextUnderlinedBlue()
	{

	echo -en '\E[4;94m'"$(PrintResetColours "$1")"

	}

ColourTextBlackOnCyan()
	{

	echo -en '\E[30;46m'"$(PrintResetColours "$1")"

	}

ColourTextBrightWhite()
	{

	echo -en '\E[1;97m'"$(PrintResetColours "$1")"

	}

PrintResetColours()
	{

	echo -en "$1"'\E[0m'

	}

Init
[ "$errorcode" -eq "0" ] && PauseDownloaders
[ "$errorcode" -eq "0" ] && DownloadQPKGs
[ "$errorcode" -eq "0" ] && RemovePackageInstallers
[ "$errorcode" -eq "0" ] && InstallEntware
[ "$errorcode" -eq "0" ] && InstallOther

if [ "$errorcode" -eq "0" ]; then
	[ "$TARGET_APP" == "SABnzbdplus" ] && ReinstallSab
 	[ "$TARGET_APP" == "SickRage" ] && ReinstallSR
	[ "$TARGET_APP" == "CouchPotato2" ] && ReinstallCP
	#[ "$TARGET_APP" == "NZBGet" ] && ReinstallNG
fi

Cleanup
[ "$errorcode" -ne "1" ] && DisplayResult

exit "$errorcode"
