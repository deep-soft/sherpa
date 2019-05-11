#!/usr/bin/env bash
####################################################################################
# sherpa.sh
#
# Copyright (C) 2017-2019 OneCD [one.cd.only@gmail.com]
#
# so, blame OneCD if it all goes horribly wrong. ;)
#
# For more info: https://forum.qnap.com/viewtopic.php?f=320&t=132373
#
# Tested on:
#  GNU bash, version 3.2.57(2)-release (i686-pc-linux-gnu)
#  Copyright (C) 2007 Free Software Foundation, Inc.
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
####################################################################################
# * Style Guide *
# function names: CamelCase
# variable names: lowercase_with_underscores (except for 'returncode' & 'errorcode')
# constants: UPPERCASE_WITH_UNDERSCORES
# indents: 1 x tab (= 4 x spaces)
####################################################################################

USER_ARGS_RAW="$@"

ResetErrorcode()
    {

    errorcode=0

    }

ParseArgs()
    {

    TARGET_APP=''
    TARGET_APPS=()

    if [[ -z $USER_ARGS_RAW ]]; then
        errorcode=1
        return 1
    else
        local user_args=($(echo "$USER_ARGS_RAW" | $TR_CMD '[A-Z]' '[a-z]'))
    fi

    for arg in ${user_args[@]}; do
        case $arg in
            -d|--debug)
                debug=true
                DebugVar debug
                ;;
            --check)
                satisfy_dependencies_only=true
                DebugVar satisfy_dependencies_only
                ;;
            --update)
                update_all_apps=true
                DebugVar update_all_apps
                ;;
            --help)
                errorcode=2
                return 1
                ;;
            *)
                TARGET_APP=$(MatchAbbrvToQPKGName "$arg") && TARGET_APPS+=($TARGET_APP)
        esac

#        # only use first matched package name abbreviation as app to install
#        [[ -z $TARGET_APP ]] && TARGET_APP=$(MatchAbbrvToQPKGName "$arg")
    done

    [[ -z $TARGET_APP && $satisfy_dependencies_only = false && $update_all_apps = false ]] && errorcode=3
    return 0

    }

Init()
    {

    SCRIPT_FILE=sherpa.sh
    local SCRIPT_VERSION=190512
    debug=false
    ResetErrorcode

    if [[ ! -e /etc/init.d/functions ]]; then
        ShowError "QTS functions missing. Is this a QNAP NAS?"
        exit 1
    fi

    # cherry-pick required binaries
    AWK_CMD=/bin/awk
    CAT_CMD=/bin/cat
    CHMOD_CMD=/bin/chmod
    DATE_CMD=/bin/date
    GREP_CMD=/bin/grep
    HOSTNAME_CMD=/bin/hostname
    LN_CMD=/bin/ln
    MD5SUM_CMD=/bin/md5sum
    MKDIR_CMD=/bin/mkdir
    PING_CMD=/bin/ping
    SED_CMD=/bin/sed
    SLEEP_CMD=/bin/sleep
    TOUCH_CMD=/bin/touch
    TR_CMD=/bin/tr
    UNAME_CMD=/bin/uname
    UNIQ_CMD=/bin/uniq

    curl_cmd=/sbin/curl         # this will change depending on QTS version
    GETCFG_CMD=/sbin/getcfg
    RMCFG_CMD=/sbin/rmcfg
    SETCFG_CMD=/sbin/setcfg

    BASENAME_CMD=/usr/bin/basename
    CUT_CMD=/usr/bin/cut
    DIRNAME_CMD=/usr/bin/dirname
    DU_CMD=/usr/bin/du
    HEAD_CMD=/usr/bin/head
    READLINK_CMD=/usr/bin/readlink
    SERVICE_CMD=/sbin/qpkg_service
    SORT_CMD=/usr/bin/sort
    TAIL_CMD=/usr/bin/tail
    TEE_CMD=/usr/bin/tee
    UNZIP_CMD=/usr/bin/unzip
    UPTIME_CMD=/usr/bin/uptime
    WC_CMD=/usr/bin/wc
    WGET_CMD=/usr/bin/wget
    WHICH_CMD=/usr/bin/which
    ZIP_CMD=/usr/local/sbin/zip

    FIND_CMD=/opt/bin/find
    OPKG_CMD=/opt/bin/opkg
    PIP_CMD=/opt/bin/pip
    PIP3_CMD=/opt/bin/pip3

    # paths and files
    APP_CENTER_CONFIG_PATHFILE=/etc/config/qpkg.conf
    INSTALL_LOG_FILE=install.log
    DOWNLOAD_LOG_FILE=download.log
    START_LOG_FILE=start.log
    STOP_LOG_FILE=stop.log
    RESTART_LOG_FILE=restart.log
    local DEFAULT_SHARES_PATHFILE=/etc/config/def_share.info
    local ULINUX_PATHFILE=/etc/config/uLinux.conf
    local ISSUE_PATHFILE=/etc/issue
    local DEBUG_LOG_FILE=${SCRIPT_FILE%.*}.debug.log

    # check required binaries are present
    IsSysFilePresent $AWK_CMD || return
    IsSysFilePresent $CAT_CMD || return
    IsSysFilePresent $CHMOD_CMD || return
    IsSysFilePresent $DATE_CMD || return
    IsSysFilePresent $GREP_CMD || return
    IsSysFilePresent $HOSTNAME_CMD || return
    IsSysFilePresent $LN_CMD || return
    IsSysFilePresent $MD5SUM_CMD || return
    IsSysFilePresent $MKDIR_CMD || return
    IsSysFilePresent $PING_CMD || return
    IsSysFilePresent $SED_CMD || return
    IsSysFilePresent $SLEEP_CMD || return
    IsSysFilePresent $TOUCH_CMD || return
    IsSysFilePresent $TR_CMD || return
    IsSysFilePresent $UNAME_CMD || return
    IsSysFilePresent $UNIQ_CMD || return

    IsSysFilePresent $curl_cmd || return
    IsSysFilePresent $GETCFG_CMD || return
    IsSysFilePresent $RMCFG_CMD || return
    IsSysFilePresent $SETCFG_CMD || return

    IsSysFilePresent $BASENAME_CMD || return
    IsSysFilePresent $CUT_CMD || return
    IsSysFilePresent $DIRNAME_CMD || return
    IsSysFilePresent $DU_CMD || return
    IsSysFilePresent $HEAD_CMD || return
    IsSysFilePresent $READLINK_CMD || return
    IsSysFilePresent $SERVICE_CMD || return
    IsSysFilePresent $SORT_CMD || return
    IsSysFilePresent $TAIL_CMD || return
    IsSysFilePresent $TEE_CMD || return
    IsSysFilePresent $UNZIP_CMD || return
    IsSysFilePresent $UPTIME_CMD || return
    IsSysFilePresent $WC_CMD || return
    IsSysFilePresent $WGET_CMD || return
    IsSysFilePresent $ZIP_CMD || return

    local DEFAULT_SHARE_DOWNLOAD_PATH=/share/Download
    local DEFAULT_SHARE_PUBLIC_PATH=/share/Public
    local DEFAULT_VOLUME=$($GETCFG_CMD SHARE_DEF defVolMP -f $DEFAULT_SHARES_PATHFILE)

    # check required system paths are present
    if [[ -L $DEFAULT_SHARE_DOWNLOAD_PATH ]]; then
        SHARE_DOWNLOAD_PATH=$DEFAULT_SHARE_DOWNLOAD_PATH
    else
        SHARE_DOWNLOAD_PATH=/share/$($GETCFG_CMD SHARE_DEF defDownload -d Qdownload -f $DEFAULT_SHARES_PATHFILE)
        IsSysSharePresent "$SHARE_DOWNLOAD_PATH" || return
    fi

    if [[ -L $DEFAULT_SHARE_PUBLIC_PATH ]]; then
        SHARE_PUBLIC_PATH=$DEFAULT_SHARE_PUBLIC_PATH
    else
        SHARE_PUBLIC_PATH=/share/$($GETCFG_CMD SHARE_DEF defPublic -d Qpublic -f $DEFAULT_SHARES_PATHFILE)
        IsSysSharePresent "$SHARE_PUBLIC_PATH" || return
    fi

    PREV_QPKG_CONFIG_DIRS=(SAB_CONFIG CONFIG Config config)     # last element is used as target dirname
    PREV_QPKG_CONFIG_FILES=(sabnzbd.ini config.ini)             # last element is used as target filename
    WORKING_PATH=$SHARE_PUBLIC_PATH/${SCRIPT_FILE%.*}.tmp
    DEBUG_LOG_PATHFILE=$SHARE_PUBLIC_PATH/$DEBUG_LOG_FILE
    SHERPA_PACKAGES_PATHFILE=$WORKING_PATH/packages.conf
    QPKG_DL_PATH=$WORKING_PATH/qpkg-downloads
    IPKG_DL_PATH=$WORKING_PATH/ipkg-downloads
    IPKG_CACHE_PATH=$WORKING_PATH/ipkg-cache
    QPKG_BACKUP_PATH=$WORKING_PATH/backup
    QPKG_CONFIG_BACKUP_PATH=$QPKG_BACKUP_PATH/${PREV_QPKG_CONFIG_DIRS[${#PREV_QPKG_CONFIG_DIRS[@]}-1]}
    QPKG_CONFIG_BACKUP_PATHFILE=$QPKG_CONFIG_BACKUP_PATH/${PREV_QPKG_CONFIG_FILES[${#PREV_QPKG_CONFIG_FILES[@]}-1]}

    # sherpa-supported package details
    SHERPA_QPKG_NAME=()         # internal QPKG name
        SHERPA_QPKG_ARCH=()     # QPKG supports this architecture ('noarch' = all)
        SHERPA_QPKG_URL=()      # remote QPKG URL available for download
        SHERPA_QPKG_MD5=()      # remote QPKG MD5
        SHERPA_QPKG_ABBRVS=()   # if set, this package is user-installable, and these abbreviations can be used to specify app
        SHERPA_QPKG_DEPS=()     # this QPKG requires these QPKGs to be installed first
        SHERPA_QPKG_IPKGS=()    # this QPKG requires these IPKGs to be installed first
        SHERPA_QPKG_PIPS=()     # this QPKG requires these PIPs to be installed first
        SHERPA_QPKG_REPLACES=() # this QPKG replaces these QPKGs if installed (although, only one must be active to be replaced). Original data is backed-up, converted, then restored into new QPKG.

    SHERPA_QPKG_NAME+=(Entware)
        SHERPA_QPKG_ARCH+=(noarch)
        SHERPA_QPKG_URL+=(http://bin.entware.net/other/Entware_1.00std.qpkg)
        SHERPA_QPKG_MD5+=(0c99cf2cf8ef61c7a18b42651a37da74)
        SHERPA_QPKG_ABBRVS+=('entware')
        SHERPA_QPKG_DEPS+=('')
        SHERPA_QPKG_IPKGS+=('')
        SHERPA_QPKG_PIPS+=('')
        SHERPA_QPKG_REPLACES+=('Entware-ng Entware-3x Optware')

    SHERPA_QPKG_NAME+=(Entware-ng)
        SHERPA_QPKG_ARCH+=(i686)
        SHERPA_QPKG_URL+=(http://entware.zyxmon.org/binaries/other/Entware-ng_0.97.qpkg)
        SHERPA_QPKG_MD5+=(6c81cc37cbadd85adfb2751dc06a238f)
        SHERPA_QPKG_ABBRVS+=('')
        SHERPA_QPKG_DEPS+=('')
        SHERPA_QPKG_IPKGS+=('')
        SHERPA_QPKG_PIPS+=('')
        SHERPA_QPKG_REPLACES+=('')

    SHERPA_QPKG_NAME+=(SABnzbdplus)
        SHERPA_QPKG_ARCH+=(noarch)
        SHERPA_QPKG_URL+=(https://onecdonly.github.io/sherpa/QPKGs/SABnzbdplus/build/SABnzbdplus_190205.qpkg)
        SHERPA_QPKG_MD5+=(b771606008cf5f7a74052a7db53c789a)
        SHERPA_QPKG_ABBRVS+=('sb sab sabnzbd sabnzbdplus')
        SHERPA_QPKG_DEPS+=('Entware Par2')
        SHERPA_QPKG_IPKGS+=('python python-pyopenssl python-dev gcc unrar p7zip coreutils-nice ionice ffprobe')
        SHERPA_QPKG_PIPS+=('sabyenc==3.3.5 cheetah')
        SHERPA_QPKG_REPLACES+=('QSabNZBdPlus')

    SHERPA_QPKG_NAME+=(SickChill)
        SHERPA_QPKG_ARCH+=(noarch)
        SHERPA_QPKG_URL+=(https://onecdonly.github.io/sherpa/QPKGs/SickChill/build/SickChill_181011.qpkg)
        SHERPA_QPKG_MD5+=(552d3c1fc5ddd832fc8f70327fbcb11f)
        SHERPA_QPKG_ABBRVS+=('sc sick sickc chill sickchill')
        SHERPA_QPKG_DEPS+=('Entware')
        SHERPA_QPKG_IPKGS+=('python')
        SHERPA_QPKG_PIPS+=('')
        SHERPA_QPKG_REPLACES+=('SickRage')

    SHERPA_QPKG_NAME+=(CouchPotato2)
        SHERPA_QPKG_ARCH+=(noarch)
        SHERPA_QPKG_URL+=(https://onecdonly.github.io/sherpa/QPKGs/CouchPotato2/build/CouchPotato2_180427.qpkg)
        SHERPA_QPKG_MD5+=(395ffdb9c25d0bc07eb24987cc722cdb)
        SHERPA_QPKG_ABBRVS+=('cp cp2 couch couchpotato couchpotato2 couchpotatoserver')
        SHERPA_QPKG_DEPS+=('Entware')
        SHERPA_QPKG_IPKGS+=('python python-pyopenssl python-lxml')
        SHERPA_QPKG_PIPS+=('')
        SHERPA_QPKG_REPLACES+=('QCouchPotato')

    SHERPA_QPKG_NAME+=(LazyLibrarian)
        SHERPA_QPKG_ARCH+=(noarch)
        SHERPA_QPKG_URL+=(https://onecdonly.github.io/sherpa/QPKGs/LazyLibrarian/build/LazyLibrarian_181112.qpkg)
        SHERPA_QPKG_MD5+=(8f3aae17aba2cbdef5d06b432d3d8015)
        SHERPA_QPKG_ABBRVS+=('ll lazy lazylibrarian')
        SHERPA_QPKG_DEPS+=('Entware')
        SHERPA_QPKG_IPKGS+=('python python-urllib3')
        SHERPA_QPKG_PIPS+=('')
        SHERPA_QPKG_REPLACES+=('')

    SHERPA_QPKG_NAME+=(OMedusa)
        SHERPA_QPKG_ARCH+=(noarch)
        SHERPA_QPKG_URL+=(https://onecdonly.github.io/sherpa/QPKGs/OMedusa/build/OMedusa_180427.qpkg)
        SHERPA_QPKG_MD5+=(ec3b193c7931a100067cfaa334caf883)
        SHERPA_QPKG_ABBRVS+=('om med omed medusa omedusa')
        SHERPA_QPKG_DEPS+=('Entware')
        SHERPA_QPKG_IPKGS+=('python python-lib2to3 mediainfo')
        SHERPA_QPKG_PIPS+=('')
        SHERPA_QPKG_REPLACES+=('')

    SHERPA_QPKG_NAME+=(OWatcher3)
        SHERPA_QPKG_ARCH+=(noarch)
        SHERPA_QPKG_URL+=(https://onecdonly.github.io/sherpa/QPKGs/OWatcher3/build/OWatcher3_190106.qpkg)
        SHERPA_QPKG_MD5+=(45145a005a8b0622790a735087c2699f)
        SHERPA_QPKG_ABBRVS+=('ow wat owat watcher owatcher watcher3 owatcher3')
        SHERPA_QPKG_DEPS+=('Entware')
        SHERPA_QPKG_IPKGS+=('python3')
        SHERPA_QPKG_PIPS+=('')
        SHERPA_QPKG_REPLACES+=('')

    SHERPA_QPKG_NAME+=(Headphones)
        SHERPA_QPKG_ARCH+=(noarch)
        SHERPA_QPKG_URL+=(https://onecdonly.github.io/sherpa/QPKGs/Headphones/build/Headphones_180429.qpkg)
        SHERPA_QPKG_MD5+=(c1b5ba10f5636b4e951eb57fb2bb1ed5)
        SHERPA_QPKG_ABBRVS+=('hp head phones headphones')
        SHERPA_QPKG_DEPS+=('Entware')
        SHERPA_QPKG_IPKGS+=('python')
        SHERPA_QPKG_PIPS+=('')
        SHERPA_QPKG_REPLACES+=('')

    SHERPA_QPKG_NAME+=(Par2)
        SHERPA_QPKG_ARCH+=(x86)
        SHERPA_QPKG_URL+=(https://onecdonly.github.io/sherpa/QPKGs/Par2/Par2_0.8.0.0_x86.qpkg)
        SHERPA_QPKG_MD5+=(c2584f84334dccd685e56419f2f07b9d)
        SHERPA_QPKG_ABBRVS+=('')
        SHERPA_QPKG_DEPS+=('')
        SHERPA_QPKG_IPKGS+=('')
        SHERPA_QPKG_PIPS+=('')
        SHERPA_QPKG_REPLACES+=('')

    SHERPA_QPKG_NAME+=(Par2)
        SHERPA_QPKG_ARCH+=(x64)
        SHERPA_QPKG_URL+=(https://onecdonly.github.io/sherpa/QPKGs/Par2/Par2_0.8.0.0_x86_64.qpkg)
        SHERPA_QPKG_MD5+=(e720a700a3364f5e81af6de40ab2e0b0)
        SHERPA_QPKG_ABBRVS+=('')
        SHERPA_QPKG_DEPS+=('')
        SHERPA_QPKG_IPKGS+=('')
        SHERPA_QPKG_PIPS+=('')
        SHERPA_QPKG_REPLACES+=('')

    SHERPA_QPKG_NAME+=(Par2)
        SHERPA_QPKG_ARCH+=(x41)
        SHERPA_QPKG_URL+=(https://onecdonly.github.io/sherpa/QPKGs/Par2/Par2_0.8.0.0_arm-x41.qpkg)
        SHERPA_QPKG_MD5+=(32281486500ba2dd55df40f00c38af53)
        SHERPA_QPKG_ABBRVS+=('')
        SHERPA_QPKG_DEPS+=('')
        SHERPA_QPKG_IPKGS+=('')
        SHERPA_QPKG_PIPS+=('')
        SHERPA_QPKG_REPLACES+=('')

    SHERPA_QPKG_NAME+=(Par2)
        SHERPA_QPKG_ARCH+=(x31)
        SHERPA_QPKG_URL+=(https://onecdonly.github.io/sherpa/QPKGs/Par2/Par2_0.8.0.0_arm-x31.qpkg)
        SHERPA_QPKG_MD5+=(d60a625e255a48f82c414fab1ea53a76)
        SHERPA_QPKG_ABBRVS+=('')
        SHERPA_QPKG_DEPS+=('')
        SHERPA_QPKG_IPKGS+=('')
        SHERPA_QPKG_PIPS+=('')
        SHERPA_QPKG_REPLACES+=('')

    SHERPA_QPKG_NAME+=(Par2)
        SHERPA_QPKG_ARCH+=(a64)
        SHERPA_QPKG_URL+=(https://onecdonly.github.io/sherpa/QPKGs/Par2/Par2_0.8.0.0_arm_64.qpkg)
        SHERPA_QPKG_MD5+=(1cb7fa5dc1b3b6f912cb0e1981aa74d2)
        SHERPA_QPKG_ABBRVS+=('')
        SHERPA_QPKG_DEPS+=('')
        SHERPA_QPKG_IPKGS+=('')
        SHERPA_QPKG_PIPS+=('')
        SHERPA_QPKG_REPLACES+=('')

    SHERPA_COMMON_IPKGS='git git-http nano less ca-certificates python-pip python3-pip'
    SHERPA_COMMON_PIPS='--upgrade pip setuptools'
    SHERPA_COMMON_CONFLICTS='Optware-NG'

    # internals
    secure_web_login=false
    package_port=0
    SCRIPT_STARTSECONDS=$($DATE_CMD +%s)
    NAS_FIRMWARE=$($GETCFG_CMD System Version -f $ULINUX_PATHFILE)
    NAS_ARCH=$($UNAME_CMD -m)
    progress_message=''
    previous_length=0
    previous_msg=''
    REINSTALL_FLAG=false
    OLD_APP=''
    satisfy_dependencies_only=false
    update_all_apps=false
    local conflicting_qpkg=''
    [[ ${NAS_FIRMWARE//.} -lt 426 ]] && curl_cmd+=' --insecure'

    local result=0

    ParseArgs

    DebugFuncEntry

    DebugInfoThickSeparator
    DebugScript 'started' "$($DATE_CMD | $TR_CMD -s ' ')"

    [[ $debug = false ]] && echo -e "$(ColourTextBrightWhite "$SCRIPT_FILE") ($SCRIPT_VERSION)\n"

    DebugScript 'version' "$SCRIPT_VERSION"
    DebugInfoThinSeparator
    DebugInfo 'Markers: (**) detected, (II) information, (WW) warning, (LL) log file,'
    DebugInfo ' (EE) error, (==) processing, (--) done, (>>) f entry, (<<) f exit,'
    DebugInfo ' (vv) variable name & value, ($1) positional argument value.'
    DebugInfoThinSeparator
    DebugNAS 'model' "$($GREP_CMD -v "^$" "$ISSUE_PATHFILE" | $SED_CMD 's|^Welcome to ||;s|(.*||')"
    DebugNAS 'firmware version' "$NAS_FIRMWARE"
    DebugNAS 'firmware build' "$($GETCFG_CMD System 'Build Number' -f $ULINUX_PATHFILE)"
    DebugNAS 'kernel' "$($UNAME_CMD -mr)"
    DebugNAS 'OS uptime' "$($UPTIME_CMD | $SED_CMD 's|.*up.||;s|,.*load.*||;s|^\ *||')"
    DebugNAS 'system load' "$($UPTIME_CMD | $SED_CMD 's|.*load average: ||' | $AWK_CMD -F', ' '{print "1 min="$1 ", 5 min="$2 ", 15 min="$3}')"
    DebugNAS 'EUID' "$EUID"
    DebugNAS 'default volume' "$DEFAULT_VOLUME"
    DebugNAS '$PATH' "${PATH:0:43}"
    DebugNAS '/opt' "$([[ -L '/opt' ]] && $READLINK_CMD '/opt' || echo "not present")"
    DebugNAS "$SHARE_DOWNLOAD_PATH" "$([[ -L $SHARE_DOWNLOAD_PATH ]] && $READLINK_CMD "$SHARE_DOWNLOAD_PATH" || echo "not present!")"
    DebugScript 'user arguments' "$USER_ARGS_RAW"
    DebugScript 'target app(s)' "${TARGET_APPS[*]}"
    DebugInfoThinSeparator

    [[ $errorcode -gt 0 ]] && DisplayHelp

    CalcNASQPKGArch
    CalcPrefEntware

    if [[ $errorcode -eq 0 && $EUID -ne 0 ]]; then
        ShowError "this script must be run as the 'admin' user. Please login via SSH as 'admin' and try again."
        errorcode=4
    fi

    if [[ $errorcode -eq 0 ]]; then
        $MKDIR_CMD -p "$WORKING_PATH" 2> /dev/null
        result=$?

        if [[ $result -ne 0 ]]; then
            ShowError "unable to create working directory ($WORKING_PATH) [$result]"
            errorcode=5
        else
            cd "$WORKING_PATH"
        fi
    fi

    if [[ $errorcode -eq 0 ]]; then
        $MKDIR_CMD -p "$QPKG_BACKUP_PATH" 2> /dev/null
        result=$?

        if [[ $result -ne 0 ]]; then
            ShowError "unable to create backup directory ($QPKG_BACKUP_PATH) [$result]"
            errorcode=6
        fi
    fi

    if [[ $errorcode -eq 0 ]]; then
        $MKDIR_CMD -p "$QPKG_DL_PATH" 2> /dev/null
        result=$?

        if [[ $result -ne 0 ]]; then
            ShowError "unable to create QPKG download directory ($QPKG_DL_PATH) [$result]"
            errorcode=7
        fi
    fi

    if [[ $errorcode -eq 0 ]]; then
        [[ -d $IPKG_DL_PATH ]] && rm -r "$IPKG_DL_PATH"
        $MKDIR_CMD -p "$IPKG_DL_PATH" 2> /dev/null
        result=$?

        if [[ $result -ne 0 ]]; then
            ShowError "unable to create IPKG download directory ($IPKG_DL_PATH) [$result]"
            errorcode=8
        else
            monitor_flag="$IPKG_DL_PATH/.monitor"
        fi
    fi

    if [[ $errorcode -eq 0 ]]; then
        $MKDIR_CMD -p "$IPKG_CACHE_PATH" 2> /dev/null
        result=$?

        if [[ $result -ne 0 ]]; then
            ShowError "unable to create IPKG cache directory ($IPKG_CACHE_PATH) [$result]"
            errorcode=9
        fi
    fi

    if [[ $errorcode -eq 0 ]]; then
        if (IsQPKGInstalled $TARGET_APP && ! IsQPKGEnabled $TARGET_APP); then
            ShowError "'$TARGET_APP' is already installed but is disabled. You'll need to enable it first to allow re-installation."
            REINSTALL_FLAG=true
            errorcode=10
        fi
    fi

    if [[ $errorcode -eq 0 ]]; then
        if [[ $TARGET_APP = SABnzbdplus ]] && IsQPKGEnabled QSabNZBdPlus && IsQPKGEnabled SABnzbdplus; then
            ShowError "both 'SABnzbdplus' and 'QSabNZBdPlus' are enabled. This is an unsupported configuration. Please disable the unused one via the QNAP App Center then re-run this installer."
            REINSTALL_FLAG=true
            errorcode=11
        fi
    fi

    if [[ $errorcode -eq 0 ]]; then
        if [[ $TARGET_APP = SickChill ]] && IsQPKGEnabled SickRage && IsQPKGEnabled SickChill; then
            ShowError "both 'SickChill' and 'SickRage' are enabled. This is an unsupported configuration. Please disable the unused one via the QNAP App Center then re-run this installer."
            REINSTALL_FLAG=true
            errorcode=12
        fi
    fi

    if [[ $errorcode -eq 0 ]]; then
        for conflicting_qpkg in ${SHERPA_COMMON_CONFLICTS[@]}; do
            if IsQPKGEnabled $conflicting_qpkg; then
                ShowError "'$conflicting_qpkg' is enabled. This is an unsupported configuration."
                errorcode=13
            fi
        done
    fi

    if [[ $errorcode -eq 0 ]]; then
        if IsQPKGEnabled Entware-ng && IsQPKGEnabled Entware-3x; then
            ShowError "both 'Entware-ng' and 'Entware-3x' are enabled. This is an unsupported configuration. Please manually disable (or uninstall) one or both of them via the QNAP App Center then re-run this installer."
            errorcode=14
        fi
    fi

    if [[ $errorcode -eq 0 ]]; then
        if IsQPKGInstalled $PREF_ENTWARE && [[ $PREF_ENTWARE = Entware-3x || $PREF_ENTWARE = Entware ]]; then
            local test_pathfile=/opt/etc/passwd
            [[ -e $test_pathfile ]] && { [[ -L $test_pathfile ]] && ENTWARE_VER=std || ENTWARE_VER=alt ;} || ENTWARE_VER=none
            DebugQPKG 'Entware installer' $ENTWARE_VER

            if [[ $ENTWARE_VER = none ]]; then
                ShowError 'Entware appears to be installed but is not visible.'
                errorcode=15
            fi
        fi
    fi

    if [[ $errorcode -eq 0 ]]; then
        ShowProc "testing Internet access"

        if ($curl_cmd --silent --fail https://onecdonly.github.io/sherpa/packages.conf -o $SHERPA_PACKAGES_PATHFILE); then
            ShowDone "Internet is accessible"
        else
            ShowError "no Internet access"
            errorcode=16
        fi
    fi

    DebugFuncExit
    return 0

    }

DisplayHelp()
    {

    DebugFuncEntry
    local package=''

    echo -e "* A BASH script to install various Usenet apps into a QNAP NAS.\n"

    echo "- Each application shown below can be installed (or reinstalled) by running:"
    for package in ${SHERPA_QPKG_NAME[@]}; do
        (IsQPKGUserInstallable $package) && echo -e "\t$0 $package"
    done

    echo -e "\n- To ensure all sherpa application dependencies are installed:"
    echo -e "\t$0 --check"

    echo -e "\n- To update all sherpa installed applications:"
    echo -e "\t$0 --update"

    DebugFuncExit
    return 0

    }

DownloadQPKGs()
    {

    [[ $errorcode -gt 0 ]] && return

    DebugFuncEntry
    local returncode=0

    ! IsQPKGInstalled $PREF_ENTWARE && DownloadQPKG $PREF_ENTWARE

    { (IsQPKGInstalled SABnzbdplus) || [[ $TARGET_APP = SABnzbdplus ]] ;} && [[ $NAS_QPKG_ARCH != none ]] && ! IsQPKGInstalled Par2 && DownloadQPKG Par2

    [[ -n $TARGET_APP ]] && DownloadQPKG $TARGET_APP

    DebugFuncExit
    return $returncode

    }

RemoveUnwantedQPKGs()
    {

    [[ $errorcode -gt 0 ]] && return

    DebugFuncEntry

    UninstallQPKG Optware || ResetErrorcode  # ignore Optware uninstall errors

    [[ $TARGET_APP = $PREF_ENTWARE ]] && { REINSTALL_FLAG=true; UninstallQPKG $PREF_ENTWARE; CalcPrefEntware ;}

    DebugFuncExit
    return 0

    }

InstallBase()
    {

    [[ $errorcode -gt 0 ]] && return

    DebugFuncEntry
    local returncode=0

    if ! IsQPKGInstalled $PREF_ENTWARE; then
        # rename original [/opt]
        opt_path=/opt
        opt_backup_path=/opt.orig
        [[ -d $opt_path && ! -L $opt_path && ! -e $opt_backup_path ]] && mv "$opt_path" "$opt_backup_path"

        InstallQPKG $PREF_ENTWARE && ReloadProfile

        # copy all files from original [/opt] into new [/opt]
        [[ -L $opt_path && -d $opt_backup_path ]] && cp --recursive "$opt_backup_path"/* --target-directory "$opt_path" && rm -r "$opt_backup_path"
    else
        ! IsQPKGEnabled $PREF_ENTWARE && EnableQPKG $PREF_ENTWARE
        ReloadProfile

        [[ $NAS_QPKG_ARCH != none ]] && ($OPKG_CMD list-installed | $GREP_CMD -q par2cmdline) && $OPKG_CMD remove par2cmdline > /dev/null 2>&1
    fi

    PatchBaseInit

    DebugFuncExit
    return $returncode

    }

PatchBaseInit()
    {

    DebugFuncEntry
    local find_text=''
    local insert_text=''
    local package_init_pathfile="$(GetQPKGServiceFile $PREF_ENTWARE)"

    if ($GREP_CMD -q 'opt.orig' "$package_init_pathfile"); then
        DebugInfo 'patch: do the "opt shuffle" - already done'
    else
        find_text='/bin/rm -rf /opt'
        insert_text='opt_path="/opt"; opt_backup_path="/opt.orig"; [ -d "$opt_path" ] \&\& [ ! -L "$opt_path" ] \&\& [ ! -e "$opt_backup_path" ] \&\& mv "$opt_path" "$opt_backup_path"'
        $SED_CMD -i "s|$find_text|$insert_text\n$find_text|" "$package_init_pathfile"

        find_text='/bin/ln -sf $QPKG_DIR /opt'
        insert_text=$(echo -e "\t")'[ -L "$opt_path" ] \&\& [ -d "$opt_backup_path" ] \&\& cp "$opt_backup_path"/* --target-directory "$opt_path" \&\& rm -r "$opt_backup_path"'
        $SED_CMD -i "s|$find_text|$find_text\n$insert_text\n|" "$package_init_pathfile"

        DebugDone 'patch: do the "opt shuffle"'
    fi

    DebugFuncExit
    return 0

    }

UpdateEntware()
    {

    DebugFuncEntry
    local package_list_file=/opt/var/opkg-lists/entware
    local package_list_age=60
    local release_file=/opt/etc/entware_release
    local result=0
    local upgrade_result=0
    local log_pathfile="$WORKING_PATH/entware-update.log"

    IsSysFilePresent $OPKG_CMD || return
    IsSysFilePresent $FIND_CMD || return

    # if Entware package list was updated only recently, don't run another update
    [[ -e $FIND_CMD && -e $package_list_file ]] && result=$($FIND_CMD "$package_list_file" -mmin +$package_list_age) || result='new install'

    if [[ -n $result ]]; then
        ShowProc 'updating Entware package list'

        install_msgs=$($OPKG_CMD update 2>&1)
        result=$?
        echo -e "${install_msgs}\nresult=[$result]" >> "$log_pathfile"

        if [[ $PREF_ENTWARE = Entware-3x && ! -e $release_file ]]; then
            DebugProc 'performing Entware-3x upgrade x 2'
            install_msgs=$($OPKG_CMD upgrade; $OPKG_CMD update; $OPKG_CMD upgrade)
            upgrade_result=$?
            echo -e "${install_msgs}\nresult=[$upgrade_result]" >> "$log_pathfile"
        fi

        if [[ $result -eq 0 ]]; then
            ShowDone 'updated Entware package list'
        else
            ShowWarning "Unable to update Entware package list [$result]"
            DebugErrorFile "$log_pathfile"
            # meh, continue anyway with old list ...
        fi
    else
        DebugInfo "Entware package list was updated less than $package_list_age minutes ago"
        ShowDone 'Entware package list is up-to-date'
    fi

    DebugFuncExit
    return 0

    }

InstallBaseAddons()
    {

    [[ $errorcode -gt 0 ]] && return

    DebugFuncEntry

    if { (IsQPKGInstalled SABnzbdplus) || [[ $TARGET_APP = SABnzbdplus ]] ;} && [[ $NAS_QPKG_ARCH != none ]]; then
        InstallQPKG Par2
        if [[ $errorcode -gt 0 ]]; then
            ShowWarning "Par2 installation failed - but it's not essential so I'm continuing"
            ResetErrorcode
            DebugVar errorcode
        fi
    fi

    InstallIPKGs
    InstallPIPs

    [[ $TARGET_APP = $PREF_ENTWARE || $update_all_apps = true ]] && RestartAllQPKGs

    DebugFuncExit
    return 0

    }

BackupAndRemoveOldQPKG()
    {

    [[ $errorcode -gt 0 || $satisfy_dependencies_only = true ]] && return

    DebugFuncEntry
    local returncode=0

    if [[ -n $TARGET_APP ]]; then
        case $TARGET_APP in
            SABnzbdplus)
                if (IsQPKGEnabled QSabNZBdPlus); then
                    BackupConfig && UninstallQPKG QSabNZBdPlus
                else
                    IsQPKGEnabled $TARGET_APP && BackupConfig && UninstallQPKG $TARGET_APP
                fi
                ;;
            SickChill)
                if (IsQPKGEnabled SickRage); then
                    BackupConfig && UninstallQPKG SickRage
                elif (IsQPKGEnabled QSickRage); then
                    BackupConfig && $SERVICE_CMD stop QSickRage && $SERVICE_CMD disable QSickRage
                else
                    IsQPKGEnabled $TARGET_APP && BackupConfig && UninstallQPKG $TARGET_APP
                fi
                ;;
            CouchPotato2|LazyLibrarian|OMedusa|OWatcher3|Headphones)
                IsQPKGEnabled $TARGET_APP && BackupConfig && UninstallQPKG $TARGET_APP
                ;;
            Entware)
                # don't backup and restore
                ;;
            *)
                ShowError "can't backup and remove app '$TARGET_APP' as it's unknown"
                returncode=1
                ;;
        esac
    fi

    DebugFuncExit
    return $returncode

    }

InstallTargetQPKG()
    {

    [[ $errorcode -gt 0 || -z $TARGET_APP ]] && return

    DebugFuncEntry

    if [[ $TARGET_APP != $PREF_ENTWARE ]]; then
        ! IsQPKGInstalled $TARGET_APP && InstallQPKG $TARGET_APP && PauseHere && RestoreConfig
        [[ $errorcode -eq 0 ]] && QPKGServiceCtl start $TARGET_APP
    fi

    DebugFuncExit
    return 0

    }

InstallIPKGs()
    {

    [[ $errorcode -gt 0 ]] && return

    DebugFuncEntry
    local returncode=0
    local install_msgs=''
    local packages="$SHERPA_COMMON_IPKGS"
    local index=0

    if [[ -n $IPKG_DL_PATH && -d $IPKG_DL_PATH ]]; then
        UpdateEntware
        for index in ${!SHERPA_QPKG_NAME[@]}; do
            if (IsQPKGInstalled ${SHERPA_QPKG_NAME[$index]}) || [[ $TARGET_APP = ${SHERPA_QPKG_NAME[$index]} ]]; then
                packages+=" ${SHERPA_QPKG_IPKGS[$index]}"
            fi
        done

        if (IsQPKGInstalled SABnzbdplus) || [[ $TARGET_APP = SABnzbdplus ]]; then
            [[ $NAS_QPKG_ARCH = none ]] && packages+=' par2cmdline'
        fi

        InstallIPKGBatch "$packages"
    else
        ShowError "IPKG download path [$IPKG_DL_PATH] does not exist"
        errorcode=17
        returncode=1
    fi

    DebugFuncExit
    return $returncode

    }

InstallIPKGBatch()
    {

    # $1 = space-separated string containing list of IPKG names to download and install

    DebugFuncEntry
    local result=0
    local returncode=0
    local requested_IPKGs=''
    local log_pathfile="$IPKG_DL_PATH/IPKGs.$INSTALL_LOG_FILE"

    [[ -n $1 ]] && requested_IPKGs="$1" || return 1

    # errors can occur due to incompatible IPKGs (tried installing Entware-3x, then Entware-ng), so delete them first
    [[ -d $IPKG_DL_PATH ]] && rm -f "$IPKG_DL_PATH"/*.ipk
    [[ -d $IPKG_CACHE_PATH ]] && rm -f "$IPKG_CACHE_PATH"/*.ipk

    FindAllIPKGDependencies "$requested_IPKGs"

    if [[ $IPKG_download_count -gt 0 ]]; then
        local IPKG_download_startseconds=$(DebugStageStart)
        ShowProc "downloading & installing $IPKG_download_count IPKGs"

        $TOUCH_CMD "$monitor_flag"
        trap CTRL_C_Captured INT
        _MonitorDirSize_ "$IPKG_DL_PATH" $IPKG_download_size &

        install_msgs=$($OPKG_CMD install --force-overwrite ${IPKG_download_list[*]} --cache "$IPKG_CACHE_PATH" --tmp-dir "$IPKG_DL_PATH" 2>&1)
        result=$?

        [[ -e $monitor_flag ]] && { rm "$monitor_flag"; $SLEEP_CMD 2 ;}
        trap - INT
        echo -e "${install_msgs}\nresult=[$result]" > "$log_pathfile"

        if [[ $result -eq 0 ]]; then
            ShowDone "downloaded & installed $IPKG_download_count IPKGs"
        else
            ShowError "download & install IPKGs failed [$result]"
            DebugErrorFile "$log_pathfile"

            errorcode=18
            returncode=1
        fi
        DebugStageEnd $IPKG_download_startseconds
    fi

    DebugFuncExit
    return $returncode

    }

InstallPIPs()
    {

    [[ $errorcode -gt 0 ]] && return

    DebugFuncEntry
    local install_cmd=''
    local install_msgs=''
    local result=0
    local returncode=0
    local packages=''
    local log_pathfile="$WORKING_PATH/PIP-modules.$INSTALL_LOG_FILE"

    IsSysFilePresent $PIP_CMD || return 1

    for index in ${!SHERPA_QPKG_NAME[@]}; do
        if (IsQPKGInstalled ${SHERPA_QPKG_NAME[$index]}) || [[ $TARGET_APP = ${SHERPA_QPKG_NAME[$index]} ]]; then
            packages+=" ${SHERPA_QPKG_PIPS[$index]}"
        fi
    done

    ShowProc "downloading & installing PIP modules"

    install_cmd="$PIP_CMD install $SHERPA_COMMON_PIPS 2>&1"
    [[ -n ${packages// /} ]] && install_cmd+=" && $PIP_CMD install $packages 2>&1"

    install_msgs=$(eval "$install_cmd")
    result=$?
    echo -e "${install_msgs}\nresult=[$result]" > "$log_pathfile"

    if [[ $result -eq 0 ]]; then
        ShowDone "downloaded & installed PIP modules"
    else
        ShowError "download & install PIP modules failed [$result]"
        DebugErrorFile "$log_pathfile"

        errorcode=19
        returncode=1
    fi

    DebugFuncExit
    return $returncode

    }

RestartAllQPKGs()
    {

    [[ $errorcode -gt 0 ]] && return

    DebugFuncEntry
    local index=0
    local dependant_on=''

    for index in ${!SHERPA_QPKG_NAME[@]}; do
        if (IsQPKGUserInstallable ${SHERPA_QPKG_NAME[$index]}) && (IsQPKGEnabled ${SHERPA_QPKG_NAME[$index]}); then
            if [[ $update_all_apps = true ]]; then
                QPKGServiceCtl restart ${SHERPA_QPKG_NAME[$index]}
            else
                for dependant_on in ${SHERPA_QPKG_DEPS[$index]}; do
                    if [[ $dependant_on = $TARGET_APP ]]; then
                        QPKGServiceCtl restart ${SHERPA_QPKG_NAME[$index]}
                        break
                    fi
                done
            fi
        fi
    done

    DebugFuncExit
    return 0

    }

InstallNG()
    {

    [[ $errorcode -gt 0 ]] && return

    DebugFuncEntry

    if ! IsIPKGInstalled nzbget; then
        local install_msgs=''
        local result=0
        local packages=''
        local package_desc=''
        local returncode=0

        InstallIPKGBatch 'nzbget'

        if [[ $? -eq 0 ]]; then
            ShowProc "modifying NZBGet"

            $SED_CMD -i 's|ConfigTemplate=.*|ConfigTemplate=/opt/share/nzbget/nzbget.conf.template|g' /opt/share/nzbget/nzbget.conf
            ShowDone "modified NZBGet"
            /opt/etc/init.d/S75nzbget start
            $CAT_CMD /opt/share/nzbget/nzbget.conf | $GREP_CMD ControlPassword=
            #Go to default router ip address and port 6789 192.168.1.1:6789 and now you should see NZBget interface
        else
            ShowError "download & install IPKG failed ($package_desc) [$result]"
            errorcode=20
            returncode=1
        fi
    fi

    DebugFuncExit
    return 0

    }

InstallQPKG()
    {

    # $1 = QPKG name to install

    [[ $errorcode -gt 0 || -z $1 ]] && return

    local target_file=''
    local install_msgs=''
    local result=0
    local returncode=0
    local local_pathfile="$(GetQPKGPathFilename $1)"

    if IsQPKGInstalled $1; then
        DebugInfo "QPKG '$1' is already installed"
        if IsQPKGEnabled $1; then
            DebugInfo "QPKG '$1' is already enabled"
        else
            EnableQPKG $1
        fi
        return 0
    fi

    if [[ ${local_pathfile##*.} = zip ]]; then
        $UNZIP_CMD -nq "$local_pathfile" -d "$QPKG_DL_PATH"
        local_pathfile="${local_pathfile%.*}"
    fi

    local log_pathfile="$local_pathfile.$INSTALL_LOG_FILE"
    target_file=$($BASENAME_CMD "$local_pathfile")
    ShowProc "installing file ($target_file) - this can take a while"
    install_msgs=$(eval sh "$local_pathfile" 2>&1)
    result=$?

    echo -e "${install_msgs}\nresult=[$result]" > "$log_pathfile"

    if [[ $result -eq 0 || $result -eq 10 ]]; then
        ShowDone "installed file ($target_file)"
    else
        ShowError "file installation failed ($target_file) [$result]"
        DebugErrorFile "$log_pathfile"

        errorcode=21
        returncode=1
    fi

    return $returncode

    }

BackupConfig()
    {

    [[ $errorcode -gt 0 || $satisfy_dependencies_only = true ]] && return

    DebugFuncEntry
    local returncode=0

    case $TARGET_APP in
        SABnzbdplus)
            if IsQPKGEnabled QSabNZBdPlus; then
                OLD_APP=QSabNZBdPlus
                QPKGServiceCtl stop $OLD_APP
                LoadInstalledQPKGVars $OLD_APP
            elif IsQPKGEnabled $TARGET_APP; then
                QPKGServiceCtl stop $TARGET_APP
                LoadInstalledQPKGVars $TARGET_APP
            fi

            REINSTALL_FLAG=$package_is_enabled
            [[ $package_is_enabled = true ]] && BackupThisPackage
            ;;
        SickChill)
            if IsQPKGEnabled QSickRage; then
                OLD_APP=QSickRage
                QPKGServiceCtl stop $OLD_APP
                LoadInstalledQPKGVars $OLD_APP
            elif IsQPKGEnabled SickRage; then
                OLD_APP=SickRage
                QPKGServiceCtl stop $OLD_APP
                LoadInstalledQPKGVars $OLD_APP
            elif IsQPKGEnabled $TARGET_APP; then
                QPKGServiceCtl stop $TARGET_APP
                LoadInstalledQPKGVars $TARGET_APP
            fi

            REINSTALL_FLAG=$package_is_enabled
            [[ $package_is_enabled = true ]] && BackupThisPackage
            ;;
        CouchPotato2)
            if IsQPKGEnabled QCouchPotato; then
                OLD_APP=QCouchPotato
                QPKGServiceCtl stop $OLD_APP
                LoadInstalledQPKGVars $OLD_APP
            elif IsQPKGEnabled $TARGET_APP; then
                QPKGServiceCtl stop $TARGET_APP
                LoadInstalledQPKGVars $TARGET_APP
            fi

            REINSTALL_FLAG=$package_is_enabled
            [[ $package_is_enabled = true ]] && BackupThisPackage
            ;;
        LazyLibrarian|OMedusa|OWatcher3|Headphones)
            if IsQPKGEnabled $TARGET_APP; then
                QPKGServiceCtl stop $TARGET_APP
                LoadInstalledQPKGVars $TARGET_APP
            fi

            REINSTALL_FLAG=$package_is_enabled
            [[ $package_is_enabled = true ]] && BackupThisPackage
            ;;
        *)
            ShowError "can't backup app '$TARGET_APP' as it's unknown"
            returncode=1
            ;;
    esac

    DebugFuncExit
    return $returncode

    }

BackupThisPackage()
    {

    local result=0

    DebugVar package_config_path
#     local package_config_backup_pathfile="$QPKG_BACKUP_PATH/sherpa.config.backup.zip"
#     DebugVar package_config_backup_pathfile

    if [[ -d $package_config_path ]]; then
        if [[ ! -d $QPKG_CONFIG_BACKUP_PATH ]]; then
            DebugVar QPKG_BACKUP_PATH
            mv "$package_config_path" "$QPKG_BACKUP_PATH"
            result=$?
            DebugInfo "moved old config to backup location"

#             [[ -e $package_config_backup_pathfile ]] && rm "$package_config_backup_pathfile"

#             $ZIP_CMD -q "$package_config_backup_pathfile" "$QPKG_CONFIG_BACKUP_PATH"
#             zipresult=$?
#
#             if [[ $result -eq 0 && $zipresult -eq 0 ]]; then
            ShowDone "created settings backup '$TARGET_APP'"
#             else
#                 ShowError "could not create settings backup of ($package_config_path) [$result]"
#                 errorcode=22
#                 return 1
#             fi
        else
            DebugInfo "a backup set already exists [$QPKG_CONFIG_BACKUP_PATH]"
            errorcode=23
        fi

        ConvertSettings
    else
        ShowError "could not find installed QPKG configuration path [$package_config_path]. Can't safely continue with backup. Aborting."
        errorcode=24
    fi

    }

ConvertSettings()
    {

    DebugFuncEntry
    local returncode=0
    local prev_config_dir=''
    local prev_config_file=''
    local test_path=''
    local test_pathfile=''

    case $TARGET_APP in
        SABnzbdplus)
            for prev_config_dir in ${PREV_QPKG_CONFIG_DIRS[@]}; do
                test_path=$QPKG_BACKUP_PATH/$prev_config_dir
                if [[ -d $test_path && ! -d $QPKG_CONFIG_BACKUP_PATH ]]; then
                    mv $test_path $QPKG_CONFIG_BACKUP_PATH
                    DebugDone "renamed config path from [$test_path] to [$QPKG_CONFIG_BACKUP_PATH]"
                    break
                fi
            done

            for prev_config_file in ${PREV_QPKG_CONFIG_FILES[@]}; do
                test_pathfile=$QPKG_CONFIG_BACKUP_PATH/$prev_config_file
                if [[ -f $test_pathfile && $test_pathfile != $QPKG_CONFIG_BACKUP_PATHFILE ]]; then
                    mv $test_pathfile $QPKG_CONFIG_BACKUP_PATHFILE
                    DebugDone "renamed config file from [$test_pathfile] to [$QPKG_CONFIG_BACKUP_PATHFILE]"
                fi
            done

            if [[ -f $QPKG_CONFIG_BACKUP_PATHFILE ]]; then
                $SED_CMD -i "s|log_dir = logs|log_dir = ${SHARE_DOWNLOAD_PATH}/sabnzbd/logs|" "$QPKG_CONFIG_BACKUP_PATHFILE"
                $SED_CMD -i "s|download_dir = Downloads/incomplete|download_dir = $SHARE_DOWNLOAD_PATH/incomplete|" "$QPKG_CONFIG_BACKUP_PATHFILE"
                $SED_CMD -i "s|complete_dir = Downloads/complete|complete_dir = $SHARE_DOWNLOAD_PATH/complete|" "$QPKG_CONFIG_BACKUP_PATHFILE"

                if ($GREP_CMD -q '^enable_https = 1' "$QPKG_CONFIG_BACKUP_PATHFILE"); then
                    package_port=$($GREP_CMD '^https_port = ' "$QPKG_CONFIG_BACKUP_PATHFILE" | $HEAD_CMD -n1 | $CUT_CMD -f3 -d' ')
                    secure_web_login=true
                else
                    package_port=$($GREP_CMD '^port = ' "$QPKG_CONFIG_BACKUP_PATHFILE" | $HEAD_CMD -n1 | $CUT_CMD -f3 -d' ')
                fi
            fi
            ;;
        SickChill)
            [[ -f $QPKG_CONFIG_BACKUP_PATHFILE ]] && $SETCFG_CMD General git_remote_url 'http://github.com/sickchill/sickchill.git' -f "$QPKG_CONFIG_BACKUP_PATHFILE"
            ;;
        LazyLibrarian|OMedusa|OWatcher3|Headphones)
            # do nothing - don't need to convert from older versions for these QPKGs as sherpa is the only installer for them.
            ;;
        CouchPotato2)
            DebugWarning "can't convert settings for '$TARGET_APP' yet!"
            ;;
        *)
            ShowError "can't convert settings for '$TARGET_APP' as it's unknown"
            returncode=1
            ;;
    esac

    DebugFuncExit
    return $returncode

    }

ReloadProfile()
    {

    IsQPKGInstalled $PREF_ENTWARE && PATH="/opt/bin:/opt/sbin:$PATH"

    DebugDone 'adjusted $PATH'
    DebugVar PATH

    return 0

    }

RestoreConfig()
    {

    [[ $errorcode -gt 0 || $satisfy_dependencies_only = true ]] && return

    DebugFuncEntry
    local result=0
    local returncode=0

    if [[ -n $TARGET_APP ]]; then
        if IsQPKGInstalled $TARGET_APP; then
            LoadInstalledQPKGVars $TARGET_APP

            if [[ -d $QPKG_CONFIG_BACKUP_PATH ]]; then
                QPKGServiceCtl stop $TARGET_APP

                if [[ ! -d $package_config_path ]]; then
                    $MKDIR_CMD -p "$($DIRNAME_CMD "$package_config_path")" 2> /dev/null
                else
                    rm -r "$package_config_path" 2> /dev/null
                fi

                mv "$QPKG_CONFIG_BACKUP_PATH" "$($DIRNAME_CMD "$package_config_path")"
                result=$?

                if [[ $result -eq 0 ]]; then
                    ShowDone "restored settings backup '$TARGET_APP'"

                    [[ -n $package_port ]] && $SETCFG_CMD "$TARGET_APP" Web_Port $package_port -f "$APP_CENTER_CONFIG_PATHFILE"
                else
                    ShowError "could not restore settings backup to ($package_config_path) [$result]"
                    errorcode=25
                    returncode=1
                fi
            fi
        else
            ShowError "'$TARGET_APP' is NOT installed so can't restore backup"
            errorcode=26
            returncode=1
        fi
    fi

    DebugFuncExit
    return $returncode

    }

DownloadQPKG()
    {

    # $1 = QPKG name to download

    [[ $errorcode -gt 0 || -z $1 ]] && return

    DebugFuncEntry
    local result=0
    local returncode=0
    local remote_url=$(GetQPKGRemoteURL $1)
    local remote_filename="$($BASENAME_CMD "$remote_url")"
    local remote_filename_md5="$(GetQPKGMD5 $1)"
    local local_pathfile="$QPKG_DL_PATH/$remote_filename"
    local local_filename="$($BASENAME_CMD "$local_pathfile")"
    local log_pathfile="$local_pathfile.$DOWNLOAD_LOG_FILE"

    if [[ -e $local_pathfile ]]; then
        if [[ $($MD5SUM_CMD "$local_pathfile" | $CUT_CMD -f1 -d' ') = $remote_filename_md5 ]]; then
            DebugInfo "existing QPKG checksum correct ($local_filename)"
        else
            DebugWarning "existing QPKG checksum incorrect ($local_filename)"
            DebugInfo "deleting file ($local_filename)"
            rm -f "$local_pathfile"
        fi
    fi

    if [[ $errorcode -eq 0 && ! -e $local_pathfile ]]; then
        ShowProc "downloading file ($remote_filename)"

        [[ -e $log_pathfile ]] && rm -f "$log_pathfile"

        # keep this one handy for SOCKS5
        # curl http://entware-3x.zyxmon.org/binaries/other/Entware-3x_1.00std.qpkg --socks5 IP:PORT --output target.qpkg

        if [[ $debug = true ]]; then
            $curl_cmd --output "$local_pathfile" "$remote_url" 2>&1 | $TEE_CMD -a "$log_pathfile"
            result=$?
        else
            $curl_cmd --output "$local_pathfile" "$remote_url" >> "$log_pathfile" 2>&1
            result=$?
        fi

        echo -e "\nresult=[$result]" >> "$log_pathfile"

        if [[ $result -eq 0 ]]; then
            if [[ $($MD5SUM_CMD "$local_pathfile" | $CUT_CMD -f1 -d' ') = $remote_filename_md5 ]]; then
                ShowDone "downloaded file ($remote_filename)"
            else
                ShowError "downloaded file checksum incorrect ($remote_filename)"
                errorcode=27
                returncode=1
            fi
        else
            ShowError "download failed ($local_pathfile) [$result]"
            DebugErrorFile "$log_pathfile"

            errorcode=28
            returncode=1
        fi
    fi

    DebugFuncExit
    return $returncode

    }

CalcNASQPKGArch()
    {

    # decide which package arch is suitable for this NAS. This is really only needed for Stephane's packages.

    case "$NAS_ARCH" in
        x86_64)
            [[ ${NAS_FIRMWARE//.} -ge 430 ]] && NAS_QPKG_ARCH=x64 || NAS_QPKG_ARCH=x86
            ;;
        i686|x86)
            NAS_QPKG_ARCH=x86
            ;;
        armv7h)
            NAS_QPKG_ARCH=x41
            ;;
        armv7l)
            NAS_QPKG_ARCH=x31
            ;;
        aarch64)
            NAS_QPKG_ARCH=a64
            ;;
        *)
            NAS_QPKG_ARCH=none
            ;;
    esac

    DebugVar NAS_QPKG_ARCH
    return 0

    }

CalcPrefEntware()
    {

    # decide which Entware is suitable for this NAS

    # start with the default preferred variant
    PREF_ENTWARE=Entware

    # then modify according to local environment
    [[ $NAS_ARCH = i686 ]] && PREF_ENTWARE=Entware-ng
    IsQPKGInstalled Entware-ng && PREF_ENTWARE=Entware-ng
    IsQPKGInstalled Entware-3x && PREF_ENTWARE=Entware-3x

    DebugVar PREF_ENTWARE
    return 0

    }

LoadInstalledQPKGVars()
    {

    # $1 = load variables for this installed package name

    local package_name=$1
    local returncode=0
    local prev_config_dir=''
    local prev_config_file=''
    local package_settings_pathfile=''
    package_installed_path=''
    package_config_path=''
    package_port=''
    package_api=''
    package_version=''

    if [[ -n $package_name ]]; then
        package_installed_path=$($GETCFG_CMD $package_name Install_Path -f $APP_CENTER_CONFIG_PATHFILE)
        if [[ $? -eq 0 ]]; then
            for prev_config_dir in ${PREV_QPKG_CONFIG_DIRS[@]}; do
                package_config_path=$package_installed_path/$prev_config_dir
                [[ -d $package_config_path ]] && break
            done

            for prev_config_file in ${PREV_QPKG_CONFIG_FILES[@]}; do
                package_settings_pathfile=$package_config_path/$prev_config_file
                [[ -f $package_settings_pathfile ]] && break
            done

            if [[ -e $QPKG_CONFIG_BACKUP_PATHFILE ]]; then
                if [[ $($GETCFG_CMD misc enable_https -d 0 -f $QPKG_CONFIG_BACKUP_PATHFILE) -eq 1 ]]; then
                    package_port=$($GETCFG_CMD misc https_port -f $QPKG_CONFIG_BACKUP_PATHFILE)
                    secure_web_login=true
                else
                    package_port=$($GETCFG_CMD misc port -f $QPKG_CONFIG_BACKUP_PATHFILE)
                fi
            else
                package_port=$($GETCFG_CMD $package_name Web_Port -f $APP_CENTER_CONFIG_PATHFILE)
            fi

            [[ -e $package_settings_pathfile ]] && package_api=$($GETCFG_CMD api_key -f $package_settings_pathfile)
            package_version=$($GETCFG_CMD $package_name Version -f $APP_CENTER_CONFIG_PATHFILE)
        else
            DebugError 'QPKG not installed?'
            errorcode=29
            returncode=1
        fi
    else
        DebugError 'QPKG name unspecified'
        errorcode=30
        returncode=1
    fi

    return $returncode

    }

UninstallQPKG()
    {

    # $1 = QPKG name

    [[ $errorcode -gt 0 ]] && return

    local result=0
    local returncode=0

    if [[ -z $1 ]]; then
        DebugError 'QPKG name unspecified'
        errorcode=31
        returncode=1
    else
        qpkg_installed_path="$($GETCFG_CMD "$1" Install_Path -f "$APP_CENTER_CONFIG_PATHFILE")"
        result=$?

        if [[ $result -eq 0 ]]; then
            if [[ -e $qpkg_installed_path/.uninstall.sh ]]; then
                ShowProc "uninstalling '$1'"

                $qpkg_installed_path/.uninstall.sh > /dev/null
                result=$?

                if [[ $result -eq 0 ]]; then
                    ShowDone "uninstalled '$1'"
                else
                    ShowError "unable to uninstall '$1' [$result]"
                    errorcode=32
                    returncode=1
                fi
            fi

            $RMCFG_CMD "$1" -f "$APP_CENTER_CONFIG_PATHFILE"
        else
            DebugQPKG "'$1'" "not installed [$result]"
        fi
    fi

    return $returncode

    }

QPKGServiceCtl()
    {

    # $1 = action (start|stop|restart)
    # $2 = QPKG name

    # this function is used in-place of [qpkg_service] as the QTS 4.2.6 version does not offer returncodes

    local msgs=''
    local result=0
    local init_pathfile=''

    if [[ -z $1 ]]; then
        DebugError 'action unspecified'
        errorcode=33
        return 1
    elif [[ -z $2 ]]; then
        DebugError 'package unspecified'
        errorcode=34
        return 1
    fi

    init_pathfile=$(GetQPKGServiceFile $2)
    init_file=$($BASENAME_CMD "$init_pathfile")

    case $1 in
        start)
            ShowProc "starting service '$2' - this can take a while"
            msgs=$("$init_pathfile" start)
            result=$?
            echo -e "${msgs}\nresult=[$result]" >> "$qpkg_pathfile.$START_LOG_FILE"

            if [[ $result -eq 0 ]]; then
                ShowDone "started service '$2'"
            else
                ShowWarning "Could not start service '$2' [$result]"
                if [[ $debug = true ]]; then
                    DebugInfoThickSeparator
                    $CAT_CMD "$qpkg_pathfile.$START_LOG_FILE"
                    DebugInfoThickSeparator
                else
                    $CAT_CMD "$qpkg_pathfile.$START_LOG_FILE" >> "$DEBUG_LOG_PATHFILE"
                fi
                errorcode=35
                return 1
            fi
            ;;
        stop)
            ShowProc "stopping service '$2'"
            msgs=$("$init_pathfile" stop)
            result=$?
            echo -e "${msgs}\nresult=[$result]" >> "$qpkg_pathfile.$STOP_LOG_FILE"

            if [[ $result -eq 0 ]]; then
                ShowDone "stopped service '$2'"
            else
                ShowWarning "Could not stop service '$2' [$result]"
                if [[ $debug = true ]]; then
                    DebugInfoThickSeparator
                    $CAT_CMD "$qpkg_pathfile.$STOP_LOG_FILE"
                    DebugInfoThickSeparator
                else
                    $CAT_CMD "$qpkg_pathfile.$STOP_LOG_FILE" >> "$DEBUG_LOG_PATHFILE"
                fi
                # meh, continue anyway...
                return 1
            fi
            ;;
        restart)
            ShowProc "restarting service '$2'"
            msgs=$("$init_pathfile" restart)
            result=$?
            echo -e "${msgs}\nresult=[$result]" >> "$qpkg_pathfile.$RESTART_LOG_FILE"

            if [[ $result -eq 0 ]]; then
                ShowDone "restarted service '$2'"
            else
                ShowWarning "Could not restart service '$2' [$result]"
                if [[ $debug = true ]]; then
                    DebugInfoThickSeparator
                    $CAT_CMD "$qpkg_pathfile.$RESTART_LOG_FILE"
                    DebugInfoThickSeparator
                else
                    $CAT_CMD "$qpkg_pathfile.$RESTART_LOG_FILE" >> "$DEBUG_LOG_PATHFILE"
                fi
                # meh, continue anyway...
                return 1
            fi
            ;;
        *)
            DebugError "Unrecognised action ($1)"
            errorcode=36
            return 1
            ;;
    esac

    return 0

    }

GetQPKGServiceFile()
    {

    # $1 = QPKG name
    # stdout = QPKG init pathfilename
    # $? = 0 if successful, 1 if failed

    local output=''
    local returncode=0

    if [[ -z $1 ]]; then
        DebugError 'Package unspecified'
        errorcode=37
        returncode=1
    else
        output=$($GETCFG_CMD $1 Shell -f $APP_CENTER_CONFIG_PATHFILE)

        if [[ -z $output ]]; then
            DebugError "No service file configured for package ($1)"
            errorcode=38
            returncode=1
        elif [[ ! -e $output ]]; then
            DebugError "Package service file not found ($output)"
            errorcode=39
            returncode=1
        fi
    fi

    echo "$output"
    return $returncode

    }

GetQPKGPathFilename()
    {

    # $1 = QPKG name
    # stdout = QPKG local filename
    # $? = 0 if successful, 1 if failed

    local output=''
    local returncode=0

    if [[ -z $1 ]]; then
        DebugError 'Package unspecified'
        errorcode=40
        returncode=1
    else
        output="$QPKG_DL_PATH/$($BASENAME_CMD "$(GetQPKGRemoteURL $1)")"
    fi

    echo "$output"
    return $returncode

    }

GetQPKGRemoteURL()
    {

    # $1 = QPKG name
    # stdout = QPKG remote URL
    # $? = 0 if successful, 1 if failed

    local index=0
    local output=''
    local returncode=1

    if [[ -z $1 ]]; then
        DebugError 'Package unspecified'
        errorcode=41
    else
        for index in ${!SHERPA_QPKG_NAME[@]}; do
            if [[ $1 = ${SHERPA_QPKG_NAME[$index]} ]] && [[ ${SHERPA_QPKG_ARCH[$index]} = noarch || ${SHERPA_QPKG_ARCH[$index]} = $NAS_QPKG_ARCH ]]; then
                output="${SHERPA_QPKG_URL[$index]}"
                returncode=0
                break
            fi
        done
    fi

    echo "$output"
    return $returncode

    }

GetQPKGMD5()
    {

    # $1 = QPKG name
    # stdout = QPKG MD5
    # $? = 0 if successful, 1 if failed

    local index=0
    local output=''
    local returncode=1

    if [[ -z $1 ]]; then
        DebugError 'Package unspecified'
        errorcode=42
    else
        for index in ${!SHERPA_QPKG_NAME[@]}; do
            if [[ $1 = ${SHERPA_QPKG_NAME[$index]} ]] && [[ ${SHERPA_QPKG_ARCH[$index]} = noarch || ${SHERPA_QPKG_ARCH[$index]} = $NAS_QPKG_ARCH ]]; then
                output="${SHERPA_QPKG_MD5[$index]}"
                returncode=0
                break
            fi
        done
    fi

    echo "$output"
    return $returncode

    }

CTRL_C_Captured()
    {

    [[ -e $monitor_flag ]] && rm "$monitor_flag"

    $SLEEP_CMD 1

    exit

    }

Cleanup()
    {

    DebugFuncEntry

    cd "$SHARE_PUBLIC_PATH"

    [[ $errorcode -eq 0 && $debug != true && -d $WORKING_PATH ]] && rm -rf "$WORKING_PATH"

    DebugFuncExit
    return 0

    }

DisplayResult()
    {

    DebugFuncEntry

    local RE=''
    local SL=''
    local suggest_issue=false

    if [[ -n $TARGET_APP ]]; then
        [[ $REINSTALL_FLAG = true ]] && RE='re' || RE=''
        [[ $secure_web_login = true ]] && SL='s' || SL=''

        if [[ $errorcode -eq 0 ]]; then
            [[ $debug = true ]] && emoticon=':DD' || { emoticon=''; echo ;}

            if [[ -n $OLD_APP ]]; then
                ShowDone "'$OLD_APP' has been successfully replaced with '$TARGET_APP'! $emoticon"
            else
                ShowDone "'$TARGET_APP' has been successfully ${RE}installed! $emoticon"
            fi
        elif [[ $errorcode -gt 3 ]]; then       # don't display 'failed' when only showing help
            [[ $debug = true ]] && emoticon=':S ' || { emoticon=''; echo ;}
            ShowError "'$TARGET_APP' ${RE}install failed! ${emoticon}[$errorcode]"
            suggest_issue=true
        fi
    fi

    if [[ $satisfy_dependencies_only = true ]]; then
        if [[ $errorcode -eq 0 ]]; then
            [[ $debug = true ]] && emoticon=':DD' || { emoticon=''; echo ;}
            ShowDone "all application dependencies are installed! $emoticon"
        else
            [[ $debug = true ]] && emoticon=':S ' || { emoticon=''; echo ;}
            ShowError "application dependency check failed! ${emoticon}[$errorcode]"
            suggest_issue=true
        fi
    fi

    if [[ $suggest_issue = true ]]; then
        echo -e "\n* Please consider creating a new issue for this on GitHub:\n\thttps://github.com/OneCDOnly/sherpa/issues"
        echo -e "\n* Alternatively, post on the QNAP NAS Community Forum:\n\thttps://forum.qnap.com/viewtopic.php?f=320&t=132373"
        echo -e "\n* Remember to include a copy of your sherpa runtime debug log for analysis."
    fi

    DebugInfoThinSeparator
    DebugScript 'finished' "$($DATE_CMD)"
    DebugScript 'elapsed time' "$(ConvertSecsToMinutes "$(($($DATE_CMD +%s)-$([[ -n $SCRIPT_STARTSECONDS ]] && echo $SCRIPT_STARTSECONDS || echo "1")))")"
    DebugInfoThickSeparator

    [[ -e $DEBUG_LOG_PATHFILE && $debug = false ]] && echo -e "\n- To display the runtime debug log:\n\tcat ${DEBUG_LOG_PATHFILE}\n"

    DebugFuncExit
    return 0

    }

FindAllIPKGDependencies()
    {

    # From a specified list of IPKG names, find all dependent IPKGs, exclude those already installed, then generate a total qty to download and a total download byte-size.
    # input:
    #   $1 = string with space-separated initial IPKG names.
    # output:
    #   $IPKG_download_list = array with complete list of all IPKGs, including those originally specified.
    #   $IPKG_download_count = number of packages to be downloaded.
    #   $IPKG_download_size = byte-count of packages to be downloaded.

    IPKG_download_size=0
    IPKG_download_count=0
    IPKG_download_list=()
    local requested_list=()
    local last_list=()
    local all_list=()
    local dependency_list=''
    local iterations=0
    local iteration_limit=20
    local complete=false
    local result_size=0
    local IPKG_search_startseconds=$(DebugStageStart)

    [[ -z $1 ]] && { DebugError 'No IPKGs were requested'; return 1 ;}

    IsSysFilePresent $OPKG_CMD || return

    # remove duplicate entries
    requested_list=$($TR_CMD ' ' '\n' <<< $1 | $SORT_CMD | $UNIQ_CMD | $TR_CMD '\n' ' ')
    last_list=$requested_list

    ShowProc 'calculating number and total size of IPKGs required'
    DebugInfo "requested IPKGs: ${requested_list[*]}"

    DebugProc 'finding all IPKG dependencies'
    while [[ $iterations -lt $iteration_limit ]]; do
        ((iterations++))
        last_list=$($OPKG_CMD depends -A $last_list | $GREP_CMD -v 'depends on:' | $SED_CMD 's|^[[:blank:]]*||;s|[[:blank:]]*$||' | $TR_CMD ' ' '\n' | $SORT_CMD | $UNIQ_CMD)

        if [[ -n $last_list ]]; then
            [[ -n $dependency_list ]] && dependency_list+=$(echo -e "\n$last_list") || dependency_list=$last_list
        else
            DebugDone 'complete'
            DebugInfo "found all IPKG dependencies in $iterations iterations"
            complete=true
            break
        fi
    done

    [[ $complete = false ]] && DebugError "IPKG dependency list is incomplete! Consider raising \$iteration_limit [$iteration_limit]."

    # remove duplicate entries
    all_list=$(echo "$requested_list $dependency_list" | $TR_CMD ' ' '\n' | $SORT_CMD | $UNIQ_CMD | $TR_CMD '\n' ' ')

    DebugProc 'excluding packages already installed'
    for element in ${all_list[@]}; do
        $OPKG_CMD status "$element" | $GREP_CMD -q "Status:.*installed" || IPKG_download_list+=($element)
    done
    DebugDone 'complete'
    DebugInfo "IPKGs to download: ${IPKG_download_list[*]}"
    IPKG_download_count=${#IPKG_download_list[@]}

    if [[ $IPKG_download_count -gt 0 ]]; then
        DebugProc 'calculating size of IPKGs to download'
        for element in ${IPKG_download_list[@]}; do
            result_size=$($OPKG_CMD info $element | $GREP_CMD -F 'Size:' | $SED_CMD 's|^Size: ||')
            ((IPKG_download_size+=result_size))
        done
        DebugDone 'complete'
    fi
    DebugVar IPKG_download_size
    DebugStageEnd $IPKG_search_startseconds

    if [[ $IPKG_download_count -gt 0 ]]; then
        ShowDone "$IPKG_download_count IPKGs ($(Convert2ISO $IPKG_download_size)) to be downloaded"
    else
        ShowDone 'no IPKGs are required'
    fi

    }

_MonitorDirSize_()
    {

    # * This function runs autonomously *
    # It watches for the existence of the pathfile set in $monitor_flag.
    # If this file is removed, this function dies gracefully.

    # $1 = directory to monitor the size of.
    # $2 = total target bytes (100%) for specified path.

    [[ -z $1 || ! -d $1 ]] && return 1
    [[ -z $2 || $2 -eq 0 ]] && return 1

    local target_dir="$1"
    local total_bytes=$2
    local last_bytes=0
    local stall_seconds=0
    local stall_seconds_threshold=4
    local current_bytes=0
    local percent=''

    IsSysFilePresent $FIND_CMD || return

    InitProgress

    while [[ -e $monitor_flag ]]; do
        current_bytes=$($FIND_CMD $target_dir -type f -name '*.ipk' -exec $DU_CMD --bytes --total --apparent-size {} + 2> /dev/null | $GREP_CMD total$ | $CUT_CMD -f1)
        [[ -z $current_bytes ]] && current_bytes=0

        if [[ $current_bytes -ne $last_bytes ]]; then
            stall_seconds=0
            last_bytes=$current_bytes
        else
            ((stall_seconds++))
        fi

        percent="$((200*(current_bytes)/(total_bytes) % 2 + 100*(current_bytes)/(total_bytes)))%"
        progress_message=" $percent ($(Convert2ISO $current_bytes)/$(Convert2ISO $total_bytes))"

        if [[ $stall_seconds -ge $stall_seconds_threshold ]]; then
            if [[ $stall_seconds -lt 60 ]]; then
                progress_message+=" stalled for $stall_seconds seconds"
            else
                progress_message+=" stalled for $(ConvertSecsToMinutes $stall_seconds)"
            fi
        fi

        ProgressUpdater "$progress_message"
        $SLEEP_CMD 1
    done

    [[ -n $progress_message ]] && ProgressUpdater " done!"

    }

EnableQPKG()
    {

    # $1 = package name to enable

    [[ -z $1 ]] && return 1

    if [[ $($GETCFG_CMD "$1" Enable -u -f "$APP_CENTER_CONFIG_PATHFILE") != 'TRUE' ]]; then
        DebugProc "enabling QPKG '$1'"
        $SETCFG_CMD "$1" Enable TRUE -f "$APP_CENTER_CONFIG_PATHFILE"
        DebugDone "QPKG '$1' enabled"
    fi

    }

IsQPKGUserInstallable()
    {

    # input:
    #   $1 = package name to check
    # output:
    #   $? = 0 (true) or 1 (false)

    local returncode=1
    local package_index=0

    [[ -z $1 ]] && return 1
    [[ ${#SHERPA_QPKG_NAME[@]} -eq 0 || ${#SHERPA_QPKG_ABBRVS[@]} -eq 0 ]] && return 1

    for package_index in ${!SHERPA_QPKG_NAME[@]}; do
        if [[ ${SHERPA_QPKG_NAME[$package_index]} = $1 && -n ${SHERPA_QPKG_ABBRVS[$package_index]} ]]; then
            returncode=0
            break
        fi
    done

    return $returncode

    }

IsQPKGInstalled()
    {

    # input:
    #   $1 = package name to check
    # output:
    #   $package_is_installed = true / false
    #   $? = 0 (true) or 1 (false)

    package_is_installed=false

    [[ -z $1 ]] && return 1

    if [[ $($GETCFG_CMD "$1" RC_Number -d 0 -f "$APP_CENTER_CONFIG_PATHFILE") -eq 0 ]]; then
        return 1
    else
        package_is_installed=true
        return 0
    fi

    }

IsQPKGEnabled()
    {

    # input:
    #   $1 = package name to check
    # output:
    #   $package_is_enabled = true / false
    #   $? = 0 (true) or 1 (false)

    package_is_enabled=false

    [[ -z $1 ]] && return 1

    if [[ $($GETCFG_CMD "$1" Enable -u -f "$APP_CENTER_CONFIG_PATHFILE") != 'TRUE' ]]; then
        return 1
    else
        package_is_enabled=true
        return 0
    fi

    }

IsIPKGInstalled()
    {

    # input:
    #   $1 = package name to check
    # output:
    #   $? = 0 (true) or 1 (false)

    [[ -z $1 ]] && return 1

    if ! ($OPKG_CMD list-installed | $GREP_CMD -q -F "$1"); then
        DebugIPKG "'$1'" 'not installed'
        return 1
    else
        DebugIPKG "'$1'" 'installed'
        return 0
    fi

    }

IsSysFilePresent()
    {

    # input:
    #   $1 = pathfile to check
    # output:
    #   $? = 0 (true) or 1 (false)

    [[ -z $1 ]] && return 1

    if ! [[ -f $1 || -L $1 ]]; then
        ShowError "a required NAS system file is missing [$1]"
        errorcode=43
        return 1
    else
        return 0
    fi

    }

IsSysSharePresent()
    {

    # input:
    #   $1 = symlink path to check
    # output:
    #   $? = 0 (true) or 1 (false)

    [[ -z $1 ]] && return 1

    if [[ ! -L $1 ]]; then
        ShowError "a required NAS system share is missing [$1]. Please re-create it via the QTS Control Panel -> Privilege Settings -> Shared Folders."
        errorcode=44
        return 1
    else
        return 0
    fi

    }

MatchAbbrvToQPKGName()
    {

    # input:
    #   $1 = a potential package abbreviation supplied by user
    # output:
    #   stdout = matched installable package name (empty if unmatched)
    #   $? = 0 (matched) or 1 (unmatched)

    local returncode=1
    local abbs=()
    local package_index=0
    local abb_index=0

    [[ -z $1 ]] && return 1
    [[ ${#SHERPA_QPKG_NAME[@]} -eq 0 || ${#SHERPA_QPKG_ABBRVS[@]} -eq 0 ]] && return 1

    for package_index in ${!SHERPA_QPKG_NAME[@]}; do
        abbs=(${SHERPA_QPKG_ABBRVS[$package_index]})
        for abb_index in ${!abbs[@]}; do
            if [[ ${abbs[$abb_index]} = $1 ]]; then
                echo "${SHERPA_QPKG_NAME[$package_index]}"
                returncode=0
                break 2
            fi
        done
    done

    return $returncode

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
            printf "%${previous_length}s" | $TR_CMD ' ' '\b' ; echo -n "$1 " ; printf "%${appended_length}s" ; printf "%${appended_length}s" | $TR_CMD ' ' '\b'
        else
            # backspace to start of previous msg, print new msg
            printf "%${previous_length}s" | $TR_CMD ' ' '\b' ; echo -n "$1 "
        fi

        previous_length=$current_length
        previous_msg="$1"
    fi

    }

ConvertSecsToMinutes()
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

    echo "$1" | $AWK_CMD 'BEGIN{ u[0]="B"; u[1]="kB"; u[2]="MB"; u[3]="GB"} { n = $1; i = 0; while(n > 1000) { i+=1; n= int((n/1000)+0.5) } print n u[i] } '

    }

DebugInfoThickSeparator()
    {

    DebugInfo "$(printf '%0.s=' {1..70})"

    }

DebugInfoThinSeparator()
    {

    DebugInfo "$(printf '%0.s-' {1..70})"

    }

DebugErrorThinSeparator()
    {

    DebugError "$(printf '%0.s-' {1..70})"

    }

DebugLogThinSeparator()
    {

    DebugLog "$(printf '%0.s-' {1..70})"

    }

DebugStageStart()
    {

    # stdout = current time in seconds

    $DATE_CMD +%s
    DebugInfoThinSeparator
    DebugStage 'start stage timer'

    }

DebugStageEnd()
    {

    # $1 = start time in seconds

    DebugStage 'elapsed time' "$(ConvertSecsToMinutes "$(($($DATE_CMD +%s)-$([[ -n $1 ]] && echo $1 || echo "1")))")"
    DebugInfoThinSeparator

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

DebugIPKG()
    {

    DebugDetected 'IPKG' "$1" "$2"

    }

DebugFuncEntry()
    {

    DebugThis "(>>) <${FUNCNAME[1]}>"

    }

DebugFuncExit()
    {

    DebugThis "(<<) <${FUNCNAME[1]}> [$errorcode]"

    }

DebugProc()
    {

    DebugThis "(==) $1 ..."

    }

DebugDone()
    {

    DebugThis "(--) $1"

    }

DebugDetected()
    {

    if [[ -z $3 ]]; then
        DebugThis "(**) $(printf "%-6s: %17s\n" "$1" "$2")"
    else
        DebugThis "(**) $(printf "%-6s: %17s: %-s\n" "$1" "$2" "$3")"
    fi

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

    DebugThis "(EE) $1"

    }

DebugLog()
    {

    DebugThis "(LL) $1"

    }

DebugVar()
    {

    DebugThis "(vv) \$$1 [${!1}]"

    }

DebugThis()
    {

    [[ $debug = true ]] && ShowDebug "$1"
    SaveDebug "$1"

    }

DebugErrorFile()
    {

    # add the contents of specified pathfile $1 to the main runtime log

    [[ -z $1 || ! -e $1 ]] && return 1
    local linebuff=''

    DebugLogThinSeparator
    DebugLog "$1"
    DebugLogThinSeparator

    while read linebuff; do
        DebugLog "$linebuff"
    done < "$1"

    DebugLogThinSeparator

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

    local buffer="$1"
    local capitalised="$(tr "[a-z]" "[A-Z]" <<< ${buffer:0:1})${buffer:1}"

    ShowLogLine_update "$(ColourTextBrightRed fail)" "$capitalised"
    SaveLogLine fail "$capitalised"

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

    [[ -n $DEBUG_LOG_PATHFILE ]] && $TOUCH_CMD "$DEBUG_LOG_PATHFILE" && printf "[ %-4s ] %s\n" "$1" "$2" >> "$DEBUG_LOG_PATHFILE"

    }

ColourTextBrightGreen()
    {

    echo -en '\033[1;32m'"$(PrintResetColours "$1")"

    }

ColourTextBrightOrange()
    {

    echo -en '\033[1;38;5;214m'"$(PrintResetColours "$1")"

    }

ColourTextBrightRed()
    {

    echo -en '\033[1;31m'"$(PrintResetColours "$1")"

    }

ColourTextUnderlinedBlue()
    {

    echo -en '\033[4;94m'"$(PrintResetColours "$1")"

    }

ColourTextBlackOnCyan()
    {

    echo -en '\033[30;46m'"$(PrintResetColours "$1")"

    }

ColourTextBrightWhite()
    {

    echo -en '\033[1;97m'"$(PrintResetColours "$1")"

    }

PrintResetColours()
    {

    echo -en "$1"'\033[0m'

    }

PauseHere()
    {

    # wait here temporarily

    local wait_seconds=10

    ShowProc "waiting for $wait_seconds seconds for service to initialise"
    $SLEEP_CMD $wait_seconds
    ShowDone 'completed wait'

    }

Init
DownloadQPKGs
RemoveUnwantedQPKGs
InstallBase
InstallBaseAddons
BackupAndRemoveOldQPKG
InstallTargetQPKG
Cleanup
DisplayResult

exit $errorcode
