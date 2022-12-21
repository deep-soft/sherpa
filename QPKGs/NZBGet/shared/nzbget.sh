#!/usr/bin/env bash
####################################################################################
# nzbget.sh
#
# Copyright (C) 2019-2022 OneCD [one.cd.only@gmail.com]
#
# so, blame OneCD if it all goes horribly wrong. ;)
#
# This is a type 3 service-script: https://github.com/OneCDOnly/sherpa/blob/main/QPKG-service-script-types.txt
#
# For more info: https://forum.qnap.com/viewtopic.php?f=320&t=132373
####################################################################################

readonly USER_ARGS_RAW=$*

Init()
    {

    IsQNAP || return

    # service-script environment
    readonly QPKG_NAME=NZBGet
    readonly SCRIPT_VERSION=221221

    # general environment
    readonly QPKG_PATH=$(/sbin/getcfg $QPKG_NAME Install_Path -f /etc/config/qpkg.conf)
    readonly QPKG_VERSION=$(/sbin/getcfg $QPKG_NAME Version -d unknown -f /etc/config/qpkg.conf)
    readonly QPKG_INI_PATHFILE=$QPKG_PATH/config/config.ini
    readonly QPKG_INI_DEFAULT_PATHFILE=$QPKG_INI_PATHFILE.def
    readonly APP_VERSION_STORE_PATHFILE=$QPKG_PATH/config/version.stored
    readonly SERVICE_STATUS_PATHFILE=/var/run/$QPKG_NAME.last.operation
    readonly SERVICE_LOG_PATHFILE=/var/log/$QPKG_NAME.log
    local -r BACKUP_PATH=$(/sbin/getcfg SHARE_DEF defVolMP -f /etc/config/def_share.info)/.qpkg_config_backup
    readonly BACKUP_PATHFILE=$BACKUP_PATH/$QPKG_NAME.config.tar.gz
    readonly OPKG_PATH=/opt/bin:/opt/sbin
    export PATH="$OPKG_PATH:$(/bin/sed "s|$OPKG_PATH||" <<< "$PATH")"
    readonly DEBUG_LOG_DATAWIDTH=100
    local re=''

    # specific to Entware binaries only
    readonly ORIG_DAEMON_SERVICE_SCRIPT=/opt/etc/init.d/S75nzbget

    # specific to daemonised applications only
    readonly DAEMON_PATHFILE=/opt/bin/nzbget
    readonly DAEMON_PID_PATHFILE=/opt/var/lock/nzbget.lock
    readonly LAUNCHER="$DAEMON_PATHFILE --daemon --configfile $QPKG_INI_PATHFILE"
    readonly PORT_CHECK_TIMEOUT=60
    readonly DAEMON_STOP_TIMEOUT=60
    readonly UI_PORT_CMD="/sbin/getcfg '' ControlPort -d 0 -f $QPKG_INI_PATHFILE"
    readonly UI_PORT_SECURE_CMD="/sbin/getcfg '' SecurePort -d 0 -f $QPKG_INI_PATHFILE"
    readonly SECURE_PORT_ENABLED_CMD="/sbin/getcfg '' SecureControl -d no -f $QPKG_INI_PATHFILE"
    readonly UI_LISTENING_ADDRESS_CMD="/sbin/getcfg '' ControlIP -f $QPKG_INI_PATHFILE"
    ui_port=0
    ui_port_secure=0
    ui_listening_address=''

    # specific to applications supporting version lookup only
    readonly APP_VERSION_PATHFILE=$DAEMON_PATHFILE
    readonly APP_VERSION_CMD="$DAEMON_PATHFILE --version 2>&1 | /bin/sed 's|nzbget version: ||'"

    if [[ -z $LANG ]]; then
        export LANG=en_US.UTF-8
        export LC_ALL=en_US.UTF-8
        export LC_CTYPE=en_US.UTF-8
    fi

    if [[ ${DEBUG_QPKG:-} = true ]]; then
        SetDebug
    else
        UnsetDebug
    fi

    for re in \\bd\\b \\bdebug\\b \\bdbug\\b \\bverbose\\b; do
        if [[ $USER_ARGS_RAW =~ $re ]]; then
            SetDebug
            break
        fi
    done

    UnsetError
    UnsetRestartPending
    EnsureConfigFileExists
    LoadAppVersion
    DisableOpkgDaemonStart

    IsSupportBackup && [[ -n ${BACKUP_PATH:-} && ! -d $BACKUP_PATH ]] && mkdir -p "$BACKUP_PATH"

    return 0

    }

ShowHelp()
    {

    Display "$(ColourTextBrightWhite "$(/usr/bin/basename "$0")") $SCRIPT_VERSION • a service control script for the $(FormatAsPackageName $QPKG_NAME) QPKG"
    Display
    Display "Usage: $0 [OPTION]"
    Display
    Display '[OPTION] may be any one of the following:'
    Display
    DisplayAsHelp start "launch $(FormatAsPackageName $QPKG_NAME) if not already running."
    DisplayAsHelp stop "shutdown $(FormatAsPackageName $QPKG_NAME) if running."
    DisplayAsHelp restart "stop, then start $(FormatAsPackageName $QPKG_NAME)."
    DisplayAsHelp status "check if $(FormatAsPackageName $QPKG_NAME) daemon is running. Returns \$? = 0 if running, 1 if not."
    IsSupportBackup && DisplayAsHelp backup "backup the current $(FormatAsPackageName $QPKG_NAME) configuration to persistent storage."
    IsSupportBackup && DisplayAsHelp restore "restore a previously saved configuration from persistent storage. $(FormatAsPackageName $QPKG_NAME) will be stopped, then restarted."
    IsSupportReset && DisplayAsHelp reset-config "delete the application configuration, databases and history. $(FormatAsPackageName $QPKG_NAME) will be stopped, then restarted."
    IsSourcedOnline && DisplayAsHelp clean "delete the local copy of $(FormatAsPackageName $QPKG_NAME), and download it again from remote source. Configuration will be retained."
    DisplayAsHelp log 'display the service-script log.'
    IsSourcedOnline && DisplayAsHelp enable-auto-update "auto-update $(FormatAsPackageName $QPKG_NAME) before starting (default)."
    IsSourcedOnline && DisplayAsHelp disable-auto-update "don't auto-update $(FormatAsPackageName $QPKG_NAME) before starting."
    DisplayAsHelp version 'display the package version numbers.'
    Display

    }

StartQPKG()
    {

    # this function is customised depending on the requirements of the packaged application

    IsError && return

    if IsNotRestart && IsNotRestore && IsNotClean && IsNotReset; then
        CommitOperationToLog
        IsDaemonActive && return
    fi

    if IsRestore || IsClean || IsReset; then
        IsNotRestartPending && return
    fi

    IsNotDaemon && return
    WaitForLaunchTarget || return
    EnsureConfigFileExists
    LoadUIPorts app || return

    if [[ $ui_port -le 0 && $ui_port_secure -le 0 ]]; then
        DisplayErrCommitAllLogs 'unable to start daemon: no UI port was specified!'
        SetError
        return 1
    elif IsNotPortAvailable $ui_port || IsNotPortAvailable $ui_port_secure; then
        DisplayErrCommitAllLogs "unable to start daemon: ports $ui_port or $ui_port_secure are already in use!"

        portpid=$(/usr/sbin/lsof -i :$ui_port -Fp)
        DisplayErrCommitAllLogs "process details for port $ui_port: \"$([[ -n ${portpid:-} ]] && /bin/tr '\000' ' ' </proc/${portpid/p/}/cmdline)\""

        portpid=$(/usr/sbin/lsof -i :$ui_port_secure -Fp)
        DisplayErrCommitAllLogs "process details for secure port $ui_port_secure: \"$([[ -n ${portpid:-} ]] && /bin/tr '\000' ' ' </proc/${portpid/p/}/cmdline)\""

        SetError
        return 1
    fi

    DisplayRunAndLog 'start daemon' "$LAUNCHER" log:everything || return
    WaitForPID || return
    IsDaemonActive || return
    CheckPorts || return

    return 0

    }

StopQPKG()
    {

    # this function is customised depending on the requirements of the packaged application

    IsError && return

    if IsNotRestore && IsNotClean && IsNotReset; then
        CommitOperationToLog
    fi

    if IsDaemonActive; then
        if IsRestart || IsRestore || IsClean || IsReset; then
            SetRestartPending
        fi

        local acc=0
        local pid=0
        SetRestartPending

        killall "$(/usr/bin/basename "$DAEMON_PATHFILE")"
        DisplayWaitCommitToLog 'stop daemon with SIGTERM:'
        DisplayWait "(no-more than $DAEMON_STOP_TIMEOUT seconds):"

        while true; do
            while (ps ax | /bin/grep $DAEMON_PATHFILE | /bin/grep -vq grep); do
                sleep 1
                ((acc++))
                DisplayWait "$acc,"

                if [[ $acc -ge $DAEMON_STOP_TIMEOUT ]]; then
                    DisplayCommitToLog 'failed!'
                    DisplayCommitToLog 'stop daemon with SIGKILL'
                    killall -9 "$(/usr/bin/basename "$DAEMON_PATHFILE")"
                    [[ -f $DAEMON_PID_PATHFILE ]] && rm -f $DAEMON_PID_PATHFILE
                    break 2
                fi
            done

            [[ -f $DAEMON_PID_PATHFILE ]] && rm -f $DAEMON_PID_PATHFILE
            Display OK
            CommitLog "stopped OK in $acc seconds"

            CommitInfoToSysLog 'stop daemon: OK.'
            break
        done

        IsNotDaemonActive || return
    fi

    return 0

    }

BackupConfig()
    {

    CommitOperationToLog
    DisplayRunAndLog 'update configuration backup' "/bin/tar --create --gzip --file=$BACKUP_PATHFILE --directory=$QPKG_PATH/config ." log:everything || SetError

    }

RestoreConfig()
    {

    CommitOperationToLog

    if [[ ! -f $BACKUP_PATHFILE ]]; then
        DisplayErrCommitAllLogs 'unable to restore configuration: no backup file was found!'
        SetError
        return 1
    fi

    StopQPKG
    DisplayRunAndLog 'restore configuration backup' "/bin/tar --extract --gzip --file=$BACKUP_PATHFILE --directory=$QPKG_PATH/config" log:everything || SetError
    StartQPKG

    }

ResetConfig()
    {

    CommitOperationToLog
    StopQPKG
    DisplayRunAndLog 'reset configuration' "mv $QPKG_INI_DEFAULT_PATHFILE $QPKG_PATH; rm -rf $QPKG_PATH/config/*; mv $QPKG_PATH/$(/usr/bin/basename "$QPKG_INI_DEFAULT_PATHFILE") $QPKG_INI_DEFAULT_PATHFILE" log:everything || SetError
    StartQPKG

    }

LoadUIPorts()
    {

    # If user changes ports via app UI, must first 'stop' application on old ports, then 'start' on new ports

    case $1 in
        app)
            # Read the current application UI ports from application configuration
            DisplayWaitCommitToLog 'load UI ports from application config:'
            ui_port=$(eval "$UI_PORT_CMD")
            ui_port_secure=$(eval "$UI_PORT_SECURE_CMD")
            DisplayCommitToLog OK
            ;;
        qts)
            # Read the current application UI ports from QTS App Center
            DisplayWaitCommitToLog 'load UI ports from QPKG icon:'
            ui_port=$(/sbin/getcfg $QPKG_NAME Web_Port -d 0 -f /etc/config/qpkg.conf)
            ui_port_secure=$(/sbin/getcfg $QPKG_NAME Web_SSL_Port -d 0 -f /etc/config/qpkg.conf)
            DisplayCommitToLog OK
            ;;
        *)
            DisplayErrCommitAllLogs "unable to load UI ports: action '$1' is unrecognised"
            SetError
            return 1
            ;;
    esac

    if [[ $ui_port -eq 0 ]] && IsNotDefaultConfigFound; then
        ui_port=0
        ui_port_secure=0
    fi

    # Always read this from the application configuration
    ui_listening_address=$(eval "$UI_LISTENING_ADDRESS_CMD")

    return 0

    }

IsSSLEnabled()
    {

    [[ $(eval "$SECURE_PORT_ENABLED_CMD") -eq 1 ]]

    }

LoadAppVersion()
    {

    # Find the application's internal version number
    # creates a global var: $app_version
    # this is the installed application version (not the QPKG version)

    if [[ -n ${APP_VERSION_PATHFILE:-} && -e $APP_VERSION_PATHFILE ]]; then
        app_version=$(eval "$APP_VERSION_CMD")
        return 0
    else
        app_version='unknown'
        return 1
    fi

    }

StatusQPKG()
    {

    IsNotError || return

    if IsDaemonActive; then
        if IsDaemon || IsSourcedOnline; then
            LoadUIPorts qts
            if ! CheckPorts; then
                SetError
                return 1
            fi
        fi
    else
        SetError
        return 1
    fi

    return 0

    }

DisableOpkgDaemonStart()
    {

    if [[ -n $ORIG_DAEMON_SERVICE_SCRIPT && -x $ORIG_DAEMON_SERVICE_SCRIPT ]]; then
        $ORIG_DAEMON_SERVICE_SCRIPT stop        # stop default daemon
        chmod -x "$ORIG_DAEMON_SERVICE_SCRIPT"  # ... and ensure Entware doesn't re-launch it on startup
    fi

    }

WaitForLaunchTarget()
    {

    local launch_target=''

    if [[ -n ${INTERPRETER:-} ]]; then
        launch_target=$INTERPRETER
    elif [[ -n ${DAEMON_PATHFILE:-} ]]; then
        launch_target=$DAEMON_PATHFILE
    else
        return 0
    fi

    if WaitForFileToAppear "$launch_target" 30; then
        return 0
    else
        return 1
    fi

    }

WaitForPID()
    {

    if WaitForFileToAppear "$DAEMON_PID_PATHFILE" 60; then
        sleep 1       # wait one more second to allow file to have PID written into it
        return 0
    else
        return 1
    fi

    }

WaitForFileToAppear()
    {

    # input:
    #   $1 = pathfilename to watch for
    #   $2 = timeout in seconds (optional) - default 30

    # output:
    #   $? = 0 (file was found) or 1 (file not found: timeout)

    [[ -z $1 ]] && return

    if [[ -n $2 ]]; then
        MAX_SECONDS=$2
    else
        MAX_SECONDS=30
    fi

    if [[ ! -e $1 ]]; then
        DisplayWaitCommitToLog "wait for $(FormatAsFileName "$1") to appear:"
        DisplayWait "(no-more than $MAX_SECONDS seconds):"

        (
            for ((count=1; count<=MAX_SECONDS; count++)); do
                sleep 1
                DisplayWait "$count,"
                if [[ -e $1 ]]; then
                    Display OK
                    CommitLog "visible in $count second$(FormatAsPlural "$count")"
                    true
                    exit    # only this sub-shell
                fi
            done
            false
        )

        if [[ $? -ne 0 ]]; then
            DisplayCommitToLog 'failed!'
            DisplayErrCommitAllLogs "$(FormatAsFileName "$1") not found! (exceeded timeout: $MAX_SECONDS seconds)"
            return 1
        fi
    fi

    DisplayCommitToLog "file $(FormatAsFileName "$1"): exists"

    return 0

    }

EnsureConfigFileExists()
    {

    IsNotSupportReset && return

    if IsNotConfigFound && IsDefaultConfigFound; then
        DisplayCommitToLog 'no configuration file found: using default'
        cp "$QPKG_INI_DEFAULT_PATHFILE" "$QPKG_INI_PATHFILE"
    fi

    }

ViewLog()
    {

    if [[ -e $SERVICE_LOG_PATHFILE ]]; then
        if [[ -e /opt/bin/less ]]; then
            LESSSECURE=1 /opt/bin/less +G --quit-on-intr --tilde --LINE-NUMBERS --prompt ' use arrow-keys to scroll up-down left-right, press Q to quit' "$SERVICE_LOG_PATHFILE"
        else
            cat --number "$SERVICE_LOG_PATHFILE"
        fi
    else
        Display "service log not found: $(FormatAsFileName "$SERVICE_LOG_PATHFILE")"
        SetError
        return 1
    fi

    return 0

    }

DisplayRunAndLog()
    {

    # Run a commandstring, log the results, and show onscreen if required

    # input:
    #   $1 = processing message
    #   $2 = commandstring to execute
    #   $3 = 'log:failure-only' (optional) - if specified, stdout & stderr are only recorded in the specified log if the command failed
    #                                      - if unspecified, stdout & stderr is always recorded

    local -r LOG_PATHFILE=$(/bin/mktemp -p /var/log ${FUNCNAME[0]}_XXXXXX)
    local -i result_code=0

    DisplayWaitCommitToLog "$1:"

    RunAndLog "$2" "$LOG_PATHFILE" "$3"
    result_code=$?

    if [[ -e $LOG_PATHFILE ]]; then
        rm -f "$LOG_PATHFILE"
    fi

    if [[ $result_code -eq 0 ]]; then
        DisplayCommitToLog OK
        [[ $3 = log:everything ]] && CommitInfoToSysLog "$1: OK."
        return 0
    else
        DisplayCommitToLog 'failed!'
        return 1
    fi

    }

RunAndLog()
    {

    # Run a commandstring, log the results, and show onscreen if required

    # input:
    #   $1 = commandstring to execute
    #   $2 = pathfile to record stdout and stderr for commandstring
    #   $3 = 'log:failure-only' (optional) - if specified, stdout & stderr are only recorded in the specified log if the command failed
    #                                      - if unspecified, stdout & stderr is always recorded
    #   $4 = e.g. '10' (optional) - an additional acceptable result code. Any other result from command (other than zero) will be considered a failure

    # output:
    #   stdout = commandstring stdout and stderr if script is in 'debug' mode
    #   pathfile ($2) = commandstring ($1) stdout and stderr
    #   $? = result_code of commandstring

    local -r LOG_PATHFILE=$(/bin/mktemp -p /var/log ${FUNCNAME[0]}_XXXXXX)
    local -i result_code=0

    FormatAsCommand "${1:?empty}" > "${2:?empty}"

    if IsDebug; then
        Display
        Display "exec: '$1'"
        eval "$1 > >(/usr/bin/tee $LOG_PATHFILE) 2>&1"   # NOTE: 'tee' buffers stdout here
        result_code=$?
    else
        eval "$1" > "$LOG_PATHFILE" 2>&1
        result_code=$?
    fi

    if [[ -e $LOG_PATHFILE ]]; then
        FormatAsResultAndStdout "$result_code" "$(<"$LOG_PATHFILE")" >> "$2"
        rm -f "$LOG_PATHFILE"
    else
        FormatAsResultAndStdout "$result_code" '<null>' >> "$2"
    fi

    if [[ $result_code -eq 0 ]]; then
        [[ ${3:-} != log:failure-only ]] && AddFileToDebug "$2"
    else
        [[ $result_code -ne ${4:-} ]] && AddFileToDebug "$2"
    fi

    return $result_code

    }

AddFileToDebug()
    {

    # Add the contents of specified pathfile $1 to the runtime log

    local debug_was_set=false
    local linebuff=''

    if IsDebug; then      # prevent external log contents appearing onscreen again, as they have already been seen "live"
        debug_was_set=true
        UnsetDebug
    fi

    DebugAsLog ''
    DebugAsLog 'adding external log to main log ...'
    DebugExtLogMinorSeparator
    DebugAsLog "$(FormatAsLogFilename "${1:?no filename supplied}")"

    while read -r linebuff; do
        DebugAsLog "$linebuff"
    done < "$1"

    DebugExtLogMinorSeparator
    [[ $debug_was_set = true ]] && SetDebug

    }

DebugExtLogMinorSeparator()
    {

    DebugAsLog "$(eval printf '%0.s-' "{1..$DEBUG_LOG_DATAWIDTH}")" # 'seq' is unavailable in QTS, so must resort to 'eval' trickery instead

    }

DebugAsLog()
    {

    DebugThis "(LL) ${1:-}"

    }

DebugThis()
    {

    IsDebug && Display "${1:-}"
    WriteAsDebug "${1:-}"

    }

WriteAsDebug()
    {

    WriteToLog dbug "${1:-}"

    }

WriteToLog()
    {

    # input:
    #   $1 = pass/fail
    #   $2 = message

    printf "%-4s: %s\n" "$(StripANSI "${1:-}")" "$(StripANSI "${2:-}")" >> "$SERVICE_LOG_PATHFILE"

    }

StripANSI()
    {

    # QTS 4.2.6 BusyBox 'sed' doesn't fully support extended regexes, so this only works with a real 'sed'

    if [[ -e /opt/bin/sed ]]; then
        /opt/bin/sed -r 's/\x1b\[[0-9;]*m//g' <<< "${1:-}"
    else
        echo "${1:-}"           # can't strip, so pass thru original message unaltered
    fi

    }

ReWriteUIPorts()
    {

    # Write the current application UI ports into the QTS App Center configuration

    # QTS App Center requires 'Web_Port' to always be non-zero

    # 'Web_SSL_Port' behaviour:
    #            < -2 = crashes current QTS session. Starts with non-responsive package icons in App Center
    #   missing or -2 = QTS will fallback from HTTPS to HTTP, with a warning to user
    #              -1 = launch QTS UI again (only if WebUI = '/'), else show "QNAP Error" page
    #               0 = "unable to connect"
    #             > 0 = works if logged-in to QTS UI via HTTPS

    # If SSL is enabled, attempting to access with non-SSL via 'Web_Port' results in "connection was reset"

    DisplayWaitCommitToLog 'update QPKG icon with UI ports:'
    /sbin/setcfg $QPKG_NAME Web_Port "$ui_port" -f /etc/config/qpkg.conf

    if IsSSLEnabled; then
        /sbin/setcfg $QPKG_NAME Web_SSL_Port "$ui_port_secure" -f /etc/config/qpkg.conf
    else
        /sbin/setcfg $QPKG_NAME Web_SSL_Port '-2' -f /etc/config/qpkg.conf
    fi

    DisplayCommitToLog OK

    }

CheckPorts()
    {

    local msg=''

    DisplayCommitToLog "daemon listening address: $ui_listening_address"

    if IsSSLEnabled && IsPortSecureResponds $ui_port_secure; then
        msg="HTTPS port $ui_port_secure"
    fi

    if IsNotSSLEnabled || [[ $ui_port -ne $ui_port_secure ]]; then
        # assume $ui_port should be checked too
        if IsPortResponds $ui_port; then
            if [[ -n $msg ]]; then
                msg+=" and HTTP port $ui_port"
            else
                msg="HTTP port $ui_port"
            fi
        fi
    fi

    if [[ -z $msg ]]; then
        DisplayErrCommitAllLogs 'no response on configured port(s)!'
        SetError
        return 1
    fi

    DisplayCommitToLog "$msg: OK"
    ReWriteUIPorts

    return 0

    }

IsQNAP()
    {

    # returns 0 if this is a QNAP NAS

    if [[ ! -e /etc/init.d/functions ]]; then
        Display 'QTS functions missing (is this a QNAP NAS?)'
        SetError
        return 1
    fi

    return 0

    }

IsQPKGEnabled()
    {

    [[ $(/sbin/getcfg $QPKG_NAME Enable -u -d FALSE -f /etc/config/qpkg.conf) = TRUE ]]

    }

IsNotQPKGEnabled()
    {

    ! IsQPKGEnabled

    }

IsSupportBackup()
    {

    [[ -n ${BACKUP_PATHFILE:-} ]]

    }

IsNotSupportBackup()
    {

    ! IsSupportBackup

    }

IsSupportReset()
    {

    [[ -n ${QPKG_INI_PATHFILE:-} ]]

    }

IsNotSupportReset()
    {

    ! IsSupportReset

    }

IsSourcedOnline()
    {

    [[ -n ${SOURCE_GIT_URL:-} ]]

    }

IsNotSourcedOnline()
    {

    ! IsSourcedOnline

    }

IsNotSSLEnabled()
    {

    ! IsSSLEnabled

    }

IsDaemon()
    {

    [[ -n ${DAEMON_PID_PATHFILE:-} ]]

    }

IsNotDaemon()
    {

    ! IsDaemon

    }

IsDaemonActive()
    {

    # $? = 0 : $DAEMON_PATHFILE is in memory
    # $? = 1 : $DAEMON_PATHFILE is not in memory

    if [[ -e $DAEMON_PID_PATHFILE && -d /proc/$(<$DAEMON_PID_PATHFILE) && -n ${DAEMON_PATHFILE:-} && $(</proc/"$(<$DAEMON_PID_PATHFILE)"/cmdline) =~ $DAEMON_PATHFILE ]]; then
        DisplayCommitToLog 'daemon: IS active'
        DisplayCommitToLog "daemon PID: $(<$DAEMON_PID_PATHFILE)"
        return
    fi

    DisplayCommitToLog 'daemon: NOT active'
    [[ -f $DAEMON_PID_PATHFILE ]] && rm "$DAEMON_PID_PATHFILE"
    return 1

    }

IsNotDaemonActive()
    {

    ! IsDaemonActive

    }

IsSysFilePresent()
    {

    # $1 = pathfile to check

    if [[ -z $1 ]]; then
        SetError
        return 1
    fi

    if [[ ! -e $1 ]]; then
        Display "A required NAS system file is missing: $(FormatAsFileName "$1")"
        SetError
        return 1
    else
        return 0
    fi

    }

IsNotSysFilePresent()
    {

    # $1 = pathfile to check

    ! IsSysFilePresent "$1"

    }

IsPortAvailable()
    {

    # $1 = port to check
    # $? = 0 if available
    # $? = 1 if already used

    [[ -z $1 || $1 -eq 0 ]] && return

    if (/usr/sbin/lsof -i :"$1" -sTCP:LISTEN >/dev/null 2>&1); then
        return 1
    else
        return 0
    fi

    }

IsNotPortAvailable()
    {

    # $1 = port to check
    # $? = 1 if available
    # $? = 0 if already used

    ! IsPortAvailable "$1"

    }

IsPortResponds()
    {

    # $1 = port to check
    # $? = 0 if response received
    # $? = 1 if not OK

    if [[ -z $1 || $1 -eq 0 ]]; then
        SetError
        return 1
    fi

    local acc=0

    DisplayWaitCommitToLog "check for UI port $1 response:"
    DisplayWait "(no-more than $PORT_CHECK_TIMEOUT seconds):"

    while true; do
        /sbin/curl --silent --fail --max-time 1 http://localhost:"$1" >/dev/null
        [[ $? -eq 0 || $? -eq 22 ]] && break

        sleep 1
        ((acc+=2))
        DisplayWait "$acc,"

        if [[ $acc -ge $PORT_CHECK_TIMEOUT ]]; then
            DisplayCommitToLog 'failed!'
            CommitErrToSysLog "UI port $1 failed to respond after $acc seconds"
            return 1
        fi
    done

    Display OK
    CommitLog "UI port responded after $acc seconds"

    return 0

    }

IsPortSecureResponds()
    {

    # $1 = port to check
    # $? = 0 if response received
    # $? = 1 if not OK or port unspecified

    if [[ -z $1 || $1 -eq 0 ]]; then
        SetError
        return 1
    fi

    local acc=0

    DisplayWaitCommitToLog "check for secure UI port $1 response:"
    DisplayWait "(no-more than $PORT_CHECK_TIMEOUT seconds):"

    while ! /sbin/curl --silent --insecure --fail --max-time 1 https://localhost:"$1" >/dev/null; do
        sleep 1
        ((acc+=2))
        DisplayWait "$acc,"

        if [[ $acc -ge $PORT_CHECK_TIMEOUT ]]; then
            DisplayCommitToLog 'failed!'
            CommitErrToSysLog "secure UI port $1 failed to respond after $acc seconds"
            return 1
        fi
    done

    Display OK
    CommitLog "secure UI port responded after $acc seconds"

    return 0

    }

IsConfigFound()
    {

    # Is there an application configuration file to read from?

    [[ -e $QPKG_INI_PATHFILE ]]

    }

IsNotConfigFound()
    {

    ! IsConfigFound

    }

IsDefaultConfigFound()
    {

    # Is there a default application configuration file to read from?

    [[ -e $QPKG_INI_DEFAULT_PATHFILE ]]

    }

IsNotDefaultConfigFound()
    {

    ! IsDefaultConfigFound

    }

IsVirtualEnvironmentExist()
    {

    # Is there a virtual environment to run the application in?

    [[ -e $VENV_PATH/bin/activate ]]

    }

IsNotVirtualEnvironmentExist()
    {

    ! IsVirtualEnvironmentExist

    }

SetServiceOperation()
    {

    service_operation="$1"
    SetServiceOperationResult "$1"

    }

SetServiceOperationResultOK()
    {

    SetServiceOperationResult ok

    }

SetServiceOperationResultFailed()
    {

    SetServiceOperationResult failed

    }

SetServiceOperationResult()
    {

    # $1 = result of operation to recorded

    [[ -n $1 && -n ${SERVICE_STATUS_PATHFILE:-} ]] && echo "$1" > "$SERVICE_STATUS_PATHFILE"

    }

SetRestartPending()
    {

    IsRestartPending && return
    _restart_pending_flag=true

    }

UnsetRestartPending()
    {

    IsNotRestartPending && return
    _restart_pending_flag=false

    }

IsRestartPending()
    {

    [[ $_restart_pending_flag = true ]]

    }

IsNotRestartPending()
    {

    [[ $_restart_pending_flag = false ]]

    }

SetDebug()
    {

    debug=true

    }

UnsetDebug()
    {

    debug=false

    }

IsDebug()
    {

    [[ $debug = 'true' ]]

    }

IsNotDebug()
    {

    ! IsDebug

    }

SetError()
    {

    IsError && return
    _error_flag=true

    }

UnsetError()
    {

    IsNotError && return
    _error_flag=false

    }

IsError()
    {

    [[ $_error_flag = true ]]

    }

IsNotError()
    {

    ! IsError

    }

IsRestart()
    {

    [[ $service_operation = restarting ]]

    }

IsNotRestart()
    {

    ! IsRestart

    }

IsNotRestore()
    {

    ! [[ $service_operation = restoring ]]

    }

IsNotLog()
    {

    ! [[ $service_operation = log ]]

    }

IsClean()
    {

    [[ $service_operation = cleaning ]]

    }

IsNotClean()
    {

    ! IsClean

    }

IsRestore()
    {

    [[ $service_operation = restoring ]]

    }

IsNotRestore()
    {

    ! IsRestore

    }

IsReset()
    {

    [[ $service_operation = 'resetting-config' ]]

    }

IsNotReset()
    {

    ! IsReset

    }

IsNotStatus()
    {

    ! [[ $service_operation = status ]]

    }

DisplayErrCommitAllLogs()
    {

    DisplayCommitToLog "$1"
    CommitErrToSysLog "$1"

    }

DisplayCommitToLog()
    {

    Display "$1"
    CommitLog "$1"

    }

DisplayWaitCommitToLog()
    {

    DisplayWait "$1"
    CommitLogWait "$1"

    }

FormatAsLogFilename()
    {

    echo "= log file: '$1'"

    }

FormatAsCommand()
    {

    Display "command: '$1'"

    }

FormatAsStdout()
    {

    Display "output: \"$1\""

    }

FormatAsResult()
    {

    Display "result: $(FormatAsExitcode "$1")"

    }

FormatAsResultAndStdout()
    {

    if [[ ${1:-0} -eq 0 ]]; then
        echo "= result_code: $(FormatAsExitcode "$1") ***** stdout/stderr begins below *****"
    else
        echo "! result_code: $(FormatAsExitcode "$1") ***** stdout/stderr begins below *****"
    fi

    echo "${2:-null}"
    echo '= ***** stdout/stderr is complete *****'

    }

FormatAsFuncMessages()
    {

    echo "= ${FUNCNAME[1]}()"
    FormatAsCommand "$1"
    FormatAsStdout "$2"

    }

FormatAsExitcode()
    {

    echo "[$1]"

    }

FormatAsPackageName()
    {

    echo "'$1'"

    }

FormatAsFileName()
    {

    echo "($1)"

    }

DisplayAsHelp()
    {

    printf "  --%-19s  %s\n" "$1" "$2"

    }

Display()
    {

    echo "$1"

    }

DisplayWait()
    {

    echo -n "$1 "

    }

CommitOperationToLog()
    {

    CommitLog "$(SessionSeparator "datetime:'$(date)', request:'$service_operation', package:'$QPKG_VERSION', service:'$SCRIPT_VERSION', app:'$app_version'")"

    }

CommitInfoToSysLog()
    {

    CommitSysLog "$1" 4

    }

CommitWarnToSysLog()
    {

    CommitSysLog "$1" 2

    }

CommitErrToSysLog()
    {

    CommitSysLog "$1" 1

    }

CommitLog()
    {

    if IsNotStatus && IsNotLog; then
        echo "$1" >> "$SERVICE_LOG_PATHFILE"
    fi

    }

CommitLogWait()
    {

    if IsNotStatus && IsNotLog; then
        echo -n "$1 " >> "$SERVICE_LOG_PATHFILE"
    fi

    }

CommitSysLog()
    {

    # $1 = message to append to QTS system log
    # $2 = event type:
    #    1 : Error
    #    2 : Warning
    #    4 : Information

    if [[ -z $1 || -z $2 ]]; then
        SetError
        return 1
    fi

    /sbin/write_log "[$QPKG_NAME] $1" "$2"

    }

SessionSeparator()
    {

    # $1 = message

    printf '%0.s>' {1..10}; echo -n " $1 "; printf '%0.s<' {1..10}

    }

ColourTextBrightWhite()
    {

    echo -en '\033[1;97m'"$(ColourReset "$1")"

    }

ColourReset()
    {

    echo -en "$1"'\033[0m'

    }

FormatAsPlural()
    {

    [[ $1 -ne 1 ]] && echo s

    }

Init

if IsNotError; then
    case $1 in
        start|--start)
            if IsNotQPKGEnabled; then
                echo "The $(FormatAsPackageName $QPKG_NAME) QPKG is disabled. Please enable it first with: qpkg_service enable $QPKG_NAME"
                SetError
            fi

            SetServiceOperation starting
            StartQPKG
            ;;
        stop|--stop)
            if IsNotQPKGEnabled; then
                echo "The $(FormatAsPackageName $QPKG_NAME) QPKG is disabled. Please enable it first with: qpkg_service enable $QPKG_NAME"
                SetError
            fi

            SetServiceOperation stopping
            StopQPKG
            ;;
        r|-r|restart|--restart)
            if IsNotQPKGEnabled; then
                echo "The $(FormatAsPackageName $QPKG_NAME) QPKG is disabled. Please enable it first with: qpkg_service enable $QPKG_NAME"
                SetError
            fi

            SetServiceOperation restarting
            StopQPKG
            StartQPKG
            ;;
        s|-s|status|--status)
            SetServiceOperation status
            StatusQPKG
            ;;
        b|-b|backup|--backup|backup-config|--backup-config)
            if IsSupportBackup; then
                SetServiceOperation backing-up
                BackupConfig
            else
                SetServiceOperation none
                ShowHelp
            fi
            ;;
        reset-config|--reset-config)
            if IsSupportReset; then
                SetServiceOperation resetting-config
                ResetConfig
            else
                SetServiceOperation none
                ShowHelp
            fi
            ;;
        restore|--restore|restore-config|--restore-config)
            if IsSupportBackup; then
                SetServiceOperation restoring
                RestoreConfig
            else
                SetServiceOperation none
                ShowHelp
            fi
            ;;
        l|-l|log|--log)
            SetServiceOperation logging
            ViewLog
            ;;
        v|-v|version|--version)
            SetServiceOperation versioning
            Display "package: $QPKG_VERSION"
            Display "service: $SCRIPT_VERSION"
            ;;
        remove)     # only called by the standard QDK .uninstall.sh script
            SetServiceOperation removing
            ;;
        *)
            SetServiceOperation none
            ShowHelp
    esac
fi

if IsError; then
    SetServiceOperationResultFailed
    exit 1
fi

SetServiceOperationResultOK
exit
