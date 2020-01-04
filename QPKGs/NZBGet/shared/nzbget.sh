#!/usr/bin/env bash

Init()
    {

    QPKG_NAME=NZBGet

    QTS_QPKG_CONF_PATHFILE=/etc/config/qpkg.conf
    QPKG_PATH=$(/sbin/getcfg $QPKG_NAME Install_Path -f $QTS_QPKG_CONF_PATHFILE)
    QPKG_INI_PATHFILE=$QPKG_PATH/config/config.ini
    local QPKG_INI_DEFAULT_PATHFILE=$QPKG_INI_PATHFILE.def
    INIT_LOG_PATHFILE=/var/log/$QPKG_NAME.log
    DAEMON=/opt/bin/nzbget
    LAUNCHER="$DAEMON --daemon --configfile $QPKG_INI_PATHFILE"
    export PATH=/opt/bin:/opt/sbin:$PATH

    if [[ -z $LANG ]]; then
        export LANG=en_US.UTF-8
        export LC_ALL=en_US.UTF-8
        export LC_CTYPE=en_US.UTF-8
    fi

    WaitForEntware
    errorcode=0

    if [[ ! -f $QPKG_INI_PATHFILE && -f $QPKG_INI_DEFAULT_PATHFILE ]]; then
        echo "! no settings file found: using default"
        cp $QPKG_INI_DEFAULT_PATHFILE $QPKG_INI_PATHFILE
    fi

    if [[ -x /opt/etc/init.d/S75nzbget ]]; then
        /opt/etc/init.d/S75nzbget stop          # stop default daemon
        chmod -x /opt/etc/init.d/S75nzbget      # and ensure Entware doesn't relaunch daemon on startup
    fi

    return 0

    }

QPKGIsActive()
    {

    # $? = 0 if $QPKG_NAME is active
    # $? = 1 if $QPKG_NAME is not active

    if (ps ax | grep $DAEMON | grep -vq grep); then
        echo "= ($QPKG_NAME) is active" | tee -a $INIT_LOG_PATHFILE
        return 0
    else
        echo "= ($QPKG_NAME) is not active" | tee -a $INIT_LOG_PATHFILE
        return 1
    fi

    }

StartQPKG()
    {

    local returncode=0
    local exec_msgs=''
    local ui_port=''
    local secure=''
    local msg=''

    QPKGIsActive && return

    ui_port=$(UIPortSecure)
    if [[ $ui_port -gt 0 ]]; then
        secure='S'
    else
        ui_port=$(UIPort)
    fi

    {
        if (PortAvailable $ui_port); then
            if [[ $ui_port -gt 0 ]]; then
                /sbin/setcfg $QPKG_NAME Web_Port $ui_port -f $QTS_QPKG_CONF_PATHFILE

                echo -n "* starting ($QPKG_NAME): "
                exec_msgs=$($LAUNCHER 2>&1)
                result=$?

                if [[ $result = 0 || $result = 2 ]]; then
                    echo "OK"
                    sleep 2              # allow time for daemon to start and claim port
                    ! PortAvailable $ui_port && echo "= service configured for HTTP${secure} port: $ui_port"
                else
                    echo "failed!"
                    echo "= result: $result"
                    echo "= startup messages: '$exec_msgs'"
                    returncode=1
                fi
            else
                msg="unable to start: no UI service port found"
                echo "! $msg"
                /sbin/write_log "[$(basename $0)] $msg" 1
                returncode=2
            fi
        else
            msg="unable to start: UI service port ($ui_port) already in use"
            echo "! $msg"
            /sbin/write_log "[$(basename $0)] $msg" 1
            returncode=2
        fi
    } | tee -a $INIT_LOG_PATHFILE

    return $returncode

    }

StopQPKG()
    {

    local maxwait=100

    ! QPKGIsActive && return

    killall $(basename $DAEMON)
    echo -n "* stopping ($QPKG_NAME) with SIGTERM: " | tee -a $INIT_LOG_PATHFILE; echo -n "waiting for upto $maxwait seconds: "

    while true; do
        while (ps ax | grep $DAEMON | grep -vq grep); do
            sleep 1
            ((acc++))
            echo -n "$acc, "

            if [[ $acc -ge $maxwait ]]; then
                echo -n "failed! " | tee -a $INIT_LOG_PATHFILE
                killall -9 $(basename $DAEMON)
                echo "sent SIGKILL." | tee -a $INIT_LOG_PATHFILE
                break 2
            fi
        done

        echo "OK"; echo "stopped OK in $acc seconds" >> $INIT_LOG_PATHFILE
        break
    done

    }

UIPort()
    {

    # get HTTP port
    # stdout = HTTP port (if used) or 0 if none found

    /sbin/getcfg '' ControlPort -d 0 -f $QPKG_INI_PATHFILE

    }

UIPortSecure()
    {

    # get HTTPS port
    # stdout = HTTPS port (if used) or 0 if none found

    if [[ $(/sbin/getcfg '' SecureControl -d no -f $QPKG_INI_PATHFILE) = yes ]]; then
        /sbin/getcfg '' SecurePort -d 0 -f $QPKG_INI_PATHFILE
    else
        echo 0
    fi

    }

PortAvailable()
    {

    # $1 = port to check
    # $? = 0 if available
    # $? = 1 if already used or unspecified

    if [[ -z $1 ]] || (/usr/sbin/lsof -i :$1 2>&1 >/dev/null); then
        return 1
    else
        return 0
    fi

    }

SessionSeparator()
    {

    # $1 = message

    printf '%0.s-' {1..20}; echo -n " $1 "; printf '%0.s-' {1..20}

    }

SysFilePresent()
    {

    # $1 = pathfile to check

    [[ -z $1 ]] && return 1

    if [[ ! -e $1 ]]; then
        echo "! A required NAS system file is missing [$1]"
        errorcode=1
        return 1
    else
        return 0
    fi

    }

WaitForEntware()
    {

    local TIMEOUT=300

    if [[ ! -e /opt/Entware.sh && ! -e /opt/Entware-3x.sh && ! -e /opt/Entware-ng.sh ]]; then
        (
            for ((count=1; count<=TIMEOUT; count++)); do
                sleep 1
                [[ -e /opt/Entware.sh || -e /opt/Entware-3x.sh || -e /opt/Entware-ng.sh ]] && { echo "waited for Entware for $count seconds" >> $INIT_LOG_PATHFILE; true; exit ;}
            done
            false
        )

        if [[ $? -ne 0 ]]; then
            echo "Entware not found! [TIMEOUT = $TIMEOUT seconds]" | tee -a $INIT_LOG_PATHFILE
            /sbin/write_log "[$(basename $0)] can't continue: Entware not found! (timeout)" 1
            false
            exit
        else
            # if here, then testfile has appeared, so reload environment
            . /etc/profile &>/dev/null
            . /root/.profile &>/dev/null
        fi
    fi

    }

Init

if [[ $errorcode -eq 0 ]]; then
    case $1 in
        start)
            echo -e "$(SessionSeparator 'start requested')\n= $(date)" >> $INIT_LOG_PATHFILE
            StartQPKG || errorcode=1
            ;;
        stop)
            echo -e "$(SessionSeparator 'stop requested')\n= $(date)" >> $INIT_LOG_PATHFILE
            StopQPKG || errorcode=1
            ;;
        restart)
            echo -e "$(SessionSeparator 'restart requested')\n= $(date)" >> $INIT_LOG_PATHFILE
            StopQPKG; StartQPKG || errorcode=1
            ;;
        *)
            echo "Usage: $0 {start|stop|restart}"
            ;;
    esac
fi

exit $errorcode