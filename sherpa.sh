#!/usr/bin/env bash
###############################################################################
# sherpa.sh
#
# (C)opyright 2017-2018 OneCD - one.cd.only@gmail.com
#
# So, blame OneCD if it all goes horribly wrong. ;)
#
# For more info [https://forum.qnap.com/viewtopic.php?f=320&t=132373]
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
###############################################################################

USER_ARGS_RAW="$@"
errorcode=0

ParseArgs()
    {

    if [[ ! -n $USER_ARGS_RAW ]]; then
        DisplayHelp
        errorcode=1
        return 1
    else
        local user_args=( $(echo "$USER_ARGS_RAW" | tr '[A-Z]' '[a-z]') )
    fi

    for arg in "${user_args[@]}"; do
        case $arg in
            sab|sabnzbd|sabnzbdplus)
                TARGET_APP=SABnzbdplus
                ;;
            sr|sickrage)
                TARGET_APP=SickRage
                ;;
            cp|couchpotato|couchpotato2|couchpotatoserver)
                TARGET_APP=CouchPotato2
                ;;
            ll|lazylibrarian)
                TARGET_APP=LazyLibrarian
                ;;
            med|medusa|omedusa)
                TARGET_APP=OMedusa
                ;;
            -d|--debug)
                debug=true
                ;;
            *)
                break
                ;;
        esac
    done

    return 0

    }

Init()
    {

    local returncode=0
    local SCRIPT_FILE=sherpa.sh
    local SCRIPT_VERSION=180402
    debug=false

    # cherry-pick required binaries
    CAT_CMD=/bin/cat
    CHMOD_CMD=/bin/chmod
    DATE_CMD=/bin/date
    GREP_CMD=/bin/grep
    HOSTNAME_CMD=/bin/hostname
    LN_CMD=/bin/ln
    MD5SUM_CMD=/bin/md5sum
    MKDIR_CMD=/bin/mkdir
    MV_CMD=/bin/mv
    CP_CMD=/bin/cp
    RM_CMD=/bin/rm
    SED_CMD=/bin/sed
    TOUCH_CMD=/bin/touch
    TR_CMD=/bin/tr
    UNAME_CMD=/bin/uname
    AWK_CMD=/bin/awk
    MKTEMP_CMD=/bin/mktemp
    PING_CMD=/bin/ping

    GETCFG_CMD=/sbin/getcfg
    RMCFG_CMD=/sbin/rmcfg
    SETCFG_CMD=/sbin/setcfg
    CURL_CMD=/sbin/curl

    BASENAME_CMD=/usr/bin/basename
    CUT_CMD=/usr/bin/cut
    DIRNAME_CMD=/usr/bin/dirname
    HEAD_CMD=/usr/bin/head
    READLINK_CMD=/usr/bin/readlink
    TAIL_CMD=/usr/bin/tail
    UNZIP_CMD=/usr/bin/unzip
    UPTIME_CMD=/usr/bin/uptime
    WC_CMD=/usr/bin/wc
    WGET_CMD=/usr/bin/wget
    DU_CMD=/usr/bin/du

    OPKG_CMD=/opt/bin/opkg
    FIND_CMD=/opt/bin/find

    # paths and files
    QPKG_CONFIG_PATHFILE=/etc/config/qpkg.conf
    local DEFAULT_SHARES_PATHFILE=/etc/config/def_share.info
    local ULINUX_PATHFILE=/etc/config/uLinux.conf
    local ISSUE_PATHFILE=/etc/issue
    INSTALL_LOG_FILE=install.log
    DOWNLOAD_LOG_FILE=download.log
    START_LOG_FILE=start.log
    STOP_LOG_FILE=stop.log
    local DEBUG_LOG_FILE="${SCRIPT_FILE%.*}.debug.log"

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
    SysFilePresent "$MKTEMP_CMD" || return
    SysFilePresent "$PING_CMD" || return

    SysFilePresent "$GETCFG_CMD" || return
    SysFilePresent "$RMCFG_CMD" || return
    SysFilePresent "$SETCFG_CMD" || return
    SysFilePresent "$CURL_CMD" || return

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
    SysFilePresent "$DU_CMD" || return

    local DEFAULT_SHARE_DOWNLOAD_PATH=/share/Download
    local DEFAULT_SHARE_PUBLIC_PATH=/share/Public
    local DEFAULT_VOLUME="$($GETCFG_CMD SHARE_DEF defVolMP -f "$DEFAULT_SHARES_PATHFILE")"

    if [[ -L $DEFAULT_SHARE_DOWNLOAD_PATH ]]; then
        SHARE_DOWNLOAD_PATH="$DEFAULT_SHARE_DOWNLOAD_PATH"
    else
        SHARE_DOWNLOAD_PATH="/share/$($GETCFG_CMD SHARE_DEF defDownload -d Qdownload -f "$DEFAULT_SHARES_PATHFILE")"
    fi

    if [[ -L $DEFAULT_SHARE_PUBLIC_PATH ]]; then
        SHARE_PUBLIC_PATH="$DEFAULT_SHARE_PUBLIC_PATH"
    else
        SHARE_PUBLIC_PATH="/share/$($GETCFG_CMD SHARE_DEF defPublic -d Qpublic -f "$DEFAULT_SHARES_PATHFILE")"
    fi

    # check required system paths are present
    SysSharePresent "$SHARE_DOWNLOAD_PATH" || return
    SysSharePresent "$SHARE_PUBLIC_PATH" || return

    WORKING_PATH="${SHARE_PUBLIC_PATH}/${SCRIPT_FILE%.*}.tmp"
    BACKUP_PATH="${WORKING_PATH}/backup"
    SETTINGS_BACKUP_PATH="${BACKUP_PATH}/config"
    SETTINGS_BACKUP_PATHFILE="${SETTINGS_BACKUP_PATH}/config.ini"
    QPKG_DL_PATH="${WORKING_PATH}/qpkg-downloads"
    IPKG_DL_PATH="${WORKING_PATH}/ipkg-downloads"
    IPKG_CACHE_PATH="${WORKING_PATH}/ipkg-cache"
    DEBUG_LOG_PATHFILE="${SHARE_PUBLIC_PATH}/${DEBUG_LOG_FILE}"
    QPKG_BASE_PATH="${DEFAULT_VOLUME}/.qpkg"

    # internals
    secure_web_login=false
    package_port=0
    SCRIPT_STARTSECONDS=$($DATE_CMD +%s)
    queuepaused=false
    FIRMWARE_VERSION="$($GETCFG_CMD System Version -f "$ULINUX_PATHFILE")"
    NAS_ARCH="$($UNAME_CMD -m)"
    progress_message=''
    previous_length=0
    previous_msg=''
    REINSTALL_FLAG=false
    [[ ${FIRMWARE_VERSION//.} -lt 426 ]] && CURL_CMD+=' --insecure'

    ParseArgs

    if [[ $errorcode -eq 0 ]]; then
        DebugFuncEntry
        DebugThickSeparator
        DebugScript 'started' "$($DATE_CMD | $TR_CMD -s ' ')"

        [[ $debug = false ]] && echo -e "$(ColourTextBrightWhite "$SCRIPT_FILE") ($SCRIPT_VERSION)\n"

        DebugScript 'version' "$SCRIPT_VERSION"
        DebugThinSeparator
        DebugInfo 'Markers: (**) detected, (II) information, (WW) warning, (EE) error,'
        DebugInfo '         (--) done, (>>) function entry, (<<) function exit,'
        DebugInfo '         (vv) variable name & value, ($1) positional argument value.'
        DebugThinSeparator
        DebugNAS 'model' "$($GREP_CMD -v "^$" "$ISSUE_PATHFILE" | $SED_CMD 's|^Welcome to ||;s|(.*||')"
        DebugNAS 'firmware version' "$FIRMWARE_VERSION"
        DebugNAS 'firmware build' "$($GETCFG_CMD System 'Build Number' -f "$ULINUX_PATHFILE")"
        DebugNAS 'kernel' "$($UNAME_CMD -mr)"
        DebugNAS 'OS uptime' "$($UPTIME_CMD | $SED_CMD 's|.*up.||;s|,.*load.*||;s|^\ *||')"
        DebugNAS 'system load' "$($UPTIME_CMD | $SED_CMD 's|.*load average: ||' | $AWK_CMD -F', ' '{print "1 min="$1 ", 5 min="$2 ", 15 min="$3}')"
        DebugNAS 'default volume' "$DEFAULT_VOLUME"
        DebugNAS '$PATH' "${PATH:0:42}"
        DebugNAS '/opt' "$([[ -L '/opt' ]] && $READLINK_CMD '/opt' || echo "not present")"
        DebugNAS "$SHARE_DOWNLOAD_PATH" "$([[ -L $SHARE_DOWNLOAD_PATH ]] && $READLINK_CMD "$SHARE_DOWNLOAD_PATH" || echo "not present!")"
        DebugScript 'user arguments' "$USER_ARGS_RAW"
        DebugScript 'target app' "$TARGET_APP"
        DebugThinSeparator
    fi

    if [[ $errorcode -eq 0 ]]; then
        $MKDIR_CMD -p "$WORKING_PATH" 2> /dev/null
        result=$?

        if [[ $result -ne 0 ]]; then
            ShowError "Unable to create working directory ($WORKING_PATH) [$result]"
            errorcode=2
            returncode=1
        else
            cd "$WORKING_PATH"
        fi
    fi

    if [[ $errorcode -eq 0 ]]; then
        $MKDIR_CMD -p "$QPKG_DL_PATH" 2> /dev/null
        result=$?

        if [[ $result -ne 0 ]]; then
            ShowError "Unable to create QPKG download directory ($QPKG_DL_PATH) [$result]"
            errorcode=3
            returncode=1
        fi
    fi

    if [[ $errorcode -eq 0 ]]; then
        [[ -d $IPKG_DL_PATH ]] && rm -r "$IPKG_DL_PATH"
        $MKDIR_CMD -p "$IPKG_DL_PATH" 2> /dev/null
        result=$?

        if [[ $result -ne 0 ]]; then
            ShowError "Unable to create IPKG download directory ($IPKG_DL_PATH) [$result]"
            errorcode=4
            returncode=1
        else
            monitor_flag="$IPKG_DL_PATH/.monitor"
        fi
    fi

    if [[ $errorcode -eq 0 ]]; then
        $MKDIR_CMD -p "$IPKG_CACHE_PATH" 2> /dev/null
        result=$?

        if [[ $result -ne 0 ]]; then
            ShowError "Unable to create IPKG cache directory ($IPKG_CACHE_PATH) [$result]"
            errorcode=5
            returncode=1
        fi
    fi

    if [[ $errorcode -eq 0 ]]; then
        if [[ $TARGET_APP = 'SABnzbdplus' ]] && QPKGIsInstalled 'QSabNZBdPlus' && QPKGIsInstalled 'SABnzbdplus'; then
            ShowError 'Both (SABnzbdplus) and (QSabNZBdPlus) are installed. This is an unsupported configuration. Please manually uninstall the unused one via the QNAP App Center then re-run this installer.'
            errorcode=6
            returncode=1
        fi
    fi

    if [[ $errorcode -eq 0 ]]; then
        if QPKGIsInstalled 'Entware-ng' && QPKGIsInstalled 'Entware-3x'; then
            ShowError 'Both (Entware-ng) and (Entware-3x) are installed. This is an unsupported configuration. Please manually uninstall both of them via the QNAP App Center then re-run this installer.'
            errorcode=7
            returncode=1
        fi
    fi

    if [[ $errorcode -eq 0 ]]; then
        CalcStephaneQPKGArch
        CalcEntwareQPKG
        ShowProc "testing network access"

        if ($PING_CMD -c 1 -q google.com > /dev/null 2>&1); then
            ShowDone "OK"
        else
            ShowError "No network access"
            errorcode=7
            returncode=1
        fi
    fi

    DebugFuncExit
    return $returncode

    }

DisplayHelp()
    {

    echo -e "\nEach application is (re)installed by calling $0 with the name of the required app as an argument.\n\nSome examples are:"
    echo "$0 SABnzbd"
    echo "$0 SickRage"
    echo "$0 CouchPotato2"
    echo "$0 LazyLibrarian"
    echo "$0 OMedusa"
    echo

    }

PauseDownloaders()
    {

    [[ $errorcode -gt 0 ]] && return 1

    DebugFuncEntry

    # pause local SAB queue so installer downloads will finish faster
    if QPKGIsInstalled SABnzbdplus; then
        LoadQPKGVars SABnzbdplus
        SabQueueControl pause
    elif QPKGIsInstalled QSabNZBdPlus; then
        LoadQPKGVars QSabNZBdPlus
        SabQueueControl pause
    fi

    DebugFuncExit
    return 0

    }

DownloadQPKGs()
    {

    [[ $errorcode -gt 0 ]] && return 1

    DebugFuncEntry
    local returncode=0
    local SL=''

    # Entware is always required
    if ! QPKGIsInstalled "$PREF_ENTWARE"; then
        LoadQPKGDownloadDetails "$PREF_ENTWARE" && DownloadQPKG

    elif [[ $PREF_ENTWARE = Entware-3x ]]; then
        local testfile=/opt/etc/passwd
        [[ -e $testfile ]] && { [[ -L $testfile ]] && ENTWARE_VER=std || ENTWARE_VER=alt ;} || ENTWARE_VER=none

        if [[ $ENTWARE_VER = alt ]]; then
            ShowError 'Entware-3x (alt) is installed. This configuration has not been tested.'
            errorcode=8
            returncode=1
        elif [[ $ENTWARE_VER = none ]]; then
            ShowError 'Entware appears to be installed but is not visible.'
            errorcode=9
            returncode=1
        fi
    fi

    # now choose package(s) to download
    if [[ $errorcode -eq 0 ]]; then
        case "$STEPHANE_QPKG_ARCH" in
            x86)
                ! QPKGIsInstalled Par2cmdline-MT && LoadQPKGDownloadDetails Par2cmdline-MT && DownloadQPKG
                ;;
            none)
                ;;
            *)
                ! QPKGIsInstalled Par2 && LoadQPKGDownloadDetails Par2 && DownloadQPKG
                ;;
        esac

        [[ $errorcode -eq 0 ]] && LoadQPKGDownloadDetails "$TARGET_APP" && DownloadQPKG
    fi

    DebugFuncExit
    return $returncode

    }

RemovePackageInstallers()
    {

    [[ $errorcode -gt 0 ]] && return 1

    DebugFuncEntry

    [[ $PREF_ENTWARE = Entware-3x ]] && UninstallQPKG Entware-ng
    UninstallQPKG Optware || errorcode=0  # ignore Optware uninstall errors

    DebugFuncExit
    return 0

    }

RemoveOther()
    {

    [[ $errorcode -gt 0 ]] && return 1

    DebugFuncEntry

    # cruft - remove previous x41 Par2cmdline-MT package due to wrong arch - this was corrected on 2017-06-03

    # no longer use Par2cmdline-MT for x86_64 as multi-thread changes have been merged upstream into Par2cmdline and Par2cmdline-MT has been discontinued
    case "$STEPHANE_QPKG_ARCH" in
        x86)
            QPKGIsInstalled Par2 && UninstallQPKG Par2
            ;;
        none)
            ;;
        *)
            QPKGIsInstalled Par2cmdline-MT && UninstallQPKG Par2cmdline-MT
            ;;
    esac

    DebugFuncExit
    return 0

    }

InstallEntware()
    {

    [[ $errorcode -gt 0 ]] && return 1

    DebugFuncEntry
    local returncode=0

    if ! QPKGIsInstalled "$PREF_ENTWARE"; then
        # rename original [/opt]
        opt_path=/opt
        opt_backup_path=/opt.orig
        [[ -d $opt_path && ! -L $opt_path && ! -e $opt_backup_path ]] && $MV_CMD "$opt_path" "$opt_backup_path"

        LoadQPKGDownloadDetails "$PREF_ENTWARE" && InstallQPKG && ReloadProfile

        # copy all files from original [/opt] into new [/opt]
        [[ -L $opt_path && -d $opt_backup_path ]] && $CP_CMD --recursive "$opt_backup_path"/* --target-directory "$opt_path" && $RM_CMD -r "$opt_backup_path"

    else
        if [[ $PREF_ENTWARE = Entware-3x ]]; then
            local testfile=/opt/etc/passwd
            [[ -e $testfile ]] && { [[ -L $testfile ]] && ENTWARE_VER=std || ENTWARE_VER=alt ;} || ENTWARE_VER=none

            DebugQPKG version "$ENTWARE_VER"
            ReloadProfile

            if [[ $ENTWARE_VER = alt ]]; then
                ShowError "Entware-3x (alt) is installed. This config has not been tested. Can't continue."
                errorcode=11
                returncode=1
            fi
        fi

        [[ $STEPHANE_QPKG_ARCH != none ]] && ($OPKG_CMD list-installed | $GREP_CMD -q par2cmdline) && $OPKG_CMD remove par2cmdline >> /dev/null
    fi

    LoadQPKGVars "$PREF_ENTWARE" && PatchEntwareInit

    DebugFuncExit
    return $returncode

    }

PatchEntwareInit()
    {

    local returncode=0
    local findtext=''
    local inserttext=''

    if [[ ! -e $package_init_pathfile ]]; then
        ShowError "No init file found [$package_init_pathfile]"
        errorcode=12
        returncode=1
    else
        if ($GREP_CMD -q 'opt.orig' "$package_init_pathfile"); then
            DebugInfo 'patch: do the "opt shuffle" - already done'
        else
            findtext='/bin/rm -rf /opt'
            inserttext='opt_path="/opt"; opt_backup_path="/opt.orig"; [ -d "$opt_path" ] \&\& [ ! -L "$opt_path" ] \&\& [ ! -e "$opt_backup_path" ] \&\& mv "$opt_path" "$opt_backup_path"'
            $SED_CMD -i "s|$findtext|$inserttext\n$findtext|" "$package_init_pathfile"

            findtext='/bin/ln -sf $QPKG_DIR /opt'
            inserttext=$(echo -e "\t")'[ -L "$opt_path" ] \&\& [ -d "$opt_backup_path" ] \&\& cp "$opt_backup_path"/* --target-directory "$opt_path" \&\& rm -r "$opt_backup_path"'
            $SED_CMD -i "s|$findtext|$findtext\n$inserttext\n|" "$package_init_pathfile"

            DebugDone 'patch: do the "opt shuffle"'
        fi
    fi

    return $returncode

    }

UpdateEntware()
    {

    DebugFuncEntry
    local returncode=0
    local package_list_file=/opt/var/opkg-lists/packages
    local package_list_age=60
    local result=''
    local log_pathfile="${IPKG_DL_PATH}/entware-update.log"

    if [[ ! -f $OPKG_CMD ]]; then
        ShowError "Entware opkg binary is missing. [$OPKG_CMD]"
        errorcode=13
        returncode=1
    else
        # if Entware package list was updated only recently, don't run another update
        [[ -e $FIND_CMD ]] && result=$($FIND_CMD "$package_list_file" -mmin +$package_list_age)

        # temporarily force update until new combined Entware QPKG is available
        result='x'

        if [[ -n $result ]] ; then
            ShowProc "updating 'Entware'"

            install_msgs=$($OPKG_CMD update; $OPKG_CMD upgrade; $OPKG_CMD update; $OPKG_CMD upgrade 2>&1)
            result=$?
            echo -e "${install_msgs}\nresult=[$result]" >> "$log_pathfile"

            if [[ $result -eq 0 ]]; then
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

InstallExtras()
    {

    [[ $errorcode -gt 0 ]] && return 1

    DebugFuncEntry

    case "$STEPHANE_QPKG_ARCH" in
        x86)
            ! QPKGIsInstalled Par2cmdline-MT && LoadQPKGDownloadDetails Par2cmdline-MT && {
                InstallQPKG
                if [[ $errorcode -gt 0 ]]; then
                    ShowWarning "Par2cmdline-MT installation failed - but it's not essential so I'm continuing"
                    errorcode=0
                    DebugVar errorcode
                fi
                }
            ;;
        none)
            ;;
        *)
            ! QPKGIsInstalled Par2 && LoadQPKGDownloadDetails Par2 && {
                InstallQPKG
                if [[ $errorcode -gt 0 ]]; then
                    ShowWarning "Par2 installation failed - but it's not essential so I'm continuing"
                    errorcode=0
                    DebugVar errorcode
                fi
                }
            ;;
    esac
    [[ $errorcode -eq 0 ]] && InstallIPKs
    [[ $errorcode -eq 0 ]] && InstallPIPs

    DebugFuncExit
    return 0

    }

InstallIPKs()
    {

    DebugFuncEntry
    local returncode=0
    local install_msgs=''
    local result=''
    local packages=''
    local package_desc=''
    local log_pathfile="${IPKG_DL_PATH}/ipks.$INSTALL_LOG_FILE"

    if [[ ! -z $IPKG_DL_PATH && -d $IPKG_DL_PATH ]]; then
        UpdateEntware

        # errors can occur due to incompatible IPKs (tried installing Entware-3x, then Entware-ng), so delete them first
        rm -f "$IPKG_DL_PATH"/*.ipk

        packages='gcc python python-pip python-cffi python-pyopenssl ca-certificates nano git git-http unrar p7zip ionice ffprobe'
        [[ $STEPHANE_QPKG_ARCH = none ]] && packages+=' par2cmdline'
        package_desc=various
        GetInstallablePackageSize
        ipk_download_startseconds=$($DATE_CMD +%s)
        ShowProc "downloading & installing IPKs ($package_desc)"
        touch "$monitor_flag"
        trap CTRL_C_Captured INT
        PathSizeMonitor $download_size &
        install_msgs=$($OPKG_CMD install --force-overwrite $packages --cache "$IPKG_CACHE_PATH" --tmp-dir "$IPKG_DL_PATH" 2>&1)
        result=$?
        [[ -e $monitor_flag ]] && { rm "$monitor_flag"; sleep 1 ;}
        trap - INT
        echo -e "${install_msgs}\nresult=[$result]" > "$log_pathfile"

        if [[ $result -eq 0 ]]; then
            ShowDone "downloaded & installed IPKs ($package_desc)"
            DebugStage 'elapsed time' "$(ConvertSecs "$(($($DATE_CMD +%s)-$([[ -n $ipk_download_startseconds ]] && echo $ipk_download_startseconds || echo "1")))")"

            packages='python-dev'
            package_desc=python-dev
            GetInstallablePackageSize
            ipk_download_startseconds=$($DATE_CMD +%s)
            ShowProc "downloading & installing IPKG ($package_desc)"
            touch "$monitor_flag"
            trap CTRL_C_Captured INT
            PathSizeMonitor $download_size &
            install_msgs=$($OPKG_CMD install --force-overwrite $packages --cache "$IPKG_CACHE_PATH" --tmp-dir "$IPKG_DL_PATH" 2>&1)
            result=$?
            [[ -e $monitor_flag ]] && { rm "$monitor_flag"; sleep 1 ;}
            trap - INT
            echo -e "${install_msgs}\nresult=[$result]" >> "$log_pathfile"

            if [[ $result -eq 0 ]]; then
                ShowDone "downloaded & installed IPKG ($package_desc)"
            else
                ShowError "Download & install IPKG failed ($package_desc) [$result]"
                if [[ $debug = true ]]; then
                    DebugThickSeparator
                    $CAT_CMD "$log_pathfile"
                    DebugThickSeparator
                fi
                errorcode=16
                returncode=1
            fi
            DebugStage 'elapsed time' "$(ConvertSecs "$(($($DATE_CMD +%s)-$([[ -n $ipk_download_startseconds ]] && echo $ipk_download_startseconds || echo "1")))")"
        else
            ShowError "Download & install IPKGs failed ($package_desc) [$result]"
            if [[ $debug = true ]]; then
                DebugThickSeparator
                $CAT_CMD "$log_pathfile"
                DebugThickSeparator
            fi
            errorcode=17
            returncode=1
            DebugStage 'elapsed time' "$(ConvertSecs "$(($($DATE_CMD +%s)-$([[ -n $ipk_download_startseconds ]] && echo $ipk_download_startseconds || echo "1")))")"
        fi
    else
        ShowError "IPKG path does not exist [$IPKG_DL_PATH]"
        errorcode=18
        returncode=1
    fi

    DebugFuncExit
    return $returncode

    }

InstallPIPs()
    {

    DebugFuncEntry
    local install_msgs=''
    local returncode=0

    local op='pip packages'
    local log_pathfile="${WORKING_PATH}/$(echo "$op" | $TR_CMD " " "_").$INSTALL_LOG_FILE"

    ShowProc "downloading & installing ($op)"

    install_msgs=$(pip install setuptools pip && pip install sabyenc==3.3.2 cheetah 2>&1)
    result=$?
    echo -e "${install_msgs}\nresult=[$result]" > "$log_pathfile"

    if [[ $result -eq 0 ]]; then
        ShowDone "downloaded & installed ($op)"
    else
        ShowError "Download & install failed ($op) [$result]"
        DebugThickSeparator
        $CAT_CMD "$log_pathfile"
        DebugThickSeparator
        errorcode=19
        returncode=1
    fi

    DebugFuncExit
    return $returncode

    }

InstallNG()
    {

    [[ $errorcode -gt 0 ]] && return 1

    DebugFuncEntry

    ! IPKIsInstalled nzbget && {
        local returncode=0
        local install_msgs=''
        local result=''
        local packages=''
        local package_desc=''

        if [[ ! -z $IPKG_DL_PATH && -d $IPKG_DL_PATH ]]; then
            packages='nzbget'
            package_desc=nzbget

            ShowProc "downloading & installing IPKG ($package_desc)"

            cd "$IPKG_DL_PATH"
            install_msgs=$($OPKG_CMD install --force-overwrite $packages --cache . 2>&1)
            result=$?
            echo -e "${install_msgs}\nresult=[$result]" >> "${IPKG_DL_PATH}/ipk.$INSTALL_LOG_FILE"

            if [[ $result -eq 0 ]]; then
                ShowDone "downloaded & installed IPKG ($package_desc)"
                ShowProc "modifying NZBGet"

                sed -i 's|ConfigTemplate=.*|ConfigTemplate=/opt/share/nzbget/nzbget.conf.template|g' "/opt/share/nzbget/nzbget.conf"
                ShowDone "modified NZBGet"
                /opt/etc/init.d/S75nzbget start
                cat /opt/share/nzbget/nzbget.conf | grep ControlPassword=
                #Go to default router ip address and port 6789 192.168.1.1:6789 and now you should see NZBget interface
            else
                ShowError "Download & install IPKG failed ($package_desc) [$result]"
                errorcode=20
                returncode=1
            fi

            cd "$WORKING_PATH"
        else
            ShowError "IPKG path does not exist [$IPKG_DL_PATH]"
            errorcode=21
            returncode=1
        fi
    } #&& LoadIPKVars "nzbget"

    DebugFuncExit
    return 0

    }

InstallQPKG()
    {

    DebugFuncEntry
    local install_msgs=''
    local returncode=0
    local target_file=''

    if [[ ${qpkg_pathfile##*.} = 'zip' ]]; then
        $UNZIP_CMD -nq "$qpkg_pathfile" -d "$QPKG_DL_PATH"
        qpkg_pathfile="${qpkg_pathfile%.*}"
    fi

    local log_pathfile="$qpkg_pathfile.$INSTALL_LOG_FILE"
    target_file=$($BASENAME_CMD "$qpkg_pathfile")
    ShowProc "installing QPKG ($target_file) - this can take a while"
    install_msgs=$(eval sh "$qpkg_pathfile" 2>&1)
    result=$?

    echo -e "${install_msgs}\nresult=[$result]" > "$log_pathfile"

    if [[ $result -eq 0 || $result -eq 10 ]]; then
        ShowDone "installed QPKG ($target_file)"
    else
        ShowError "QPKG installation failed ($target_file) [$result]"

        if [[ $debug = true ]]; then
            DebugThickSeparator
            $CAT_CMD "$log_pathfile"
            DebugThickSeparator
        fi

        errorcode=22
        returncode=1
    fi

    DebugFuncExit
    return $returncode

    }

BackupThisPackage()
    {

    if [[ -d $package_config_path ]]; then
        if [[ ! -d ${BACKUP_PATH}/config ]]; then
            $MKDIR_CMD -p "$BACKUP_PATH" 2> /dev/null
            result=$?

            if [[ $result -eq 0 ]]; then
                DebugDone "backup directory created ($BACKUP_PATH)"
            else
                ShowError "Unable to create backup directory ($BACKUP_PATH) [$result]"
                errorcode=23
                returncode=1
            fi
        fi

        if [[ $errorcode -eq 0 ]]; then
            if [[ ! -d ${BACKUP_PATH}/config ]]; then
                $MV_CMD "$package_config_path" "$BACKUP_PATH"
                result=$?

                if [[ $result -eq 0 ]]; then
                    ShowDone "created ($TARGET_APP) settings backup"
                else
                    ShowError "Could not create settings backup of ($package_config_path) [$result]"
                    errorcode=24
                    returncode=1
                fi
            else
                DebugInfo "a backup set already exists ($BACKUP_PATH)"
            fi
        fi

        ConvertSettings
    fi

    }

BackupConfig()
    {

    [[ $errorcode -gt 0 ]] && return 1

    DebugFuncEntry
    local returncode=0

    case "$TARGET_APP" in
        SABnzbdplus)
            if QPKGIsInstalled QSabNZBdPlus; then
                LoadQPKGVars QSabNZBdPlus
                DaemonCtl stop "$package_init_pathfile"

            elif QPKGIsInstalled SABnzbdplus; then
                LoadQPKGVars SABnzbdplus
                DaemonCtl stop "$package_init_pathfile"
            fi

            REINSTALL_FLAG=$package_is_installed
            [[ $package_is_installed = true ]] && BackupThisPackage
            ;;
        CouchPotato2)
            if QPKGIsInstalled QCouchPotato; then
                LoadQPKGVars QCouchPotato
                DaemonCtl stop "$package_init_pathfile"

            elif QPKGIsInstalled CouchPotato2; then
                LoadQPKGVars CouchPotato2
                DaemonCtl stop "$package_init_pathfile"
            fi

            REINSTALL_FLAG=$package_is_installed
            [[ $package_is_installed = true ]] && BackupThisPackage
            ;;
        LazyLibrarian)
            if QPKGIsInstalled LazyLibrarian; then
                LoadQPKGVars LazyLibrarian
                DaemonCtl stop "$package_init_pathfile"
            fi

            REINSTALL_FLAG=$package_is_installed
            [[ $package_is_installed = true ]] && BackupThisPackage
            ;;
        SickRage)
            if QPKGIsInstalled SickRage; then
                LoadQPKGVars SickRage
                DaemonCtl stop "$package_init_pathfile"
            fi

            REINSTALL_FLAG=$package_is_installed
            [[ $package_is_installed = true ]] && BackupThisPackage
            ;;
        OMedusa)
            if QPKGIsInstalled OMedusa; then
                LoadQPKGVars OMedusa
                DaemonCtl stop "$package_init_pathfile"
            fi

            REINSTALL_FLAG=$package_is_installed
            [[ $package_is_installed = true ]] && BackupThisPackage
            ;;
        *)
            ShowError "Can't backup specified app: ($TARGET_APP) - unknown!"
            returncode=1
            ;;
    esac

    DebugFuncExit
    return $returncode

    }

ConvertSettings()
    {

    DebugFuncEntry
    local returncode=0

    case "$TARGET_APP" in
        SABnzbdplus)
            local OLD_BACKUP_PATH="${BACKUP_PATH}/SAB_CONFIG"
            [[ -d $OLD_BACKUP_PATH ]] && { $MV_CMD "$OLD_BACKUP_PATH" "$SETTINGS_BACKUP_PATH"; DebugDone 'renamed backup config path' ;}

            OLD_BACKUP_PATH="${BACKUP_PATH}/Config"
            [[ -d $OLD_BACKUP_PATH ]] && { $MV_CMD "$OLD_BACKUP_PATH" "$SETTINGS_BACKUP_PATH"; DebugDone 'renamed backup config path' ;}

            # for converting from Stephane's QPKG and from previous version SAB QPKGs
            local SETTINGS_PREV_BACKUP_PATHFILE="${SETTINGS_BACKUP_PATH}/sabnzbd.ini"

            [[ -f $SETTINGS_PREV_BACKUP_PATHFILE ]] && { $MV_CMD "$SETTINGS_PREV_BACKUP_PATHFILE" "$SETTINGS_BACKUP_PATHFILE"; DebugDone 'renamed backup config file' ;}

            if [[ -f $SETTINGS_BACKUP_PATHFILE ]]; then
                $SED_CMD -i "s|log_dir = logs|log_dir = ${SHARE_DOWNLOAD_PATH}/sabnzbd/logs|" "$SETTINGS_BACKUP_PATHFILE"
                $SED_CMD -i "s|download_dir = Downloads/incomplete|download_dir = ${SHARE_DOWNLOAD_PATH}/incomplete|" "$SETTINGS_BACKUP_PATHFILE"
                $SED_CMD -i "s|complete_dir = Downloads/complete|complete_dir = ${SHARE_DOWNLOAD_PATH}/complete|" "$SETTINGS_BACKUP_PATHFILE"

                if ($GREP_CMD -q '^enable_https = 1' "$SETTINGS_BACKUP_PATHFILE"); then
                    package_port=$($GREP_CMD '^https_port = ' "$SETTINGS_BACKUP_PATHFILE" | $HEAD_CMD -n1 | $CUT_CMD -f3 -d' ')
                    secure_web_login=true
                else
                    package_port=$($GREP_CMD '^port = ' "$SETTINGS_BACKUP_PATHFILE" | $HEAD_CMD -n1 | $CUT_CMD -f3 -d' ')
                fi
            fi
            ;;
        LazyLibrarian|SickRage|OMedusa)
            # do nothing - don't need to convert from older versions for these QPKGs as sherpa is the only installer for them.
            ;;
        CouchPotato2)
            ShowWarning "Can't convert settings for ($TARGET_APP) yet!"
            ;;
        *)
            ShowError "Can't convert settings for ($TARGET_APP) - unsupported app!"
            returncode=1
            ;;
    esac

    DebugFuncExit
    return $returncode

    }

ReloadProfile()
    {

    QPKGIsInstalled "$PREF_ENTWARE" && export PATH="/opt/bin:/opt/sbin:$PATH"

    DebugDone 'adjusted $PATH'
    DebugVar PATH

    return 0

    }

RestoreConfig()
    {

    [[ $errorcode -gt 0 ]] && return 1

    DebugFuncEntry
    local returncode=0

    if QPKGIsInstalled "$TARGET_APP"; then
        case "$TARGET_APP" in
            SABnzbdplus)
                if [[ -d $SETTINGS_BACKUP_PATH ]]; then
                    #sleep 10; DaemonCtl stop "$package_init_pathfile"  # allow time for new package init to complete so PID is accurate
                    DaemonCtl stop "$package_init_pathfile"

                    if [[ ! -d $package_config_path ]]; then
                        $MKDIR_CMD -p "$($DIRNAME_CMD "$package_config_path")" 2> /dev/null
                    else
                        $RM_CMD -r "$package_config_path" 2> /dev/null
                    fi

                    $MV_CMD "$SETTINGS_BACKUP_PATH" "$($DIRNAME_CMD "$package_config_path")"
                    result=$?

                    if [[ $result -eq 0 ]]; then
                        ShowDone "restored ($TARGET_APP) settings backup"

                        $SETCFG_CMD "SABnzbdplus" Web_Port $package_port -f "$QPKG_CONFIG_PATHFILE"
                    else
                        ShowError "Could not restore settings backup to ($package_config_path) [$result]"
                        errorcode=25
                        returncode=1
                    fi
                fi
                ;;
            LazyLibrarian|SickRage|CouchPotato2|OMedusa)
                if [[ -d $SETTINGS_BACKUP_PATH ]]; then
                    #sleep 10; DaemonCtl stop "$package_init_pathfile"  # allow time for new package init to complete so PID is accurate
                    DaemonCtl stop "$package_init_pathfile"

                    if [[ ! -d $package_config_path ]]; then
                        $MKDIR_CMD -p "$($DIRNAME_CMD "$package_config_path")" 2> /dev/null
                    else
                        $RM_CMD -r "$package_config_path" 2> /dev/null
                    fi

                    $MV_CMD "$SETTINGS_BACKUP_PATH" "$($DIRNAME_CMD "$package_config_path")"
                    result=$?

                    if [[ $result -eq 0 ]]; then
                        ShowDone "restored ($TARGET_APP) settings backup"

                        #$SETCFG_CMD "SABnzbdplus" Web_Port $package_port -f "$QPKG_CONFIG_PATHFILE"
                    else
                        ShowError "Could not restore settings backup to ($package_config_path) [$result]"
                        errorcode=26
                        returncode=1
                    fi
                fi
                ;;
            *)
                ShowError "Can't restore settings for ($TARGET_APP) - unsupported app!"
                returncode=1
                ;;
        esac
    else
        ShowError "($TARGET_APP) is NOT installed so can't restore backups"
        errorcode=27
        returncode=1
    fi

    DebugFuncExit
    return $returncode

    }

DownloadQPKG()
    {

    [[ $errorcode -gt 0 ]] && return 1

    DebugFuncEntry
    local returncode=0

    if [[ -e $qpkg_pathfile ]]; then
        file_md5=$($MD5SUM_CMD "$qpkg_pathfile" | $CUT_CMD -f1 -d' ')
        result=$?

        if [[ $result -eq 0 ]]; then
            if [[ $file_md5 = $qpkg_md5 ]]; then
                DebugInfo "existing QPKG checksum correct ($qpkg_file)"
            else
                DebugWarning "existing QPKG checksum incorrect ($qpkg_file) [$result]"
                DebugInfo "deleting ($qpkg_pathfile) [$result]"
                $RM_CMD -f "$qpkg_pathfile"
            fi
        else
            ShowError "Problem creating checksum from existing QPKG ($qpkg_file) [$result]"
            errorcode=28
            returncode=1
        fi
    fi

    if [[ $errorcode -eq 0 && ! -e $qpkg_pathfile ]]; then
        ShowProc "downloading QPKG ($qpkg_file)"
        local log_pathfile="$qpkg_pathfile.$DOWNLOAD_LOG_FILE"

        [[ -e $log_pathfile ]] && rm -f "$log_pathfile"

        # keep this one handy for SOCKS5
        # curl http://entware-3x.zyxmon.org/binaries/other/Entware-3x_1.00std.qpkg --socks5 IP:PORT --output target.qpkg

        if [[ $debug = true ]]; then
            $CURL_CMD --output "$qpkg_pathfile" "$qpkg_url" 2>&1 | tee -a "$log_pathfile"
            result=$?
        else
            $CURL_CMD --output "$qpkg_pathfile" "$qpkg_url" >> "$log_pathfile" 2>&1
            result=$?
        fi

        echo -e "\nresult=[$result]" >> "$log_pathfile"

        if [[ $result -eq 0 ]]; then
            file_md5=$($MD5SUM_CMD "$qpkg_pathfile" | $CUT_CMD -f1 -d' ')
            result=$?

            if [[ $result -eq 0 ]]; then
                if [[ $file_md5 = $qpkg_md5 ]]; then
                    ShowDone "downloaded QPKG ($qpkg_file)"
                else
                    ShowError "Downloaded QPKG checksum incorrect ($qpkg_file) [$result]"
                    errorcode=29
                    returncode=1
                fi
            else
                ShowError "Problem creating checksum from downloaded QPKG [$result]"
                errorcode=30
                returncode=1
            fi
        else
            ShowError "Download failed ($qpkg_pathfile) [$result]"

            if [[ $debug = true ]]; then
                DebugThickSeparator
                $CAT_CMD "$log_pathfile"
                DebugThickSeparator
            fi

            errorcode=31
            returncode=1
        fi
    fi

    DebugFuncExit
    return $returncode

    }

CalcStephaneQPKGArch()
    {

    case "$NAS_ARCH" in
        x86_64)
            [[ $FIRMWARE_VERSION =~ '4.3.' ]] && STEPHANE_QPKG_ARCH=x64 || STEPHANE_QPKG_ARCH=x86
            ;;
        i686)
            STEPHANE_QPKG_ARCH=x86
            ;;
        armv7l)
            STEPHANE_QPKG_ARCH=x41
            ;;
        *)
            STEPHANE_QPKG_ARCH=none
            ;;
    esac

    DebugVar STEPHANE_QPKG_ARCH
    return 0

    }

CalcEntwareQPKG()
    {

    # decide which Entware is suitable for this NAS.
    PREF_ENTWARE=Entware-3x

    [[ $NAS_ARCH = i686 ]] && PREF_ENTWARE=Entware-ng
    QPKGIsInstalled Entware-ng && PREF_ENTWARE=Entware-ng

    DebugVar PREF_ENTWARE
    return 0

    }

LoadQPKGVars()
    {

    # $1 = installed package name to load variables for

    local returncode=0
    local package_name="$1"

    if [[ -z $package_name ]]; then
        DebugError 'QPKG name not specified'
        errorcode=32
        returncode=1
    else
        package_installed_path=''
        package_init_pathfile=''
        package_config_path=''
        local package_settings_pathfile=''
        package_port=''
        package_api=''
        sab_chartranslator_pathfile=''

        case "$package_name" in
            SABnzbdplus|QSabNZBdPlus)
                package_installed_path=$($GETCFG_CMD $package_name Install_Path -f $QPKG_CONFIG_PATHFILE)
                result=$?

                if [[ $result -eq 0 ]]; then
                    package_init_pathfile=$($GETCFG_CMD $package_name Shell -f $QPKG_CONFIG_PATHFILE)

                    if [[ $package_name = SABnzbdplus ]]; then
                        if [[ -d ${package_installed_path}/Config ]]; then
                            package_config_path=${package_installed_path}/Config
                        else
                            package_config_path=${package_installed_path}/config
                        fi

                    elif [[ $package_name = QSabNZBdPlus ]]; then
                        package_config_path=${package_installed_path}/SAB_CONFIG
                    fi

                    if [[ -f ${package_config_path}/sabnzbd.ini ]]; then
                        package_settings_pathfile=${package_config_path}/sabnzbd.ini
                    else
                        package_settings_pathfile=${package_config_path}/config.ini
                    fi

                    if [[ -e $SETTINGS_BACKUP_PATHFILE ]]; then
                        if ($GREP_CMD -q '^enable_https = 1' "$SETTINGS_BACKUP_PATHFILE"); then
                            package_port=$($GREP_CMD '^https_port = ' "$SETTINGS_BACKUP_PATHFILE" | $HEAD_CMD -n1 | $CUT_CMD -f3 -d' ')
                            secure_web_login=true
                        else
                            package_port=$($GREP_CMD '^port = ' "$SETTINGS_BACKUP_PATHFILE" | $HEAD_CMD -n1 | $CUT_CMD -f3 -d' ')
                        fi
                    else
                        package_port=$($GETCFG_CMD $package_name Web_Port -f $QPKG_CONFIG_PATHFILE)
                    fi

                    [[ -e $package_settings_pathfile ]] && package_api=$($GREP_CMD -e "^api_key" "$package_settings_pathfile" | $SED_CMD 's|api_key = ||')
                    sab_chartranslator_pathfile=$package_installed_path/Repository/scripts/CharTranslator.py
                else
                    returncode=1
                fi
                ;;
            Entware-3x|Entware-ng)
                package_installed_path=$($GETCFG_CMD $package_name Install_Path -f $QPKG_CONFIG_PATHFILE)
                result=$?

                if [[ $result -eq 0 ]]; then
                    package_init_pathfile=$($GETCFG_CMD $package_name Shell -f $QPKG_CONFIG_PATHFILE)
                else
                    returncode=1
                fi
                ;;
            QCouchPotato)
                package_installed_path=$($GETCFG_CMD $package_name Install_Path -f $QPKG_CONFIG_PATHFILE)
                result=$?

                if [[ $result -eq 0 ]]; then
                    package_init_pathfile=$($GETCFG_CMD $package_name Shell -f $QPKG_CONFIG_PATHFILE)
                else
                    returncode=1
                fi
                ;;
            LazyLibrarian|CouchPotato2|SickRage|OMedusa)
                package_installed_path=$($GETCFG_CMD $package_name Install_Path -f $QPKG_CONFIG_PATHFILE)
                result=$?

                if [[ $result -eq 0 ]]; then
                    package_init_pathfile=$($GETCFG_CMD $package_name Shell -f $QPKG_CONFIG_PATHFILE)

                    if [[ -d ${package_installed_path}/Config ]]; then
                        package_config_path=${package_installed_path}/Config
                    else
                        package_config_path=${package_installed_path}/config
                    fi
                else
                    returncode=1
                fi
                ;;
            *)
                ShowError "Can't load details of specified app: [$package_name] - unknown!"
                ;;

        esac
    fi

    return $returncode

    }

LoadQPKGDownloadDetails()
    {

    # $1 = QPKG name

    local returncode=0
    local target_file=''
    local OneCD_urlprefix='https://raw.githubusercontent.com/onecdonly/sherpa/master/QPKGs'
    local Stephane_urlprefix='http://www.qoolbox.fr'

    qpkg_url=''
    qpkg_md5=''
    qpkg_file=''
    qpkg_pathfile=''

    if [[ -z $1 ]]; then
        DebugError 'QPKG name not specified'
        errorcode=33
        returncode=1
    else
        qpkg_name="$1"
        local base_url=''

        case "$1" in
            Entware-3x)
                qpkg_md5='fa5719ab2138c96530287da8e6812746'
                qpkg_url='http://entware-3x.zyxmon.org/binaries/other/Entware-3x_1.00std.qpkg'
                ;;
            Entware-ng)
                qpkg_md5='6c81cc37cbadd85adfb2751dc06a238f'
                qpkg_url='http://entware.zyxmon.org/binaries/other/Entware-ng_0.97.qpkg'
                ;;
            SABnzbdplus)
                target_file='SABnzbdplus_180131.qpkg'
                qpkg_md5='3db999cd8c5598d804ad3954d7a0629c'
                qpkg_url="${OneCD_urlprefix}/SABnzbdplus/build/${target_file}?raw=true"
                qpkg_file=$target_file
                ;;
            SickRage)
                target_file='SickRage_180121.qpkg'
                qpkg_md5='2c99665d8fd0a423afbf9b4eae3a427d'
                qpkg_url="${OneCD_urlprefix}/SickRage/build/${target_file}?raw=true"
                qpkg_file=$target_file
                ;;
            CouchPotato2)
                target_file='CouchPotato2_180121.qpkg'
                qpkg_md5='0dc85000a8fe2c921e6265a19b13c3e0'
                qpkg_url="${OneCD_urlprefix}/CouchPotato2/build/${target_file}?raw=true"
                qpkg_file=$target_file
                ;;
            LazyLibrarian)
                target_file='LazyLibrarian_180121.qpkg'
                qpkg_md5='7bef6afcb8ba564638fb29c60594577d'
                qpkg_url="${OneCD_urlprefix}/LazyLibrarian/build/${target_file}?raw=true"
                qpkg_file=$target_file
                ;;
            OMedusa)
                target_file='OMedusa_180128.qpkg'
                qpkg_md5='bdbd33bf1148a9e12f1bfe0aa4f3dcc3'
                qpkg_url="${OneCD_urlprefix}/OMedusa/build/${target_file}?raw=true"
                qpkg_file=$target_file
                ;;
            Par2cmdline-MT)
                case "$STEPHANE_QPKG_ARCH" in
                    x86)
                        qpkg_md5='531832a39576e399f646890cc18969bb'
                        qpkg_url="${Stephane_urlprefix}/Par2cmdline-MT_0.6.14-MT_x86.qpkg.zip"
                        ;;
                    x64)
                        qpkg_md5='f3b3dd496289510ec0383cf083a50f8e'
                        qpkg_url="${Stephane_urlprefix}/Par2cmdline-MT_0.6.14-MT_x86_64.qpkg.zip"
                        ;;
                    x41)
                        qpkg_md5='1701b188115758c151f19956388b90cb'
                        qpkg_url="${Stephane_urlprefix}/Par2cmdline-MT_0.6.14-MT_arm-x41.qpkg.zip"
                        ;;
                esac
                ;;
            Par2)
                case "$STEPHANE_QPKG_ARCH" in
                    x64)
                        qpkg_md5='660882474ab00d4793a674d4b48f89be'
                        qpkg_url="${Stephane_urlprefix}/Par2_0.7.4.0_x86_64.qpkg.zip"
                        ;;
                    x41)
                        qpkg_md5='9c0c9d3e8512f403f183856fb80091a4'
                        qpkg_url="${Stephane_urlprefix}/Par2_0.7.4.0_arm-x41.qpkg.zip"
                        ;;
                esac
                ;;
            *)
                DebugError 'QPKG name not found'
                errorcode=34
                returncode=1
                ;;
        esac

        if [[ -z $qpkg_url || -z $qpkg_md5 ]]; then
            DebugError 'QPKG details not found'
            errorcode=35
            returncode=1
        else
            [[ -z $qpkg_file ]] && qpkg_file=$($BASENAME_CMD "$qpkg_url")
            qpkg_pathfile="${QPKG_DL_PATH}/${qpkg_file}"
        fi
    fi

    return $returncode

    }

UninstallQPKG()
    {

    # $1 = QPKG name

    [[ $errorcode -gt 0 ]] && return 1

    local returncode=0

    if [[ -z $1 ]]; then
        DebugError 'QPKG name not specified'
        errorcode=36
        returncode=1
    else
        qpkg_installed_path="$($GETCFG_CMD "$1" Install_Path -f "$QPKG_CONFIG_PATHFILE")"
        result=$?

        if [[ $result -eq 0 ]]; then
            qpkg_installed_path="$($GETCFG_CMD "$1" Install_Path -f "$QPKG_CONFIG_PATHFILE")"

            if [[ -e ${qpkg_installed_path}/.uninstall.sh ]]; then
                ShowProc "uninstalling QPKG '$1'"

                ${qpkg_installed_path}/.uninstall.sh > /dev/null
                result=$?

                if [[ $result -eq 0 ]]; then
                    ShowDone "uninstalled QPKG '$1'"
                else
                    ShowError "Unable to uninstall QPKG \"$1\" [$result]"
                    errorcode=37
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

DaemonCtl()
    {

    # $1 = action (start|stop)
    # $2 = pathfile of daemon init

    local returncode=0
    local msgs=''
    local target_init_pathfile=''
    local init_file=''

    if [[ -z $2 ]]; then
        DebugError 'daemon unspecified'
        errorcode=38
        returncode=1

    elif [[ ! -e $2 ]]; then
        DebugError "daemon ($2) not found"
        errorcode=39
        returncode=1

    else
        target_init_pathfile="$2"
        target_init_file=$($BASENAME_CMD "$target_init_pathfile")

        case "$1" in
            start)
                ShowProc "starting daemon ($target_init_file) - this can take a while"
                msgs=$("$target_init_pathfile" start)
                result=$?
                echo -e "${msgs}\nresult=[$result]" >> "$qpkg_pathfile.$START_LOG_FILE"

                if [[ $result -eq 0 ]]; then
                    ShowDone "daemon started ($target_init_file)"

                else
                    ShowWarning "could not start daemon ($target_init_file) [$result]"
                    if [[ $debug = true ]]; then
                        DebugThickSeparator
                        $CAT_CMD "$qpkg_pathfile.$START_LOG_FILE"
                        DebugThickSeparator
                    else
                        $CAT_CMD "$qpkg_pathfile.$START_LOG_FILE" >> "$DEBUG_LOG_PATHFILE"
                    fi
                    errorcode=40
                    returncode=1
                fi
                ;;
            stop)
                ShowProc "stopping daemon ($target_init_file)"
                msgs=$("$target_init_pathfile" stop)
                result=$?
                echo -e "${msgs}\nresult=[$result]" >> "$qpkg_pathfile.$STOP_LOG_FILE"

                if [[ $result -eq 0 ]]; then
                    ShowDone "daemon stopped ($target_init_file)"

                else
                    ShowWarning "could not stop daemon ($target_init_file) [$result]"
                    if [[ $debug = true ]]; then
                        DebugThickSeparator
                        $CAT_CMD "$qpkg_pathfile.$STOP_LOG_FILE"
                        DebugThickSeparator
                    else
                        $CAT_CMD "$qpkg_pathfile.$STOP_LOG_FILE" >> "$DEBUG_LOG_PATHFILE"
                    fi
                    # meh, continue anyway...
                    returncode=1
                fi
                ;;
            *)
                DebugError "action unrecognised ($1)"
                errorcode=41
                returncode=1
                ;;
        esac
    fi

    return $returncode

    }

CTRL_C_Captured()
    {

    [[ -e $monitor_flag ]] && rm "$monitor_flag"

    sleep 1

    exit

    }

Cleanup()
    {

    DebugFuncEntry

    cd "$SHARE_PUBLIC_PATH"

    [[ $errorcode -eq 0 && $debug != true && -d $WORKING_PATH ]] && $RM_CMD -rf "$WORKING_PATH"

    if [[ $queuepaused = true ]]; then
        if QPKGIsInstalled SABnzbdplus; then
            LoadQPKGVars SABnzbdplus
            SabQueueControl resume
        elif QPKGIsInstalled QSabNZBdPlus; then
            LoadQPKGVars QSabNZBdPlus
            SabQueueControl resume
        fi
    fi

    DebugFuncExit
    return 0

    }

DisplayResult()
    {

    [[ $errorcode -eq 1 ]] && return 1

    DebugFuncEntry
    local RE=''
    local SL=''

    [[ $REINSTALL_FLAG = true ]] && RE='re' || RE=''
    [[ $secure_web_login = true ]] && SL='s' || SL=''
    [[ $debug = false ]] && echo

    if [[ $errorcode -eq 0 ]]; then
        [[ $debug = true ]] && emoticon=':DD' || emoticon=''
        ShowDone "$TARGET_APP has been successfully ${RE}installed! $emoticon"
        #[[ $debug = false ]] && echo
        #ShowInfo "It should now be accessible on your LAN @ $(ColourTextUnderlinedBlue "http${SL}://$($HOSTNAME_CMD -i | $TR_CMD -d ' '):$package_port")"
    else
        [[ $debug = true ]] && emoticon=':S ' || emoticon=''
        ShowError "$TARGET_APP ${RE}install failed! ${emoticon}[$errorcode]"
    fi

    DebugScript 'finished' "$($DATE_CMD)"
    DebugScript 'elapsed time' "$(ConvertSecs "$(($($DATE_CMD +%s)-$([[ -n $SCRIPT_STARTSECONDS ]] && echo $SCRIPT_STARTSECONDS || echo "1")))")"
    DebugThickSeparator

    [[ -e $DEBUG_LOG_PATHFILE && $debug = false ]] && echo -e "\n- To display the debug log, use:\nless ${DEBUG_LOG_PATHFILE}\n"

    DebugFuncExit
    return 0

    }

GetInstallablePackageSize()
    {

    download_size=0
    local download_packages=()
    local new="$packages"
    local old=''
    local iterations=0
    local iteration_limit=10
    local complete=false

    ShowProc "calculating number and size of IPKGs required"

    while [[ $iterations -lt $iteration_limit ]]; do
        ((iterations++))
        old="$new"
        new="$($OPKG_CMD depends -A $old | sed 's|^[[:blank:]]*||;s|depends on:$||;s|[[:blank:]]*$||' | sort | uniq)"
        [[ $old = $new ]] && { complete=true; break ;}
    done

    if [[ $complete = true ]]; then
        DebugInfo "found all dependencies in $iterations iterations"
    else
        DebugError "Dependency list is incomplete! Consider raising \$iteration_limit [$iteration_limit]."
    fi

    all_raw_packages="$new"
    read -r -a all_required_packages_array <<< $all_raw_packages
    all_required_packages=($(printf '%s\n' "${all_required_packages_array[@]}"))

    # exclude packages already installed
    for element in ${all_required_packages[@]}; do
        ($OPKG_CMD info $element | LC_ALL=C grep 'Status: ' | LC_ALL=C grep -q 'not-installed') && download_packages+=($element)
    done

    DebugInfo "IPKG names: ${download_packages[*]}"

    for element in ${download_packages[@]}; do
        result_size=$($OPKG_CMD info $element | grep 'Size:' | sed 's|^Size: ||')
        ((download_size+=result_size))
    done

    [[ -z $download_size ]] && download_size=0

    DebugVar 'download_size'
    ShowDone "${#download_packages[@]} IPKGs ($(Convert2ISO $download_size)) are required"

    }

PathSizeMonitor()
    {

    [[ -z $1 || $1 -eq 0 ]] && return 1

    local total_bytes=$1
    local last_bytes=0
    local stall_seconds=0
    local stall_seconds_threshold=4
    local current_bytes=0
    local percent=''

    InitProgress

    while [[ -e $monitor_flag ]]; do
        sleep 1
        current_bytes=$($FIND_CMD $IPKG_DL_PATH -type f -name '*.ipk' -exec $DU_CMD --bytes --total --apparent-size {} + | $GREP_CMD total$ | $CUT_CMD -f1)
        [[ -z $current_bytes ]] && current_bytes=0
        percent="$((200*($current_bytes)/($total_bytes) % 2 + 100*($current_bytes)/($total_bytes)))%"

        if [[ $last_bytes -ne $current_bytes ]]; then
            last_bytes=$current_bytes
            stall_seconds=0
        else
            ((stall_seconds++))
        fi

        progress_message=" $percent ($(Convert2ISO $current_bytes)/$(Convert2ISO $total_bytes))"
        [[ $stall_seconds -ge $stall_seconds_threshold ]] && progress_message+=" stalled for $stall_seconds seconds"

        ProgressUpdater "$progress_message"
    done

    [[ -n $progress_message ]] && ProgressUpdater " done!"

    }

SabQueueControl()
    {

    # $1 = 'pause' or 'resume'

    local returncode=0

    if [[ -z $1 ]]; then
        returncode=1
    elif [[ $1 != pause && $1 != resume ]]; then
        returncode=1
    else
        [[ $secure_web_login = true ]] && SL='s' || SL=''
        $WGET_CMD --no-check-certificate --quiet "http${SL}://127.0.0.1:${package_port}/sabnzbd/api?mode=${1}&apikey=${package_api}" -O - 2>&1 >/dev/null &
        [[ $1 = pause ]] && queuepaused=true || queuepaused=false
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
    package_is_installed=false

    if [[ -z $1 ]]; then
        DebugError 'QPKG name not specified'
        errorcode=42
        returncode=1
    else
        $GREP_CMD -q -F "[$1]" "$QPKG_CONFIG_PATHFILE"
        result=$?

        if [[ $result -eq 0 ]]; then
            if [[ $($GETCFG_CMD "$1" RC_Number -d 0 -f "$QPKG_CONFIG_PATHFILE") -ne 0 ]]; then
                DebugQPKG "'$1'" 'installed'
                [[ $($GETCFG_CMD "$1" Enable -u -f "$QPKG_CONFIG_PATHFILE") != 'TRUE' ]] && $SETCFG_CMD "$1" Enable TRUE -f "$QPKG_CONFIG_PATHFILE"
                package_is_installed=true
            else
                DebugQPKG "'$1'" 'not installed'
                returncode=1
            fi
        else
            DebugQPKG "'$1'" 'not installed'
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

    if [[ -z $1 ]]; then
        DebugError 'IPKG name not specified'
        errorcode=43
        returncode=1
    else
        $OPKG_CMD list-installed | $GREP_CMD -q -F "$1"
        result=$?

        if [[ $result -eq 0 ]]; then
            DebugQPKG "'$1'" 'installed'
        else
            DebugQPKG "'$1'" 'not installed'
            returncode=1
        fi
    fi

    return $returncode

    }

SysFilePresent()
    {

    # $1 = pathfile to check

    [[ -z $1 ]] && return 1

    if [[ ! -e $1 ]]; then
        ShowError "A required NAS system file is missing [$1]"
        errorcode=44
        return 1
    else
        return 0
    fi

    }

SysSharePresent()
    {

    # $1 = symlink path to check

    [[ -z $1 ]] && return 1

    if [[ ! -L $1 ]]; then
        ShowError "A required NAS system share is missing [$1]. Please re-create it via QNAP Control Panel -> Privilege Settings -> Shared Folders."
        errorcode=45
        return 1
    else
        return 0
    fi

    }

InitProgress()
    {

    # needs to be called prior to first call of ProgressUpdater

    progress_message=''
    previous_length=0
    previous_msg=''

    }

ProgressUpdater()
    {

    # $1 = message to display

    if [[ $1 != $previous_msg ]]; then
        temp="$1"
        current_length=$((${#temp}+1))

        if [[ $current_length -lt $previous_length ]]; then
            appended_length=$(($current_length-$previous_length))
            # backspace to start of previous msg, print new msg, add additional spaces, then backspace to end of msg
            printf "%${previous_length}s" | tr ' ' '\b' ; echo -n "$1 " ; printf "%${appended_length}s" ; printf "%${appended_length}s" | tr ' ' '\b'
        else
            # backspace to start of previous msg, print new msg
            printf "%${previous_length}s" | tr ' ' '\b' ; echo -n "$1 "
        fi

        previous_length=$current_length
        previous_msg="$1"
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

Convert2ISO()
    {

    echo $1 | awk 'BEGIN{ u[0]="B"; u[1]="kB"; u[2]="MB"; u[3]="GB"} { n = $1; i = 0; while(n > 1000) { i+=1; n= int((n/1000)+0.5) } print n u[i] } '

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

    DebugDetected 'SCRIPT' "$1" "$2"

    }

DebugStage()
    {

    DebugDetected 'STAGE' "$1" "$2"

    }

DebugNAS()
    {

    DebugDetected 'NAS' "$1" "$2"

    }

DebugQPKG()
    {

    DebugDetected 'QPKG' "$1" "$2"

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

    [[ $debug = true ]] && ShowDebug "$1"
    SaveDebug "$1"

    }

ShowInfo()
    {

    ShowLogLine_write "$(ColourTextBrightWhite info)" "$1"
    SaveLogLine info "$1"

    }

ShowProc()
    {

    ShowLogLine_write "$(ColourTextBrightOrange proc)" "$1 ..."
    SaveLogLine proc "$1 ..."

    }

ShowDebug()
    {

    ShowLogLine_write "$(ColourTextBlackOnCyan dbug)" "$1"

    }

ShowDone()
    {

    ShowLogLine_update "$(ColourTextBrightGreen done)" "$1"
    SaveLogLine done "$1"

    }

ShowWarning()
    {

    ShowLogLine_update "$(ColourTextBrightOrange warn)" "$1"
    SaveLogLine warn "$1"

    }

ShowError()
    {

    ShowLogLine_update "$(ColourTextBrightRed fail)" "$1"
    SaveLogLine fail "$1"

    }

SaveDebug()
    {

    SaveLogLine dbug "$1"

    }

ShowLogLine_write()
    {

    # writes a new message without newline (unless in debug mode)

    # $1 = pass/fail
    # $2 = message

    previous_msg=$(printf "[ %-10s ] %s" "$1" "$2")

    echo -n "$previous_msg"; [[ $debug = true ]] && echo

    return 0

    }

ShowLogLine_update()
    {

    # updates the previous message

    # $1 = pass/fail
    # $2 = message

    new_message=$(printf "[ %-10s ] %s" "$1" "$2")

    if [[ $new_message != $previous_msg ]]; then
        previous_length=$((${#previous_msg}+1))
        new_length=$((${#new_message}+1))

        # jump to start of line, print new msg
        strbuffer=$(echo -en "\r$new_message ")

        # if new msg is shorter then add spaces to end to cover previous msg
        [[ $new_length -lt $previous_length ]] && { appended_length=$(($new_length-$previous_length)); strbuffer+=$(printf "%${appended_length}s") ;}

        echo "$strbuffer"
    fi

    return 0

    }

SaveLogLine()
    {

    # $1 = pass/fail
    # $2 = message

    [[ -n $DEBUG_LOG_PATHFILE ]] && touch "$DEBUG_LOG_PATHFILE" && printf "[ %-4s ] %s\n" "$1" "$2" >> "$DEBUG_LOG_PATHFILE"

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

PauseHere()
    {

    # wait here temporarily

    local waittime=10

    ShowProc "waiting for $waittime seconds"
    sleep 10
    ShowDone "wait complete"

    }

Init
PauseDownloaders
RemoveOther
DownloadQPKGs
RemovePackageInstallers
InstallEntware
InstallExtras

if [[ $errorcode -eq 0 ]]; then
    case "$TARGET_APP" in
        SABnzbdplus)
            BackupConfig
            UninstallQPKG $TARGET_APP
            UninstallQPKG QSabNZBdPlus
            ! QPKGIsInstalled $TARGET_APP && LoadQPKGDownloadDetails $TARGET_APP && InstallQPKG && PauseHere && LoadQPKGVars $TARGET_APP
            RestoreConfig
            [[ $errorcode -eq 0 ]] && DaemonCtl start "$package_init_pathfile"
            ;;
        LazyLibrarian|SickRage|CouchPotato2|OMedusa)
            BackupConfig
            UninstallQPKG $TARGET_APP
            ! QPKGIsInstalled $TARGET_APP && LoadQPKGDownloadDetails $TARGET_APP && InstallQPKG && PauseHere && LoadQPKGVars $TARGET_APP
            RestoreConfig
            [[ $errorcode -eq 0 ]] && DaemonCtl start "$package_init_pathfile"
            ;;
        #NZBGet)
        #   ;;
        #HeadPhones)
        #   ;;
        *)
            ShowError "Can't install specified app: [$TARGET_APP] - unknown!"
            ;;
    esac
fi

Cleanup
DisplayResult

exit "$errorcode"
