#!/usr/bin/env bash
#*<?dontedit?>
#* sherpa.manager.sh
#*  Copyright (C) 2017-2023 OneCD - one.cd.only@gmail.com
#* Project:
#*   https://git.io/sherpa
set -o nounset -o pipefail
readonly USER_ARGS_RAW=$*
readonly SCRIPT_STARTSECONDS=$(/bin/date +%s)
readonly PROJECT_BRANCH='main'
Self.Init()
{
DebugScriptFuncEn
readonly MANAGER_FILE=sherpa.manager.sh
local -r SCRIPT_VER='230207'
msg_pipe_fd=null
backup_stdin_fd=null
UpdateColourisation
IsQNAP || return
IsSU || return
ClaimLockFile /var/run/sherpa.lock || return
trap RunOnEXIT EXIT
trap RunOnSIGINT INT
[[ ! -e /dev/fd ]] && ln -s /proc/self/fd /dev/fd      
readonly OPKG_CMD=/opt/bin/opkg
readonly GNU_FIND_CMD=/opt/bin/find
readonly GNU_GREP_CMD=/opt/bin/grep
readonly GNU_LESS_CMD=/opt/bin/less
readonly GNU_SED_CMD=/opt/bin/sed
readonly GNU_SETTERM_CMD=/opt/bin/setterm
readonly GNU_STTY_CMD=/opt/bin/stty
readonly PYTHON_CMD=/opt/bin/python
readonly PYTHON3_CMD=/opt/bin/python3
readonly PIP_CMD="$PYTHON3_CMD -m pip"
readonly PERL_CMD=/opt/bin/perl
HideKeystrokes
HideCursor
readonly AWK_CMD=/bin/awk
readonly CAT_CMD=/bin/cat
readonly DATE_CMD=/bin/date
readonly DF_CMD=/bin/df
readonly GREP_CMD=/bin/grep
readonly LESS_CMD=/bin/less
readonly MD5SUM_CMD=/bin/md5sum
readonly MKNOD_CMD=/bin/mknod
readonly SED_CMD=/bin/sed
readonly SH_CMD=/bin/sh
readonly SLEEP_CMD=/bin/sleep
readonly TOUCH_CMD=/bin/touch
readonly UNAME_CMD=/bin/uname
readonly CURL_CMD=/sbin/curl
readonly GETCFG_CMD=/sbin/getcfg
readonly SETCFG_CMD=/sbin/setcfg
readonly BASENAME_CMD=/usr/bin/basename
readonly DIRNAME_CMD=/usr/bin/dirname
readonly DU_CMD=/usr/bin/du
readonly HEAD_CMD=/usr/bin/head
readonly READLINK_CMD=/usr/bin/readlink
readonly SORT_CMD=/usr/bin/sort
readonly TAIL_CMD=/usr/bin/tail
readonly TEE_CMD=/usr/bin/tee
readonly UNZIP_CMD=/usr/bin/unzip
readonly UPTIME_CMD=/usr/bin/uptime
readonly WC_CMD=/usr/bin/wc
IsSysFileExist $AWK_CMD || return
IsSysFileExist $CAT_CMD || return
IsSysFileExist $DATE_CMD || return
IsSysFileExist $DF_CMD || return
IsSysFileExist $GREP_CMD || return
IsSysFileExist $MD5SUM_CMD || return
IsSysFileExist $MKNOD_CMD || return
IsSysFileExist $SED_CMD || return
IsSysFileExist $SH_CMD || return
IsSysFileExist $SLEEP_CMD || return
IsSysFileExist $TOUCH_CMD || return
IsSysFileExist $UNAME_CMD || return
IsSysFileExist $CURL_CMD || return
IsSysFileExist $GETCFG_CMD || return
IsSysFileExist $SETCFG_CMD || return
IsSysFileExist $BASENAME_CMD || return
IsSysFileExist $DIRNAME_CMD || return
IsSysFileExist $DU_CMD || return
IsSysFileExist $HEAD_CMD || return
IsSysFileExist $READLINK_CMD || return
[[ ! -e $SORT_CMD ]] && ln -s /bin/busybox "$SORT_CMD" 
IsSysFileExist $TAIL_CMD || return
IsSysFileExist $TEE_CMD || return
IsSysFileExist $UNZIP_CMD || return
IsSysFileExist $UPTIME_CMD || return
IsSysFileExist $WC_CMD || return
readonly PROJECT_PATH=$(QPKG.InstallationPath)
readonly WORK_PATH=$PROJECT_PATH/cache
readonly LOGS_PATH=$PROJECT_PATH/logs
readonly QPKG_DL_PATH=$WORK_PATH/qpkgs.downloads
readonly IPK_DL_PATH=$WORK_PATH/ipks.downloads
readonly IPK_CACHE_PATH=$WORK_PATH/ipks
readonly PIP_CACHE_PATH=$WORK_PATH/pips
readonly BACKUP_PATH=$(GetDefVol)/.qpkg_config_backup
readonly ACTION_MSG_PIPE=/var/run/qpkg.messages.pipe
local -r MANAGER_ARCHIVE_FILE=${MANAGER_FILE%.*}.tar.gz
readonly MANAGER_ARCHIVE_PATHFILE=$WORK_PATH/$MANAGER_ARCHIVE_FILE
readonly MANAGER_PATHFILE=$WORK_PATH/$MANAGER_FILE
local -r OBJECTS_FILE=objects
local -r OBJECTS_ARCHIVE_FILE=$OBJECTS_FILE.tar.gz
readonly OBJECTS_ARCHIVE_URL=https://raw.githubusercontent.com/OneCDOnly/sherpa/$PROJECT_BRANCH/$OBJECTS_ARCHIVE_FILE
readonly OBJECTS_ARCHIVE_PATHFILE=$WORK_PATH/$OBJECTS_ARCHIVE_FILE
readonly OBJECTS_PATHFILE=$WORK_PATH/$OBJECTS_FILE
local -r PACKAGES_FILE=packages
local -r PACKAGES_ARCHIVE_FILE=$PACKAGES_FILE.tar.gz
local -r PACKAGES_ARCHIVE_URL=https://raw.githubusercontent.com/OneCDOnly/sherpa/$PROJECT_BRANCH/$PACKAGES_ARCHIVE_FILE
readonly PACKAGES_ARCHIVE_PATHFILE=$WORK_PATH/$PACKAGES_ARCHIVE_FILE
readonly PACKAGES_PATHFILE=$WORK_PATH/$PACKAGES_FILE
readonly EXTERNAL_PACKAGES_ARCHIVE_PATHFILE=/opt/var/opkg-lists/entware
readonly EXTERNAL_PACKAGES_PATHFILE=$WORK_PATH/Packages
readonly PREV_IPK_LIST=$WORK_PATH/ipk.prev.list
readonly PREV_PIP_LIST=$WORK_PATH/pip.prev.list
readonly SESS_ARCHIVE_PATHFILE=$LOGS_PATH/session.archive.log
sess_active_pathfile=$PROJECT_PATH/session.$$.active.log
readonly SESS_LAST_PATHFILE=$LOGS_PATH/session.last.log
readonly SESS_TAIL_PATHFILE=$LOGS_PATH/session.tail.log
readonly ACTIONS_LOG_PATHFILE=$LOGS_PATH/session.action.results.log
PACKAGE_TIERS=(Standalone Addon Dependent) 
PACKAGE_GROUPS=(All CanBackup CanRestartToUpdate Dependent HasDependents Installable Standalone Upgradable)    
PACKAGE_STATES=(BackedUp Cleaned Downloaded Enabled Installed Missing Reassigned Reinstalled Restarted Started Upgraded) 
PACKAGE_STATES_TRANSIENT=(Starting Stopping Restarting)                                                        
PACKAGE_ACTIONS=(Download Rebuild Reassign Backup Stop Disable Uninstall Upgrade Reinstall Install Restore Clean Enable Start Restart) 
PACKAGE_RESULTS=(Ok Unknown)
ACTION_RESULTS=(failed ok skipped)
readonly PACKAGE_TIERS
readonly PACKAGE_GROUPS
readonly PACKAGE_STATES
readonly PACKAGE_STATES_TRANSIENT
readonly PACKAGE_ACTIONS
readonly PACKAGE_RESULTS
readonly ACTION_RESULTS
local action=''
for action in "${PACKAGE_ACTIONS[@]}" check debug update; do
readonly "$(Uppercase "$action")"_LOG_FILE="$(Lowercase "$action")".log
done
[[ -d /root/.cache ]] && rm -rf /root/.cache
[[ -d /root/.local/share/virtualenv ]] && rm -rf /root/.local/share/virtualenv
[[ -d $IPK_DL_PATH ]] && rm -rf "$IPK_DL_PATH"
[[ -d $IPK_CACHE_PATH ]] && rm -rf "$IPK_CACHE_PATH"
[[ -d $PIP_CACHE_PATH ]] && rm -rf "$PIP_CACHE_PATH"
MakePath "$WORK_PATH" work || return
MakePath "$LOGS_PATH" logs || return
MakePath "$QPKG_DL_PATH" 'QPKG download' || return
MakePath "$IPK_DL_PATH" 'IPK download' || return
MakePath "$IPK_CACHE_PATH" 'IPK cache' || return
MakePath "$PIP_CACHE_PATH" 'PIP cache' || return
MakePath "$BACKUP_PATH" 'QPKG backup' || return
ArchivePriorSessLogs
local re=\\breset\\b       
if [[ $USER_ARGS_RAW =~ $re ]]; then
ResetArchivedLogs
ResetWorkPath
ArchiveActiveSessLog
ResetActiveSessLog
exit 0
fi
Objects.Load || return
if [[ -e $GNU_STTY_CMD && -t 0 ]]; then
local terminal_dimensions=$($GNU_STTY_CMD size)
readonly SESS_ROWS=${terminal_dimensions% *}
readonly SESS_COLS=${terminal_dimensions#* }
else
readonly SESS_ROWS=40
readonly SESS_COLS=156
fi
for re in \\bdebug\\b \\bdbug\\b \\bverbose\\b; do
if [[ $USER_ARGS_RAW =~ $re ]]; then
Display >&2
Self.Debug.ToScreen.Set
Self.Debug.ToFile.Set
Self.Debug.ToArchive.Set
ShowKeystrokes
ShowCursor
break
fi
done
readonly THIS_PACKAGE_VER=$(QPKG.Local.Ver)
readonly MANAGER_SCRIPT_VER="${SCRIPT_VER}$([[ $PROJECT_BRANCH = unstable ]] && echo '-alpha' || echo '-beta')"
DebugInfoMajSepr
DebugScript started "$($DATE_CMD -d @"$SCRIPT_STARTSECONDS" | tr -s ' ')"
DebugScript versions "QPKG: ${THIS_PACKAGE_VER:-unknown}, manager: ${MANAGER_SCRIPT_VER:-unknown}, loader: ${LOADER_SCRIPT_VER:-unknown}, objects: ${OBJECTS_VER:-unknown}"
DebugScript PID "$$"
DebugInfoMinSepr
DebugInfo 'Markers: (**) detected, (II) information, (WW) warning, (EE) error, (LL) log file, (--) processing,'
DebugInfo '(==) done, (>>) f entry, (<<) f exit, (vv) variable name & value, ($1) positional argument value'
DebugInfoMinSepr
Self.Summary.Set
readonly NAS_FIRMWARE_VER=$(GetFirmwareVer)
readonly NAS_FIRMWARE_BUILD=$(GetFirmwareBuild)
readonly NAS_FIRMWARE_DATE=$(GetFirmwareDate)
readonly NAS_RAM_KB=$(GetInstalledRAM)
readonly NAS_ARCH=$(GetArch)
readonly NAS_PLATFORM=$(GetPlatform)
readonly NAS_QPKG_ARCH=$(GetQPKGArch)
readonly ENTWARE_VER=$(GetEntwareType)
readonly CPU_CORES=$(GetCPUCores)
readonly CONCURRENCY=$CPU_CORES    
readonly LOG_TAIL_LINES=5000       
prev_msg=' '
fork_pid=''
[[ ${NAS_FIRMWARE_VER//.} -lt 426 ]] && curl_insecure_arg=' --insecure' || curl_insecure_arg=''
QPKG.IsInstalled Entware && [[ $ENTWARE_VER = none ]] && DebugAsWarn "$(FormatAsPackName Entware) appears to be installed but is not visible"
if [[ -z $USER_ARGS_RAW ]]; then
Opts.Help.Basic.Set
QPKGs.SkProc.Set
DisableDebugToArchiveAndFile
else
Packages.Load || return
ParseArgs
fi
EraseThisLine
if Self.Display.Clean.IsNt && Self.Debug.ToScreen.IsNt; then
Display "$(FormatAsTitle) $MANAGER_SCRIPT_VER • a mini-package-manager for QNAP NAS"
DisplayLineSpaceIfNoneAlready
fi
if ! QPKGs.Conflicts.Check; then
QPKGs.SkProc.Set
DebugScriptFuncEx 1; return
fi
QPKGs.Warnings.Check
if [[ $($GETCFG_CMD sherpa max_versions_cleared -d FALSE -f /etc/config/qpkg.conf) = FALSE ]]; then
$SED_CMD -i '/^FW_Ver_Max/d' /etc/config/qpkg.conf
$SETCFG_CMD sherpa max_versions_cleared TRUE -f /etc/config/qpkg.conf
fi
DebugScriptFuncEx
}
Self.LogEnv()
{
Self.ArgSuggests.Show
QPKGs.SkProc.IsSet && return
DebugScriptFuncEn
ShowAsProc environment
local -i max_width=70
local -i trimmed_width=$((max_width-3))
DebugInfoMinSepr
DebugHardwareOK model "$(get_display_name)"
DebugHardwareOK CPU "$(GetCPUInfo)"
DebugHardwareOK 'CPU cores' "$CPU_CORES"
DebugHardwareOK 'CPU architecture' "$NAS_ARCH"
DebugHardwareOK RAM "$(FormatAsThous "$NAS_RAM_KB")kiB"
DebugFirmwareOK OS "$(GetQnapOS)"
if [[ ${NAS_FIRMWARE_VER//.} -ge 400 ]]; then
DebugFirmwareOK version "$NAS_FIRMWARE_VER.$NAS_FIRMWARE_BUILD"
else
DebugFirmwareWarning version "$NAS_FIRMWARE_VER"
fi
if [[ $NAS_FIRMWARE_DATE -lt 20201015 || $NAS_FIRMWARE_DATE -gt 20201020 ]]; then  
DebugFirmwareOK 'build date' "$NAS_FIRMWARE_DATE"
else
DebugFirmwareWarning 'build date' "$NAS_FIRMWARE_DATE"
fi
DebugFirmwareOK kernel "$(GetKernel)"
DebugFirmwareOK platform "$NAS_PLATFORM"
DebugUserspaceOK 'OS uptime' "$(GetUptime)"
DebugUserspaceOK 'system load' "$(GetSysLoadAverages)"
if [[ $EUID -eq 0 ]]; then
DebugUserspaceOK '$EUID' "$EUID"
else
DebugUserspaceWarning '$EUID' "$EUID"
fi
DebugUserspaceOK '$SUDO_UID' "${SUDO_UID:-<undefined>}"
DebugUserspaceOK 'time in shell' "$(GetTimeInShell)"
DebugUserspaceOK '$BASH_VERSION' "$BASH_VERSION"
DebugUserspaceOK 'default volume' "$(GetDefVol)"
DebugUserspaceOK '/opt' "$($READLINK_CMD /opt || echo '<not present>')"
local public_share=$($GETCFG_CMD SHARE_DEF defPublic -d Qpublic -f /etc/config/def_share.info)
if [[ -L /share/$public_share ]]; then
DebugUserspaceOK "'$public_share' share" "/share/$public_share"
else
DebugUserspaceWarning "'$public_share' share" '<not present>'
fi
if [[ ${#PATH} -le $max_width ]]; then
DebugUserspaceOK '$PATH' "$PATH"
else
DebugUserspaceOK '$PATH' "${PATH:0:trimmed_width}..."
fi
DebugBinPathVerAndMinVer python "$(GetDefPythonVer)" "$MIN_PYTHON_VER"
DebugBinPathVerAndMinVer python3 "$(GetDefPython3Ver)" "$MIN_PYTHON_VER"
DebugBinPathVerAndMinVer perl "$(GetDefPerlVer)" "$MIN_PERL_VER"
DebugScript 'logs path' "$LOGS_PATH"
DebugScript 'work path' "$WORK_PATH"
DebugQPKG concurrency "$CONCURRENCY"
if OS.IsAllowUnsignedPackages; then
DebugQPKG 'allow unsigned' yes
else
if [[ ${NAS_FIRMWARE_VER//.} -lt 435 ]]; then
DebugQPKG 'allow unsigned' no
else
DebugQPKGWarning 'allow unsigned' no
fi
fi
DebugQPKG architecture "$NAS_QPKG_ARCH"
DebugQPKG 'Entware installer' "$ENTWARE_VER"
RunAndLog "$DF_CMD -h | $GREP_CMD '^Filesystem\|^none\|^tmpfs\|ram'" /var/log/ramdisks.freespace.log
QPKGs.States.Build
DebugScriptFuncEx
}
Self.IsAnythingToDo()
{
QPKGs.SkProc.IsSet && return
local action=''
local group=''
local state=''
local something_to_do=false
if Opts.Deps.Check.IsSet || Opts.Help.Status.IsSet; then
something_to_do=true
else
for action in "${PACKAGE_ACTIONS[@]}"; do
case $action in
Disable|Enable)
continue   
esac
if QPKGs.AcTo${action}.IsAny; then
something_to_do=true
break
fi
for group in "${PACKAGE_GROUPS[@]}"; do
if QPKGs.Ac${action}.Sc${group}.IsSet; then
something_to_do=true
break 2
fi
case $group in
All|CanBackup|CanRestartToUpdate|Dependent|HasDependents|Standalone)
continue   
esac
if QPKGs.Ac${action}.ScNt${group}.IsSet; then
something_to_do=true
break 2
fi
done
for state in "${PACKAGE_STATES[@]}"; do
if QPKGs.Ac${action}.Is${state}.IsSet; then
something_to_do=true
break 2
fi
case $state in
Missing|Reassigned)
continue   
esac
if QPKGs.Ac${action}.IsNt${state}.IsSet; then
something_to_do=true
break 2
fi
done
done
fi
if [[ $something_to_do = false ]]; then
ShowAsError "I've nothing to-do (the supplied arguments were incomplete, or didn't make sense)"
Opts.Help.Basic.Set
QPKGs.SkProc.Set
return 1
fi
return 0
}
Self.Validate()
{
QPKGs.SkProc.IsSet && return
DebugScriptFuncEn
ShowAsProc arguments
local avail_ver=''
local package=''
local action=''
local prospect=''
if Opts.Deps.Check.IsSet || QPKGs.AcToUpgrade.Exist Entware || QPKGs.AcToInstall.Exist Entware || QPKGs.AcToReinstall.Exist Entware; then
IPKs.Upgrade.Set
IPKs.Install.Set
PIPs.Install.Set
if QPKG.IsInstalled Entware && QPKG.IsEnabled Entware; then
if [[ -e $PYTHON3_CMD ]]; then
avail_ver=$(GetDefPython3Ver "$PYTHON3_CMD")
if [[ ${avail_ver//./} -lt $MIN_PYTHON_VER ]]; then
ShowAsInfo 'installed Python environment will be upgraded'
IPKs.AcToUninstall.Add 'python*'
fi
fi
if [[ -e $PERL_CMD ]]; then
avail_ver=$(GetDefPerlVer "$PERL_CMD")
if [[ ${avail_ver//./} -lt $MIN_PERL_VER ]]; then
ShowAsInfo 'installed Perl environment will be upgraded'
IPKs.AcToUninstall.Add 'perl*'
fi
fi
fi
fi
QPKGs.IsCanBackup.Build
QPKGs.IsCanRestartToUpdate.Build
QPKGs.IsCanClean.Build
AllocGroupPacksToAcs
if QPKGs.AcToRebuild.IsAny; then
for package in $(QPKGs.AcToRebuild.Array); do
QPKGs.AcToInstall.Add "$package"
QPKGs.AcToRestore.Add "$package"
QPKGs.AcToRebuild.Remove "$package"
done
fi
for action in Upgrade Reinstall Install; do
for package in $(QPKGs.AcTo${action}.Array); do
for prospect in $(QPKG.GetStandalones "$package"); do
QPKGs.AcToInstall.Add "$prospect"
done
done
done
for package in $(QPKGs.IsInstalled.Array); do
if QPKGs.IsStarted.Exist "$package" || QPKGs.AcToStart.Exist "$package"; then
for prospect in $(QPKG.GetStandalones "$package"); do
QPKGs.IsNtInstalled.Exist "$prospect" && QPKGs.AcToInstall.Add "$prospect"
done
fi
done
for package in $(QPKGs.AcToReinstall.Array) $(QPKGs.AcToRestart.Array); do
if QPKGs.ScStandalone.Exist "$package" && QPKGs.IsStarted.Exist "$package"; then
for prospect in $(QPKG.GetDependents "$package"); do
if QPKGs.IsStarted.Exist "$prospect"; then
QPKGs.AcToStop.Add "$prospect"
! QPKGs.AcToUninstall.Exist "$prospect" && ! QPKGs.AcToInstall.Exist "$prospect" && QPKGs.AcToStart.Add "$prospect"
fi
done
fi
done
for package in $(QPKGs.AcToStop.Array) $(QPKGs.AcToUninstall.Array); do
if QPKGs.ScStandalone.Exist "$package" && QPKGs.IsInstalled.Exist "$package"; then
for prospect in $(QPKG.GetDependents "$package"); do
QPKGs.IsStarted.Exist "$prospect" && QPKGs.AcToStop.Add "$prospect"
done
fi
done
for package in $(QPKGs.AcToUninstall.Array); do
if QPKGs.ScStandalone.Exist "$package" && QPKGs.IsInstalled.Exist "$package"; then
if QPKGs.AcToInstall.Exist "$package"; then
for prospect in $(QPKG.GetDependents "$package"); do
if QPKGs.IsStarted.Exist "$prospect"; then
QPKGs.AcToStop.Add "$prospect"
! QPKGs.AcToUninstall.Exist "$prospect" && ! QPKGs.AcToInstall.Exist "$prospect" && QPKGs.AcToStart.Add "$prospect"
fi
done
fi
fi
done
if QPKGs.AcToReinstall.Exist Entware; then   
QPKGs.AcToReinstall.Remove Entware
QPKGs.AcToUninstall.Add Entware
QPKGs.AcToInstall.Add Entware
fi
for action in Reinstall Install Start Restart; do
for package in $(QPKGs.AcTo${action}.Array); do
for prospect in $(QPKG.GetStandalones "$package"); do
QPKGs.IsNtStarted.Exist "$prospect" && QPKGs.AcToStart.Add "$prospect"
done
done
done
if QPKGs.AcUninstall.ScAll.IsSet; then
QPKGs.AcToStop.Init
else
QPKGs.AcToStop.Remove "$(QPKGs.AcToUninstall.Array)"
fi
for action in Upgrade Reinstall Install Start; do
QPKGs.AcToRestart.Remove "$(QPKGs.AcTo${action}.Array)"
done
QPKGs_were_installed_name=()
QPKGs_were_installed_path=()
if QPKGs.AcToUninstall.IsAny; then
for package in $(QPKGs.AcToUninstall.Array); do
if QPKGs.AcToInstall.Exist "$package"; then
QPKGs_were_installed_name+=("$package")
QPKGs_were_installed_path+=("$($DIRNAME_CMD "$(QPKG.InstallationPath "$package")")")
fi
done
fi
QPKGs.AcToDownload.Add "$(QPKGs.AcToUpgrade.Array) $(QPKGs.AcToReinstall.Array) $(QPKGs.AcToInstall.Array)"
if Opts.Deps.Check.IsSet; then
QPKGs.NewVers.Show
for package in $(QPKGs.ScDependent.Array); do
! QPKGs.ScUpgradable.Exist "$package" && QPKGs.IsStarted.Exist "$package" && QPKGs.ScCanRestartToUpdate.Exist "$package" && QPKGs.AcToRestart.Add "$package"
done
fi
[[ ! -L $PYTHON_CMD && -e $PYTHON3_CMD ]] && ln -s $PYTHON3_CMD $PYTHON_CMD
DebugScriptFuncEx
}
Actions.Proc()
{
QPKGs.SkProc.IsSet && return
DebugScriptFuncEn
local tier=''
local action=''
local -i tier_index=0
[[ -e $ACTIONS_LOG_PATHFILE ]] && rm "$ACTIONS_LOG_PATHFILE"
Action.Proc Reassign All QPKG AcToReassign reassign reassigning reassigned || return
Action.Proc Download All QPKG AcToDownload download downloading downloaded || return
Action.Proc Backup All QPKG AcToBackup backup backing-up backed-up || return
for ((tier_index=${#PACKAGE_TIERS[@]}-1; tier_index>=0; tier_index--)); do    
tier=${PACKAGE_TIERS[$tier_index]}
case $tier in
Standalone|Dependent)
Action.Proc Stop $tier QPKG AcToStop stop stopping stopped || return
Action.Proc Uninstall $tier QPKG AcToUninstall uninstall uninstalling uninstalled || return
esac
done
for tier in "${PACKAGE_TIERS[@]}"; do
case $tier in
Standalone|Dependent)
Action.Proc Upgrade $tier QPKG AcToUpgrade upgrade upgrading upgraded || return
Action.Proc Reinstall $tier QPKG AcToReinstall reinstall reinstalling reinstalled || return
Action.Proc Install $tier QPKG AcToInstall install installing installed || return
Action.Proc Restore $tier QPKG AcToRestore restore restoring restored || return
Action.Proc Clean $tier QPKG AcToClean clean cleaning cleaned || return
Action.Proc Start $tier QPKG AcToStart start starting started || return
Action.Proc Restart $tier QPKG AcToRestart restart restarting restarted || return
;;
Addon)
for action in Install Reinstall Upgrade Start; do
QPKGs.IsStarted.Exist Entware && IPKs.Upgrade.Set
QPKGs.AcTo${action}.IsAny && IPKs.Install.Set
done
if QPKGs.IsStarted.Exist Entware; then
ModPathToEntware
Action.Proc Upgrade $tier IPK '' upgrade upgrading upgraded || return
Action.Proc Install $tier IPK '' install installing installed || return
PIPs.Install.Set
Action.Proc Install $tier PIP '' install installing installed || return
fi
esac
done
EraseThisLine
if Self.Debug.ToFile.IsSet; then
IPKs.Actions.List
QPKGs.Actions.List
fi
Self.Debug.ToScreen.IsSet && QPKGs.States.List rebuild      
DebugScriptFuncEx
}
Action.Proc()
{
DebugScriptFuncEn
local target_function=''
local targets_function=''
local -r PACKAGE_TYPE=${3:?null}
local -r TARGET_ACTION=${1:?null}
case $PACKAGE_TYPE in
QPKG|IPK|PIP)
target_function=_${PACKAGE_TYPE}.${TARGET_ACTION}_
targets_function=${PACKAGE_TYPE}s.${TARGET_ACTION}
;;
*)
DebugAsError "unknown \$PACKAGE_TYPE: '$PACKAGE_TYPE'"
DebugScriptFuncEx 1; return
esac
total_count=0
local package=''
local state=''
local group=''
local msg1_key=''
local msg1_value=''
local msg2_key=''
local msg2_value=''
local -i package_index=0
local -a target_packages=()
local -r TIER=${2:?null}
local -r TARGET_OBJECT_NAME=${4:-}
local -r ACTION_INTRANSITIVE=${5:?null}
local -r ACTION_PRESENT=${6:?null}
local -r ACTION_PAST=${7:?null}
local original_colourful=$colourful
ShowAsProc "$ACTION_PRESENT $([[ $TIER != All ]] && Lowercase "$TIER ")${PACKAGE_TYPE}s"
case $PACKAGE_TYPE in
QPKG)
if [[ $TIER = All ]]; then 
target_packages=($(${PACKAGE_TYPE}s.$TARGET_OBJECT_NAME.Array))
else                       
for package in $(${PACKAGE_TYPE}s.$TARGET_OBJECT_NAME.Array); do
${PACKAGE_TYPE}s.Sc${TIER}.Exist "$package" && target_packages+=("$package")
done
fi
total_count=${#target_packages[@]}
DebugVar total_count
if [[ $total_count -eq 0 ]]; then
DebugInfo 'nothing to process'
DebugScriptFuncEx; return
fi
AdjustMaxForks "$TARGET_ACTION"
InitForkCounts
OpenActionMsgPipe
local re=\\bEntware\\b       
if [[ $TARGET_ACTION = Uninstall && ${target_packages[*]} =~ $re ]]; then
ShowKeystrokes 
ShowCursor
fi
_LaunchQPKGActionForks_ "$target_function" "${target_packages[@]}" &
fork_pid=$!
while [[ ${#target_packages[@]} -gt 0 ]]; do
IFS='#' read -r msg1_key msg1_value msg2_key msg2_value
case $msg1_key in
env)       
eval "$msg1_value"     
;;
change)    
while true; do
for group in "${PACKAGE_GROUPS[@]}"; do
case $msg1_value in
"Sc${group}")
QPKGs.ScNt${group}.Remove "$msg2_value"
QPKGs.Sc${group}.Add "$msg2_value"
break 2
;;
"ScNt${group}")
QPKGs.Sc${group}.Remove "$msg2_value"
QPKGs.ScNt${group}.Add "$msg2_value"
break 2
esac
done
for state in "${PACKAGE_STATES[@]}"; do
case $msg1_value in
"Is${state}")
QPKGs.IsNt${state}.Remove "$msg2_value"
QPKGs.Is${state}.Add "$msg2_value"
break 2
;;
"IsNt${state}")
QPKGs.Is${state}.Remove "$msg2_value"
QPKGs.IsNt${state}.Add "$msg2_value"
break 2
esac
done
DebugAsWarn "unidentified change in message queue: '$msg1_value'"
break
done
;;
status)    
case $msg1_value in
Ok)    
QPKGs.AcTo${TARGET_ACTION}.Remove "$msg2_value"
QPKGs.AcOk${TARGET_ACTION}.Add "$msg2_value"
((ok_count++))
;;
So)    
QPKGs.AcTo${TARGET_ACTION}.Remove "$msg2_value"
QPKGs.AcSo${TARGET_ACTION}.Add "$msg2_value"
((skip_ok_count++))
;;
Sk)    
QPKGs.AcTo${TARGET_ACTION}.Remove "$msg2_value"
QPKGs.AcSk${TARGET_ACTION}.Add "$msg2_value"
((skip_count++))
;;
Se)    
QPKGs.AcTo${TARGET_ACTION}.Remove "$msg2_value"
QPKGs.AcSe${TARGET_ACTION}.Add "$msg2_value"
((skip_error_count++))
;;
Er)    
QPKGs.AcTo${TARGET_ACTION}.Remove "$msg2_value"
QPKGs.AcEr${TARGET_ACTION}.Add "$msg2_value"
((fail_count++))
;;
Ex)    
for package_index in "${!target_packages[@]}"; do
if [[ ${target_packages[package_index]} = "$msg2_value" ]]; then
unset 'target_packages[package_index]'
break
fi
done
;;
*)
DebugAsWarn "unidentified status in message queue: '$msg1_value'"
esac
;;
*)
DebugAsWarn "unidentified key in message queue: '$msg1_key'"
esac
done <&$msg_pipe_fd
[[ $ok_count -gt 0 ]] && Opts.Help.Ok.Set
[[ $skip_count -gt 0 || $skip_error_count -gt 0 ]] && Opts.Help.Skipped.Set
[[ $fail_count -gt 0 ]] && Opts.Help.Failed.Set
[[ ${#target_packages[@]} -gt 0 ]] && KillActiveFork       
wait 2>/dev/null
CloseActionMsgPipe
;;
IPK|PIP)
InitForkCounts
$targets_function      
esac
if [[ $original_colourful = true && $colourful = false ]]; then
colourful=true
ShowAsActionResult "$TIER" "$PACKAGE_TYPE" "$ok_count" "$total_count" "$ACTION_PAST"
colourful=false
else
ShowAsActionResult "$TIER" "$PACKAGE_TYPE" "$ok_count" "$total_count" "$ACTION_PAST"
fi
case $PACKAGE_TYPE in
QPKG)
ShowAsActionResultDetail "$TARGET_ACTION"
esac
EraseForkCountPaths
DebugScriptFuncEx
Self.Error.IsNt
}
OpenActionMsgPipe()
{
[[ -p $ACTION_MSG_PIPE ]] && rm "$ACTION_MSG_PIPE"
[[ ! -p $ACTION_MSG_PIPE ]] && mknod "$ACTION_MSG_PIPE" p
backup_stdin_fd=$(FindNextFD)
DebugVar backup_stdin_fd
eval "exec $backup_stdin_fd>&0"
msg_pipe_fd=$(FindNextFD)
DebugVar msg_pipe_fd
[[ $msg_pipe_fd != null ]] && eval "exec $msg_pipe_fd<>$ACTION_MSG_PIPE"
}
CloseActionMsgPipe()
{
[[ $backup_stdin_fd != null ]] && eval "exec 0>&$backup_stdin_fd"
[[ $backup_stdin_fd != null ]] && eval "exec $backup_stdin_fd>&-"
[[ $msg_pipe_fd != null ]] && eval "exec $msg_pipe_fd>&-"
[[ -p $ACTION_MSG_PIPE ]] && rm "$ACTION_MSG_PIPE"
}
AdjustMaxForks()
{
max_forks=$CONCURRENCY
if Self.Debug.ToScreen.IsSet; then
max_forks=1
DebugInfo "limiting \$max_forks to $max_forks because debug mode is active"
else
case ${1:-} in
Clean)                     
max_forks=$(((max_forks+1)/2))
DebugInfo "limiting \$max_forks to $max_forks because '$(Lowercase "$1")' action was requested"
;;
Install|Reinstall|Upgrade) 
max_forks=1
DebugInfo "limiting \$max_forks to $max_forks because '$(Lowercase "$1")' action was requested"
esac
fi
DebugVar max_forks
}
Self.Results()
{
display_last_action_datetime=false
Opts.Deps.Check.IsSet && ShowAsDone 'check OK'
if Args.Unknown.IsNone; then
if Opts.Help.Abbreviations.IsSet; then
Help.PackageAbbreviations.Show
elif Opts.Help.Actions.IsSet; then
Help.Actions.Show
elif Opts.Help.ActionsAll.IsSet; then
Help.ActionsAll.Show
elif Opts.Help.Backups.IsSet; then
QPKGs.Backups.Show
elif Opts.Help.Groups.IsSet; then
Help.Groups.Show
elif Opts.Help.Options.IsSet; then
Help.Options.Show
elif Opts.Help.Packages.IsSet; then
Help.Packages.Show
elif Opts.Help.Problems.IsSet; then
Help.Problems.Show
elif Opts.Help.Repos.IsSet; then
QPKGs.NewVers.Show
QPKGs.Repos.Show
elif Opts.Help.Results.IsSet; then
display_last_action_datetime=true
Opts.Help.Ok.Set
Opts.Help.Skipped.Set
Opts.Help.Failed.Set
elif Opts.Help.Status.IsSet; then
QPKGs.NewVers.Show
QPKGs.Statuses.Show
elif Opts.Help.Tips.IsSet; then
Help.Tips.Show
fi
if Opts.Log.Last.Paste.IsSet; then
Log.Last.Paste
elif Opts.Log.Last.View.IsSet; then
ReleaseLockFile
Log.Last.View
elif Opts.Log.Tail.Paste.IsSet; then
Log.Tail.Paste
elif Opts.Log.Tail.View.IsSet; then
ReleaseLockFile
Log.Tail.View
elif Opts.Vers.View.IsSet; then
Self.Vers.Show
fi
if QPKGs.List.IsBackedUp.IsSet; then
QPKGs.IsBackedUp.Show
elif QPKGs.List.IsNtBackedUp.IsSet; then
QPKGs.IsNtBackedUp.Show
elif QPKGs.List.IsInstalled.IsSet; then
QPKGs.IsInstalled.Show
elif QPKGs.List.IsNtInstalled.IsSet; then
QPKGs.IsNtInstalled.Show
elif QPKGs.List.IsStarted.IsSet; then
QPKGs.IsStarted.Show
elif QPKGs.List.IsNtStarted.IsSet; then
QPKGs.IsNtStarted.Show
elif QPKGs.List.ScInstallable.IsSet; then
QPKGs.ScInstallable.Show
elif QPKGs.List.ScUpgradable.IsSet; then
QPKGs.ScUpgradable.Show
elif QPKGs.List.ScStandalone.IsSet; then
QPKGs.ScStandalone.Show
elif QPKGs.List.ScDependent.IsSet; then
QPKGs.ScDependent.Show
fi
fi
if Opts.Help.Basic.IsSet; then
Help.Basic.Show
Help.Basic.Example.Show
fi
Opts.Help.Ok.IsSet && Actions.Results.Show ok
Opts.Help.Skipped.IsSet && Actions.Results.Show skipped
Opts.Help.Failed.IsSet && Actions.Results.Show failed
Self.ShowBackupLoc.IsSet && Help.BackupLocation.Show
Self.Summary.IsSet && ShowSummary
Self.SuggestIssue.IsSet && Help.Issue.Show
DebugInfoMinSepr
DebugScript finished "$($DATE_CMD)"
DebugScript 'elapsed time' "$(FormatSecsToHoursMinutesSecs "$(($($DATE_CMD +%s)-SCRIPT_STARTSECONDS))")"
DebugInfoMajSepr
Self.Debug.ToArchive.IsSet && ArchiveActiveSessLog
ResetActiveSessLog
EraseThisLine
DisplayLineSpaceIfNoneAlready  
return 0
}
ParseArgs()
{
DebugScriptFuncEn
DebugVar USER_ARGS_RAW
local user_args_fixed=$(Lowercase "${USER_ARGS_RAW//,/ }")
local -a user_args=(${user_args_fixed/--/})
local arg=''
local arg_identified=false
local action=''
local action_force=false
local group=''
local group_identified=false
local package=''
for arg in "${user_args[@]}"; do
arg_identified=false
case $arg in
backup|clean|reassign|rebuild|reinstall|restart|restore|start|stop)
action=${arg}_
arg_identified=true
group=''
group_identified=false
Self.Display.Clean.UnSet
QPKGs.SkProc.UnSet
;;
paste)
action=paste_
arg_identified=true
group=''
group_identified=false
Self.Display.Clean.UnSet
QPKGs.SkProc.Set
;;
add|install)
action=install_
arg_identified=true
group=''
group_identified=false
Self.Display.Clean.UnSet
QPKGs.SkProc.UnSet
;;
c|check)
action=check_
arg_identified=true
group=''
group_identified=false
Self.Display.Clean.UnSet
QPKGs.SkProc.UnSet
;;
display|help|list|show|view)
action=help_
arg_identified=true
group=''
group_identified=false
Self.Display.Clean.UnSet
QPKGs.SkProc.Set
;;
rm|remove|uninstall)
action=uninstall_
arg_identified=true
group=''
group_identified=false
Self.Display.Clean.UnSet
QPKGs.SkProc.UnSet
;;
s|status|statuses)
action=status_
arg_identified=true
group=''
group_identified=false
Self.Display.Clean.UnSet
QPKGs.SkProc.Set
;;
update|upgrade)
action=upgrade_
arg_identified=true
group=''
group_identified=false
Self.Display.Clean.UnSet
QPKGs.SkProc.UnSet
esac
if [[ -z $action ]]; then
case $arg in
a|abs|action|actions|actions-all|all-actions|b|backups|dependent|dependents|failed|groups|installable|installed|l|last|log|missing|not-installed|ok|option|options|p|package|packages|problems|r|repo|repos|results|skipped|standalone|standalones|started|stopped|tail|tips|updatable|updateable|upgradable|v|version|versions|whole)
action=help_
arg_identified=true
group=''
group_identified=false
QPKGs.SkProc.Set
esac
DebugVar action
fi
if [[ -n $action ]]; then
case $arg in
backedup|failed|installable|installed|missing|not-backedup|not-installed|ok|problems|results|skipped|started|stopped|tail|tips)
group=${arg}_
;;
a|abs)
group=abs_
;;
actions-all|all-actions)
group=all-actions_
;;
action|actions)
group=actions_
;;
all|entire|everything)
group=all_
;;
b|backups)
group=backups_
;;
dependent|dependents)
group=dependent_
;;
group|groups)
group=groups_
;;
l|last)
group=last_
;;
log|whole)
group=log_
;;
option|options)
group=options_
;;
p|package|packages)
group=packages_
;;
r|repo|repos)
group=repos_
;;
standalone|standalones)
group=standalone_
;;
updatable|updateable|upgradable)
group=upgradable_
;;
v|version|versions)
group=versions_
esac
if [[ -n $group ]]; then
group_identified=true
arg_identified=true
fi
fi
case $arg in
debug|verbose)
Self.Debug.ToScreen.Set
arg_identified=true
group_identified=true
;;
force)
action_force=true
arg_identified=true
esac
package=$(QPKG.MatchAbbrv "$arg")
if [[ -n $package ]]; then
group_identified=true
arg_identified=true
fi
[[ $arg_identified = false ]] && Args.Unknown.Add "$arg"
case $action in
backup_)
case $group in
all_)
QPKGs.AcBackup.ScAll.Set
group=''
;;
dependent_)
QPKGs.AcBackup.ScDependent.Set
group=''
;;
installed_)
QPKGs.AcBackup.IsInstalled.Set
group=''
;;
standalone_)
QPKGs.AcBackup.ScStandalone.Set
group=''
;;
started_)
QPKGs.AcBackup.IsStarted.Set
group=''
;;
stopped_)
QPKGs.AcBackup.IsNtStarted.Set
group=''
;;
*)
QPKGs.AcToBackup.Add "$package"
esac
;;
check_)
Opts.Deps.Check.Set
;;
clean_)
case $group in
all_)
QPKGs.AcClean.ScAll.Set
group=''
;;
dependent_)
QPKGs.AcClean.ScDependent.Set
group=''
;;
installed_)
QPKGs.AcClean.IsInstalled.Set
group=''
;;
standalone_)
QPKGs.AcClean.ScStandalone.Set
group=''
;;
started_)
QPKGs.AcClean.IsStarted.Set
group=''
;;
stopped_)
QPKGs.AcClean.IsNtStarted.Set
group=''
;;
*)
QPKGs.AcToClean.Add "$package"
esac
;;
help_)
case $group in
abs_)
Opts.Help.Abbreviations.Set
;;
actions_)
Opts.Help.Actions.Set
;;
all-actions_|all_)
Opts.Help.ActionsAll.Set
;;
backedup_)
QPKGs.List.IsBackedUp.Set
Self.Display.Clean.Set
;;
backups_)
Opts.Help.Backups.Set
;;
dependent_)
QPKGs.List.ScDependent.Set
Self.Display.Clean.Set
;;
failed_)
Opts.Help.Failed.Set
;;
groups_)
Opts.Help.Groups.Set
;;
installable_)
QPKGs.List.ScInstallable.Set
Self.Display.Clean.Set
;;
installed_)
QPKGs.List.IsInstalled.Set
Self.Display.Clean.Set
;;
last_)
Opts.Log.Last.View.Set
Self.Display.Clean.Set
;;
log_)
Opts.Log.Tail.View.Set
Self.Display.Clean.Set
;;
not-backedup_)
QPKGs.List.IsNtBackedUp.Set
Self.Display.Clean.Set
;;
not-installed_)
QPKGs.List.IsNtInstalled.Set
Self.Display.Clean.Set
;;
ok_)
Opts.Help.Ok.Set
;;
options_)
Opts.Help.Options.Set
;;
packages_)
Opts.Help.Packages.Set
;;
problems_)
Opts.Help.Problems.Set
;;
repos_)
Opts.Help.Repos.Set
;;
results_)
Opts.Help.Results.Set
;;
skipped_)
Opts.Help.Skipped.Set
;;
standalone_)
QPKGs.List.ScStandalone.Set
Self.Display.Clean.Set
;;
started_)
QPKGs.List.IsStarted.Set
Self.Display.Clean.Set
;;
status_)
Opts.Help.Status.Set
;;
stopped_)
QPKGs.List.IsNtStarted.Set
Self.Display.Clean.Set
;;
tips_)
Opts.Help.Tips.Set
;;
upgradable_)
QPKGs.List.ScUpgradable.Set
Self.Display.Clean.Set
;;
versions_)
Opts.Vers.View.Set
Self.Display.Clean.Set
esac
QPKGs.SkProc.Set
;;
install_)
case $group in
all_)
QPKGs.AcInstall.ScAll.Set
group=''
;;
dependent_)
QPKGs.AcInstall.ScDependent.Set
group=''
;;
installable_)
QPKGs.AcInstall.ScInstallable.Set
group=''
;;
installed_)
QPKGs.AcInstall.IsInstalled.Set
group=''
;;
missing_)
QPKGs.AcInstall.IsMissing.Set
group=''
;;
not-installed_)
QPKGs.AcInstall.IsNtInstalled.Set
group=''
;;
standalone_)
QPKGs.AcInstall.ScStandalone.Set
group=''
;;
started_)
QPKGs.AcInstall.IsStarted.Set
group=''
;;
*)
QPKGs.AcToInstall.Add "$package"
esac
;;
paste_)
case $group in
all_|log_|tail_)
Opts.Log.Tail.Paste.Set
action=''
;;
last_)
action=''
Opts.Log.Last.Paste.Set
esac
QPKGs.SkProc.Set
;;
reassign_)
case $group in
all_)
QPKGs.AcReassign.ScAll.Set
group=''
;;
dependent_)
QPKGs.AcReassign.ScDependent.Set
group=''
;;
installed_)
QPKGs.AcReassign.IsInstalled.Set
group=''
;;
standalone_)
QPKGs.AcReassign.ScStandalone.Set
group=''
;;
started_)
QPKGs.AcReassign.IsStarted.Set
group=''
;;
stopped_)
QPKGs.AcReassign.IsNtStarted.Set
group=''
;;
upgradable_)
QPKGs.AcReassign.IsUpgradable.Set
group=''
;;
*)
QPKGs.AcToReassign.Add "$package"
esac
;;
rebuild_)
case $group in
all_)
QPKGs.AcRebuild.ScAll.Set
group=''
;;
dependent_)
QPKGs.AcRebuild.ScDependent.Set
group=''
;;
installed_)
QPKGs.AcRebuild.IsInstalled.Set
group=''
;;
standalone_)
QPKGs.AcRebuild.ScStandalone.Set
group=''
;;
*)
QPKGs.AcToRebuild.Add "$package"
esac
;;
reinstall_)
case $group in
all_)
QPKGs.AcReinstall.ScAll.Set
group=''
;;
dependent_)
QPKGs.AcReinstall.ScDependent.Set
group=''
;;
installed_)
QPKGs.AcReinstall.IsInstalled.Set
group=''
;;
standalone_)
QPKGs.AcReinstall.ScStandalone.Set
group=''
;;
started_)
QPKGs.AcReinstall.IsStarted.Set
group=''
;;
stopped_)
QPKGs.AcReinstall.IsNtStarted.Set
group=''
;;
upgradable_)
QPKGs.AcReinstall.IsUpgradable.Set
group=''
;;
*)
QPKGs.AcToReinstall.Add "$package"
esac
;;
restart_)
case $group in
all_)
QPKGs.AcRestart.ScAll.Set
group=''
;;
dependent_)
QPKGs.AcRestart.ScDependent.Set
group=''
;;
installed_)
QPKGs.AcRestart.IsInstalled.Set
group=''
;;
standalone_)
QPKGs.AcRestart.ScStandalone.Set
group=''
;;
started_)
QPKGs.AcRestart.IsStarted.Set
group=''
;;
stopped_)
QPKGs.AcRestart.IsNtStarted.Set
group=''
;;
upgradable_)
QPKGs.AcRestart.IsUpgradable.Set
group=''
;;
*)
QPKGs.AcToRestart.Add "$package"
esac
;;
restore_)
case $group in
all_)
QPKGs.AcRestore.ScAll.Set
group=''
;;
dependent_)
QPKGs.AcRestore.ScDependent.Set
group=''
;;
installed_)
QPKGs.AcRestore.IsInstalled.Set
group=''
;;
standalone_)
QPKGs.AcRestore.ScStandalone.Set
group=''
;;
started_)
QPKGs.AcRestore.IsStarted.Set
group=''
;;
stopped_)
QPKGs.AcRestore.IsNtStarted.Set
group=''
;;
upgradable_)
QPKGs.AcRestore.IsUpgradable.Set
group=''
;;
*)
QPKGs.AcToRestore.Add "$package"
esac
;;
start_)
case $group in
all_)
QPKGs.AcStart.ScAll.Set
group=''
;;
dependent_)
QPKGs.AcStart.ScDependent.Set
group=''
;;
installed_)
QPKGs.AcStart.IsInstalled.Set
group=''
;;
standalone_)
QPKGs.AcStart.ScStandalone.Set
group=''
;;
stopped_)
QPKGs.AcStart.IsNtStarted.Set
group=''
;;
upgradable_)
QPKGs.AcStart.IsUpgradable.Set
group=''
;;
*)
QPKGs.AcToStart.Add "$package"
esac
;;
status_)
Opts.Help.Status.Set
QPKGs.SkProc.Set
;;
stop_)
case $group in
all_)
QPKGs.AcStop.ScAll.Set
group=''
;;
dependent_)
QPKGs.AcStop.ScDependent.Set
group=''
;;
installed_)
QPKGs.AcStop.IsInstalled.Set
group=''
;;
standalone_)
QPKGs.AcStop.ScStandalone.Set
group=''
;;
started_)
QPKGs.AcStop.IsStarted.Set
group=''
;;
upgradable_)
QPKGs.AcStop.IsUpgradable.Set
group=''
;;
*)
QPKGs.AcToStop.Add "$package"
esac
;;
uninstall_)
case $group in
all_)  
if [[ $action_force = true ]]; then
QPKGs.AcUninstall.ScAll.Set
group=''
action_force=false
fi
;;
dependent_)
QPKGs.AcUninstall.ScDependent.Set
group=''
action_force=false
;;
installed_)  
if [[ $action_force = true ]]; then
QPKGs.AcUninstall.IsInstalled.Set
group=''
action_force=false
fi
;;
standalone_)
QPKGs.AcUninstall.ScStandalone.Set
group=''
action_force=false
;;
started_)
QPKGs.AcUninstall.IsStarted.Set
group=''
action_force=false
;;
stopped_)
QPKGs.AcUninstall.IsNtStarted.Set
group=''
action_force=false
;;
upgradable_)
QPKGs.AcUninstall.IsUpgradable.Set
group=''
action_force=false
;;
*)
QPKGs.AcToUninstall.Add "$package"
esac
;;
upgrade_)
case $group in
all_)
QPKGs.AcUpgrade.ScAll.Set
group=''
;;
dependent_)
QPKGs.AcUpgrade.ScDependent.Set
group=''
;;
installed_)
QPKGs.AcUpgrade.IsInstalled.Set
group=''
;;
standalone_)
QPKGs.AcUpgrade.ScStandalone.Set
group=''
;;
started_)
QPKGs.AcUpgrade.IsStarted.Set
group=''
;;
stopped_)
QPKGs.AcUpgrade.IsNtStarted.Set
group=''
;;
upgradable_)
QPKGs.AcUpgrade.ScUpgradable.Set
group=''
;;
*)
QPKGs.AcToUpgrade.Add "$package"
esac
esac
done
if [[ -n $action && $group_identified = false ]]; then
case $action in
help_|paste_)
Opts.Help.Basic.Set
esac
fi
if Args.Unknown.IsAny; then
Opts.Help.Basic.Set
QPKGs.SkProc.Set
Self.Display.Clean.UnSet
fi
DebugScriptFuncEx
}
Self.ArgSuggests.Show()
{
DebugScriptFuncEn
local arg=''
if Args.Unknown.IsAny; then
ShowAsError "unknown argument$(Pluralise "$(Args.Unknown.Count)"): \"$(Args.Unknown.List)\". Please check the argument list again"
for arg in $(Args.Unknown.Array); do
case $arg in
all)
DisplayAsProjSynExam "please provide a valid $(FormatAsAction) before 'all' like" 'start all'
Opts.Help.Basic.UnSet
;;
all-backup|backup-all)
DisplayAsProjSynExam 'to backup all installed package configurations, use' 'backup all'
Opts.Help.Basic.UnSet
;;
dependent)
DisplayAsProjSynExam "please provide a valid $(FormatAsAction) before 'dependent' like" 'start dependents'
Opts.Help.Basic.UnSet
;;
all-restart|restart-all)
DisplayAsProjSynExam 'to restart all packages, use' 'restart all'
Opts.Help.Basic.UnSet
;;
all-restore|restore-all)
DisplayAsProjSynExam 'to restore all installed package configurations, use' 'restore all'
Opts.Help.Basic.UnSet
;;
standalone)
DisplayAsProjSynExam "please provide a valid $(FormatAsAction) before 'standalone' like" 'start standalones'
Opts.Help.Basic.UnSet
;;
all-start|start-all)
DisplayAsProjSynExam 'to start all packages, use' 'start all'
Opts.Help.Basic.UnSet
;;
all-stop|stop-all)
DisplayAsProjSynExam 'to stop all packages, use' 'stop all'
Opts.Help.Basic.UnSet
;;
all-uninstall|all-remove|uninstall-all|remove-all)
DisplayAsProjSynExam 'to uninstall all packages, use' 'force uninstall all'
Opts.Help.Basic.UnSet
;;
all-upgrade|upgrade-all)
DisplayAsProjSynExam 'to upgrade all packages, use' 'upgrade all'
Opts.Help.Basic.UnSet
esac
done
fi
DebugScriptFuncEx
}
AllocGroupPacksToAcs()
{
DebugScriptFuncEn
local action=''
local group=''
local state=''
local prospect=''
local found=false      
for action in "${PACKAGE_ACTIONS[@]}"; do
[[ $action = Enable || $action = Disable ]] && continue    
for group in "${PACKAGE_GROUPS[@]}"; do
found=false
if QPKGs.Ac${action}.Sc${group}.IsSet; then
case $action in
Clean)
case $group in
All|Dependent|Standalone)
found=true
for prospect in $(QPKGs.Sc${group}.Array); do
QPKG.IsCanClean "$prospect" && QPKGs.AcTo${action}.Add "$prospect"
done
;;
*)
DebugAsWarn "specified group $group has no handler for specifed action $action"
esac
;;
Install)
case $group in
All|Dependent|Standalone)
found=true
QPKGs.AcTo${action}.Add "$(QPKGs.Sc${group}.Array)"
;;
*)
DebugAsWarn "specified group $group has no handler for specifed action $action"
esac
;;
Restart|Start|Stop|Uninstall)
case $group in
All|Dependent|Standalone)
found=true
for prospect in $(QPKGs.Sc${group}.Array); do
QPKGs.IsInstalled.Exist "$prospect" && QPKGs.AcTo${action}.Add "$prospect"
done
;;
*)
DebugAsWarn "specified group $group has no handler for specifed action $action"
esac
;;
Rebuild)
case $group in
All|Dependent|Standalone)
found=true
for prospect in $(QPKGs.Sc${group}.Array); do
QPKGs.ScCanBackup.Exist "$prospect" && QPKGs.AcTo${action}.Add "$prospect"
done
;;
*)
DebugAsWarn "specified group $group has no handler for specifed action $action"
esac
;;
Upgrade)
case $group in
All|Dependent|Standalone)
found=true
QPKGs.AcTo${action}.Add "$(QPKGs.ScUpgradable.Array)"
for prospect in $(QPKGs.Sc${group}.Array); do
QPKGs.ScCanRestartToUpdate.Exist "$prospect" && QPKGs.AcTo${action}.Add "$prospect"
done
QPKGs.AcToRestart.Remove "$(QPKGs.AcToUpgrade.Array)"
;;
*)
DebugAsWarn "specified group $group has no handler for specifed action $action"
esac
esac
if [[ $found = false ]]; then
QPKGs.AcTo${action}.Add "$(QPKGs.Sc${group}.Array)"
fi
if QPKGs.AcTo${action}.IsAny; then
DebugAsDone "action: '$action', group: '$group': found $(QPKGs.AcTo${action}.Count) package$(Pluralise "$(QPKGs.AcTo${action}.Count)") to process"
else
ShowAsWarn "unable to find any packages to $(Lowercase "$action")"
fi
fi
case $group in
All|CanBackup|CanRestartToUpdate|Dependent|HasDependents|Standalone|Missing|Reassigned)
continue
esac
if QPKGs.Ac${action}.ScNt${group}.IsSet; then
if [[ $found = false ]]; then
QPKGs.AcTo${action}.Add "$(QPKGs.ScNt${group}.Array)"
fi
if QPKGs.AcTo${action}.IsAny; then
DebugAsDone "action: '$action', group: 'Nt${group}': found $(QPKGs.AcTo${action}.Count) package$(Pluralise "$(QPKGs.AcTo${action}.Count)") to process"
else
ShowAsWarn "unable to find any packages to $(Lowercase "$action")"
fi
fi
done
for state in "${PACKAGE_STATES[@]}"; do
found=false
if QPKGs.Ac${action}.Is${state}.IsSet; then
case $action in
Backup|Clean|Uninstall|Upgrade)
case $state in
BackedUp|Cleaned|Downloaded|Enabled|Installed|Started|Upgradable)
found=true
QPKGs.AcTo${action}.Add "$(QPKGs.Is${state}.Array)"
;;
Stopped)
found=true
QPKGs.AcTo${action}.Add "$(QPKGs.IsNtStarted.Array)"
esac
;;
Install)
case $state in
Enabled|Installed|Started|Stopped)
found=true
esac
esac
if [[ $found = false ]]; then
QPKGs.AcTo${action}.Add "$(QPKGs.Is${state}.Array)"
fi
if QPKGs.AcTo${action}.IsAny; then
DebugAsDone "action: '$action', state: '$state': found $(QPKGs.AcTo${action}.Count) package$(Pluralise "$(QPKGs.AcTo${action}.Count)") to process"
else
ShowAsWarn "unable to find any packages to $(Lowercase "$action")"
fi
fi
case $state in
Missing|Reassigned)
continue
esac
if QPKGs.Ac${action}.IsNt${state}.IsSet; then
case $action in
Backup|Clean|Install|Start|Uninstall)
case $state in
Installed|Started)
found=true
QPKGs.AcTo${action}.Add "$(QPKGs.IsNt${state}.Array)"
;;
Stopped)
found=true
QPKGs.AcTo${action}.Add "$(QPKGs.IsStarted.Array)"
esac
esac
if [[ $found = false ]]; then
QPKGs.AcTo${action}.Add "$(QPKGs.IsNt${state}.Array)"
fi
if QPKGs.AcTo${action}.IsAny; then
DebugAsDone "action: '$action', state: 'Nt${state}': found $(QPKGs.AcTo${action}.Count) package$(Pluralise "$(QPKGs.AcTo${action}.Count)") to process"
else
ShowAsWarn "unable to find any packages to $(Lowercase "$action")"
fi
fi
done
done
DebugScriptFuncEx
}
ResetArchivedLogs()
{
if [[ -n $LOGS_PATH && -d $LOGS_PATH ]]; then
rm -rf "${LOGS_PATH:?}"/*
ShowAsDone 'all logs cleared'
fi
return 0
}
ResetWorkPath()
{
if [[ -n $WORK_PATH && -d $WORK_PATH ]]; then
rm -rf "${WORK_PATH:?}"/*
ShowAsDone 'package cache cleared'
fi
return 0
}
Quiz()
{
local prompt=${1:?null}
local response=''
ShowAsQuiz "$prompt"
[[ -e $GNU_STTY_CMD && -t 0 ]] && $GNU_STTY_CMD igncr      
read -rn1 response
[[ -e $GNU_STTY_CMD && -t 0 ]] && $GNU_STTY_CMD -igncr     
DebugVar response
ShowAsQuizDone "$prompt: $response"
case ${response:0:1} in
y|Y)
return 0
;;
*)
return 1
esac
}
PatchEntwareService()
{
local -r TAB=$'\t'
local -r PREFIX='# the following line was inserted by sherpa: https://git.io/sherpa'
local -r PACKAGE_INIT_PATHFILE=$(QPKG.ServicePathFile Entware)
local find=''
local insert=''
if $GREP_CMD -q 'opt.orig' "$PACKAGE_INIT_PATHFILE"; then
DebugInfo 'patch: do the "/opt shuffle" - already done'
else
find='# sym-link $QPKG_DIR to /opt'
insert='opt_path="/opt"; opt_backup_path="/opt.orig"; [[ -d "$opt_path" \&\& ! -L "$opt_path" \&\& ! -e "$opt_backup_path" ]] \&\& mv "$opt_path" "$opt_backup_path"'
$SED_CMD -i "s|$find|$find\n\n${TAB}${PREFIX}\n${TAB}${insert}\n|" "$PACKAGE_INIT_PATHFILE"
find='/bin/ln -sf $QPKG_DIR /opt'
insert='[[ -L "$opt_path" \&\& -d "$opt_backup_path" ]] \&\& cp "$opt_backup_path"/* --target-directory "$opt_path" \&\& rm -r "$opt_backup_path"'
$SED_CMD -i "s|$find|$find\n\n${TAB}${PREFIX}\n${TAB}${insert}\n|" "$PACKAGE_INIT_PATHFILE"
DebugAsDone 'patch: do the "opt shuffle"'
fi
return 0
}
UpdateEntwarePackageList()
{
if IsNtSysFileExist $OPKG_CMD; then
DisplayAsProjSynExam 'try restarting Entware' 'restart ew'
return 1
fi
[[ ${ENTWARE_PACKAGE_LIST_UPTODATE:-false} = true ]] && return 0
local -r CHANGE_THRESHOLD_MINUTES=60
local -r LOG_PATHFILE=$LOGS_PATH/Entware.$UPDATE_LOG_FILE
local -i result_code=0
if ! IsThisFileRecent "$EXTERNAL_PACKAGES_ARCHIVE_PATHFILE" "$CHANGE_THRESHOLD_MINUTES" || [[ ! -f $EXTERNAL_PACKAGES_ARCHIVE_PATHFILE ]] || Opts.Deps.Check.IsSet; then
DebugAsProc "updating $(FormatAsPackName Entware) package list"
RunAndLog "$OPKG_CMD update" "$LOG_PATHFILE" log:failure-only
result_code=$?
if [[ $result_code -eq 0 ]]; then
DebugAsDone "updated $(FormatAsPackName Entware) package list"
CloseIPKArchive
else
DebugAsWarn "Unable to update $(FormatAsPackName Entware) package list $(FormatAsExitcode "$result_code")"
fi
else
DebugInfo "$(FormatAsPackName Entware) package list updated less-than $CHANGE_THRESHOLD_MINUTES minutes ago: skipping update"
fi
[[ -f $EXTERNAL_PACKAGES_ARCHIVE_PATHFILE && ! -f $EXTERNAL_PACKAGES_PATHFILE ]] && OpenIPKArchive
readonly ENTWARE_PACKAGE_LIST_UPTODATE=true
return 0
}
IsThisFileRecent()
{
if [[ -e $1 && -e $GNU_FIND_CMD ]]; then
if [[ -z $($GNU_FIND_CMD "$1" -cmin +${2:-1440}) ]]; then       
return 0
fi
fi
return 1   
}
SavePackageLists()
{
$PIP_CMD freeze > "$PREV_PIP_LIST" 2>/dev/null && DebugAsDone "saved current $(FormatAsPackName pip3) module list to $(FormatAsFileName "$PREV_PIP_LIST")"
$OPKG_CMD list-installed > "$PREV_IPK_LIST" 2>/dev/null && DebugAsDone "saved current $(FormatAsPackName Entware) IPK list to $(FormatAsFileName "$PREV_IPK_LIST")"
}
CalcIpkDepsToInstall()
{
IsNtSysFileExist $GNU_GREP_CMD && return 1
DebugScriptFuncEn
local -a this_list=()
local -a dep_acc=()
local -i requested_count=0
local -i pre_exclude_count=0
local -i iterations=0
local -r ITERATION_LIMIT=20
local req_list=''
local pre_exclude_list=''
local element=''
local complete=false
req_list=$(DeDupeWords "$(IPKs.AcToInstall.List)")
this_list=($req_list)
requested_count=$($WC_CMD -w <<< "$req_list")
if [[ $requested_count -eq 0 ]]; then
DebugAsWarn 'no IPKs requested'
DebugScriptFuncEx 1; return
fi
ShowAsProc 'calculating IPK dependencies'
DebugInfo "$requested_count IPK$(Pluralise "$requested_count") requested" "'$req_list' "
while [[ $iterations -lt $ITERATION_LIMIT ]]; do
((iterations++))
local IPK_titles=$(printf '^Package: %s$\|' "${this_list[@]}")
IPK_titles=${IPK_titles%??}      
this_list=($($GNU_GREP_CMD --word-regexp --after-context 1 --no-group-separator '^Package:\|^Depends:' "$EXTERNAL_PACKAGES_PATHFILE" | $GNU_GREP_CMD -vG '^Section:\|^Version:' | $GNU_GREP_CMD --word-regexp --after-context 1 --no-group-separator "$IPK_titles" | $GNU_GREP_CMD -vG "$IPK_titles" | $GNU_GREP_CMD -vG '^Package: ' | $SED_CMD 's|^Depends: ||;s|, |\n|g' | $SORT_CMD | /bin/uniq))
if [[ ${#this_list[@]} -eq 0 ]]; then
complete=true
break
else
dep_acc+=(${this_list[*]})
fi
done
if [[ $complete = true ]]; then
DebugAsDone "completed in $iterations loop iteration$(Pluralise "$iterations")"
else
DebugAsError "incomplete with $iterations loop iteration$(Pluralise "$iterations"), consider raising \$ITERATION_LIMIT [$ITERATION_LIMIT]"
Self.SuggestIssue.Set
fi
pre_exclude_list=$(DeDupeWords "$req_list ${dep_acc[*]}")
pre_exclude_count=$($WC_CMD -w <<< "$pre_exclude_list")
if [[ $pre_exclude_count -gt 0 ]]; then
DebugInfo "$pre_exclude_count IPK$(Pluralise "$pre_exclude_count") required (including dependencies)" "'$pre_exclude_list' "
DebugAsProc 'excluding IPKs already installed'
for element in $pre_exclude_list; do
if [[ $element != 'ca-certs' && $element != 'python3-gdbm' ]]; then
if [[ $element != 'libjpeg' ]]; then
if ! $OPKG_CMD status "$element" | $GREP_CMD -q "Status:.*installed"; then
IPKs.AcToDownload.Add "$element"
fi
elif ! $OPKG_CMD status 'libjpeg-turbo' | $GREP_CMD -q "Status:.*installed"; then
IPKs.AcToDownload.Add 'libjpeg-turbo'
fi
fi
done
else
DebugAsDone 'no IPKs to exclude'
fi
DebugScriptFuncEx
}
CalcIpkDownloadSize()
{
DebugScriptFuncEn
local -a size_array=()
local -i size_count=0
size_count=$(IPKs.AcToDownload.Count)
if [[ $size_count -gt 0 ]]; then
DebugAsDone "$size_count IPK$(Pluralise "$size_count") to download: '$(IPKs.AcToDownload.List)'"
DebugAsProc "calculating size of IPK$(Pluralise "$size_count") to download"
size_array=($($GNU_GREP_CMD -w '^Package:\|^Size:' "$EXTERNAL_PACKAGES_PATHFILE" | $GNU_GREP_CMD --after-context 1 --no-group-separator ": $($SED_CMD 's/ /$ /g;s/\$ /\$\\\|: /g' <<< "$(IPKs.AcToDownload.List)")" | $GREP_CMD '^Size:' | $SED_CMD 's|^Size: ||'))
IPKs.AcToDownload.Size = "$(IFS=+; echo "$((${size_array[*]}))")"  
DebugAsDone "$(FormatAsThous "$(IPKs.AcToDownload.Size)") bytes ($(FormatAsISOBytes "$(IPKs.AcToDownload.Size)")) to download"
else
DebugAsDone 'no IPKs to size'
fi
DebugScriptFuncEx
}
IPKs.Upgrade()
{
IPKs.Upgrade.IsNt && return
QPKGs.IsNtInstalled.Exist Entware && return
QPKGs.IsNtStarted.Exist Entware && return
UpdateEntwarePackageList
Self.Error.IsSet && return
DebugScriptFuncEn
local -i result_code=0
IPKs.AcToUpgrade.Init
IPKs.AcToDownload.Init
IPKs.AcToUpgrade.Add "$($OPKG_CMD list-upgradable | cut -f1 -d' ')"
IPKs.AcToDownload.Add "$(IPKs.AcToUpgrade.Array)"
CalcIpkDownloadSize
total_count=$(IPKs.AcToDownload.Count)
if [[ $total_count -gt 0 ]]; then
ShowAsProc "downloading & upgrading $total_count IPK$(Pluralise "$total_count")"
_MonitorDirSize_ "$IPK_DL_PATH" "$(IPKs.AcToDownload.Size)" &
fork_pid=$!
RunAndLog "$OPKG_CMD upgrade --force-overwrite $(IPKs.AcToDownload.List) --cache $IPK_CACHE_PATH --tmp-dir $IPK_DL_PATH" "$LOGS_PATH/ipks.$UPGRADE_LOG_FILE" log:failure-only
result_code=$?
KillActiveFork
if [[ $result_code -eq 0 ]]; then
ok_count=$total_count          
NoteIPKAcAsOk "$(IPKs.AcToUpgrade.Array)" upgrade
else
ShowAsFail "download & upgrade $total_count IPK$(Pluralise "$total_count") failed $(FormatAsExitcode "$result_code")"
NoteIPKAcAsEr "$(IPKs.AcToUpgrade.Array)" upgrade
fi
fi
DebugScriptFuncEx
}
IPKs.Install()
{
IPKs.Install.IsNt && return
QPKGs.IsNtInstalled.Exist Entware && return
QPKGs.IsNtStarted.Exist Entware && return
UpdateEntwarePackageList
Self.Error.IsSet && return
DebugScriptFuncEn
local -i index=0
local -i result_code=0
IPKs.AcToInstall.Init
IPKs.AcToDownload.Init
! QPKGs.AcOkInstall.Exist Entware && IPKs.AcToInstall.Add "$ESSENTIAL_IPKS"
if QPKGs.AcInstall.ScAll.IsSet; then
for index in "${!QPKG_NAME[@]}"; do
IPKs.AcToInstall.Add "${QPKG_REQUIRES_IPKS[$index]}"
done
else
for index in "${!QPKG_NAME[@]}"; do
if QPKGs.AcToInstall.Exist "${QPKG_NAME[$index]}" || QPKGs.IsInstalled.Exist "${QPKG_NAME[$index]}" || QPKGs.AcToReinstall.Exist "${QPKG_NAME[$index]}" || (QPKGs.AcToStart.Exist "${QPKG_NAME[$index]}" && (QPKGs.AcToInstall.Exist "${QPKG_NAME[$index]}" || QPKGs.IsInstalled.Exist "${QPKG_NAME[$index]}" || QPKGs.AcToReinstall.Exist "${QPKG_NAME[$index]}")); then
QPKG.MinRAM "${QPKG_NAME[$index]}" &>/dev/null || continue
IPKs.AcToInstall.Add "${QPKG_REQUIRES_IPKS[$index]}"
fi
done
fi
CalcIpkDepsToInstall
CalcIpkDownloadSize
total_count=$(IPKs.AcToDownload.Count)
if [[ $total_count -gt 0 ]]; then
ShowAsProc "downloading & installing $total_count IPK$(Pluralise "$total_count"): "
_MonitorDirSize_ "$IPK_DL_PATH" "$(IPKs.AcToDownload.Size)" &
fork_pid=$!
RunAndLog "$OPKG_CMD install --force-overwrite $(IPKs.AcToDownload.List) --cache $IPK_CACHE_PATH --tmp-dir $IPK_DL_PATH" "$LOGS_PATH/ipks.$INSTALL_LOG_FILE" log:failure-only
result_code=$?
KillActiveFork
if [[ $result_code -eq 0 ]]; then
ok_count=$total_count          
NoteIPKAcAsOk "$(IPKs.AcToDownload.Array)" install
else
fail_count=$total_count        
ShowAsFail "download & install $total_count IPK$(Pluralise "$total_count") failed $(FormatAsExitcode "$result_code")"
NoteIPKAcAsEr "$(IPKs.AcToDownload.Array)" install
fi
fi
DebugScriptFuncEx
}
PIPs.Install()
{
PIPs.Install.IsNt && return
QPKGs.IsNtInstalled.Exist Entware && return
QPKGs.IsNtStarted.Exist Entware && return
! $OPKG_CMD status python3-pip | $GREP_CMD -q "Status:.*installed" && return
Self.Error.IsSet && return
DebugScriptFuncEn
local exec_cmd=''
local -i result_code=0
local -r PACKAGE_TYPE='PyPI group'
local -r RUNTIME=long
ModPathToEntware
if Opts.Deps.Check.IsSet || IPKs.AcOkInstall.Exist python3-pip; then
((total_count++))
ShowAsActionProgress '' "$PACKAGE_TYPE" "$ok_count" "$skip_count" "$fail_count" "$total_count" installing "$RUNTIME"
exec_cmd="$PIP_CMD install --upgrade --no-input $ESSENTIAL_PIPS --cache-dir $PIP_CACHE_PATH 2> >($GREP_CMD -v \"Running pip as the 'root' user\") >&2"
local desc="'PyPI' essential modules"
local log_pathfile=$LOGS_PATH/pypi.$INSTALL_LOG_FILE
DebugAsProc "installing $desc"
RunAndLog "$exec_cmd" "$log_pathfile" log:failure-only
result_code=$?
if [[ $result_code -eq 0 ]]; then
DebugAsDone "installed $desc"
((ok_count++))
else
ShowAsFail "installed $desc failed $(FormatAsResult "$result_code")"
((fail_count++))
fi
ShowAsActionProgress '' "$PACKAGE_TYPE" "$ok_count" "$skip_count" "$fail_count" "$total_count" installing "$RUNTIME"
fi
DebugScriptFuncEx $result_code
}
OpenIPKArchive()
{
if [[ ! -e $EXTERNAL_PACKAGES_ARCHIVE_PATHFILE ]]; then
ShowAsError 'unable to locate the IPK list file'
return 1
fi
RunAndLog "/usr/local/sbin/7z e -o$($DIRNAME_CMD "$EXTERNAL_PACKAGES_PATHFILE") $EXTERNAL_PACKAGES_ARCHIVE_PATHFILE" "$WORK_PATH/ipk.archive.extract" log:failure-only
if [[ ! -e $EXTERNAL_PACKAGES_PATHFILE ]]; then
ShowAsError 'unable to open the IPK list file'
return 1
fi
return 0
}
CloseIPKArchive()
{
[[ -f $EXTERNAL_PACKAGES_PATHFILE ]] && rm -f "$EXTERNAL_PACKAGES_PATHFILE"
}
_LaunchQPKGActionForks_()
{
local package=''
local target_function="${1:-function null}"
shift  
local -a target_packages=("$@")
for package in "${target_packages[@]}"; do
while [[ $fork_count -ge $max_forks ]]; do 
UpdateForkProgress
done
IncForkProgressIndex
MarkThisActionForkAsStarted   
$target_function "$package" &
DebugAsDone "forked $target_function for $package"
UpdateForkProgress
done
while [[ $fork_count -gt 0 ]]; do
UpdateForkProgress     
$SLEEP_CMD 1
done
EraseThisLine
}
_MonitorDirSize_()
{
[[ -z ${1:?path null} || ! -d ${1:-} || -z ${2:?total bytes null} || ${2:-} -eq 0 ]] && exit
IsNtSysFileExist $GNU_FIND_CMD && exit
local -i current_bytes=-1
local -i total_bytes=$2
local -i last_bytes=0
local -i stall_seconds=0
local -i stall_seconds_threshold=4
local perc_msg=''
local progress_msg=''
local stall_msg=''
InitProgress
while [[ $current_bytes -lt $total_bytes ]]; do
current_bytes=$($GNU_FIND_CMD "$1" -type f -name '*.ipk' -exec $DU_CMD --bytes --total --apparent-size {} + 2>/dev/null | $GREP_CMD total$ | cut -f1)
[[ -z $current_bytes ]] && current_bytes=0
if [[ $current_bytes -ne $last_bytes ]]; then
stall_seconds=0
last_bytes=$current_bytes
else
((stall_seconds++))
fi
perc_msg="$((200*(current_bytes)/(total_bytes)%2+100*(current_bytes)/(total_bytes)))%"
[[ $current_bytes -lt $total_bytes && $perc_msg = '100%' ]] && perc_msg='99%'    
progress_msg="$perc_msg ($(ColourTextBrightWhite "$(FormatAsISOBytes "$current_bytes")")/$(ColourTextBrightWhite "$(FormatAsISOBytes "$total_bytes")"))"
if [[ $stall_seconds -ge $stall_seconds_threshold ]]; then
stall_msg=' stalled for '
if [[ $stall_seconds -lt 60 ]]; then
stall_msg+="$stall_seconds seconds"
else
stall_msg+="$(FormatSecsToHoursMinutesSecs "$stall_seconds")"
fi
if [[ $stall_seconds -ge 90 ]]; then
stall_msg+=': cancel with CTRL+C and try again later'
fi
if [[ $stall_seconds -ge 90 ]]; then
stall_msg=$(ColourTextBrightRed "$stall_msg")
elif [[ $stall_seconds -ge 45 ]]; then
stall_msg=$(ColourTextBrightOrange "$stall_msg")
elif [[ $stall_seconds -ge 20 ]]; then
stall_msg=$(ColourTextBrightYellow "$stall_msg")
fi
progress_msg+=$stall_msg
fi
WriteMsgInPlace "$progress_msg"
$SLEEP_CMD 1
done
[[ -n $progress_msg ]] && WriteMsgInPlace 'done!'
}
WriteMsgInPlace()
{
local -i length=0
local -i prev_length=0
local -i blanking_length=0
local squeezed_msg=$(tr -s ' ' <<< "${1:-}")
local clean_msg=$(StripANSI "$squeezed_msg")
if [[ $clean_msg != "$prev_clean_msg" ]]; then
length=${#clean_msg}
prev_length=${#prev_clean_msg}
if [[ $length -lt $prev_length ]]; then
blanking_length=$((length-prev_length))
printf "%${prev_length}s" | tr ' ' '\b'; echo -en "$squeezed_msg"; printf "%${blanking_length}s"; printf "%${blanking_length}s" | tr ' ' '\b'
else
printf "%${prev_length}s" | tr ' ' '\b'; echo -en "$squeezed_msg"
fi
prev_clean_msg=$clean_msg
fi
}
KillActiveFork()
{
if [[ -n ${fork_pid:-} && ${fork_pid:-0} -gt 0 && -d /proc/$fork_pid ]]; then
$SLEEP_CMD 1
kill -9 "$fork_pid" 2>/dev/null
wait 2>/dev/null
fi
}
IsQNAP()
{
if [[ ! -e /etc/init.d/functions ]]; then
ShowAsAbort 'QTS functions missing (is this a QNAP NAS?)'
return 1
fi
return 0
}
IsSU()
{
if [[ $EUID -ne 0 ]]; then
if [[ -e /usr/bin/sudo ]]; then
ShowAsError 'this utility must be run with superuser privileges. Try again as:'
echo "$ sudo sherpa" >&2
else
ShowAsError "this utility must be run as the 'admin' user. Please login via SSH as 'admin' and try again"
fi
return 1
fi
return 0
}
GetDefPythonVer()
{
GetPythonVer "${1:-}"
}
GetDefPython3Ver()
{
GetPythonVer "${1:-python3}"
}
GetDefPerlVer()
{
GetPerlVer
}
GetPythonVer()
{
GetThisBinPath ${1:-python} &>/dev/null && ${1:-python} -V 2>&1 | $SED_CMD 's|^Python ||'
}
GetPerlVer()
{
GetThisBinPath ${1:-perl} &>/dev/null && ${1:-perl} -e 'print "$^V\n"' 2>/dev/null | $SED_CMD 's|v||'
}
GetThisBinPath()
{
[[ -n ${1:?null} ]] && command -v "$1" 2>&1
}
DebugBinPathVerAndMinVer()
{
[[ -n ${1:-} ]] || return
local bin_path=$(GetThisBinPath "$1")
if [[ -n $bin_path ]]; then
DebugUserspaceOK "'$1' path" "$bin_path"
else
DebugUserspaceWarning "'$1' path" '<not present>'
fi
if [[ -n ${2:-} ]]; then
if [[ ${2//./} -ge ${3//./} ]]; then
DebugUserspaceOK "'$1' version" "$2"
else
DebugUserspaceWarning "'$1' version" "$2"
fi
else
DebugUserspaceWarning "'$1' version" '<unknown>'
fi
return 0
}
IsSysFileExist()
{
if ! [[ -f ${1:?pathfile null} || -L ${1:?pathfile null} ]]; then
ShowAsAbort "a required NAS system file is missing $(FormatAsFileName "$1")"
return 1
fi
return 0
}
IsNtSysFileExist()
{
! IsSysFileExist "${1:?pathfile null}"
}
readonly HELP_DESC_INDENT=3
readonly HELP_SYNTAX_INDENT=6
readonly ACTION_RESULT_INDENT=6
readonly HELP_PACKAGE_NAME_WIDTH=20
readonly HELP_PACKAGE_AUTHOR_WIDTH=12
readonly HELP_PACKAGE_STATUS_WIDTH=40
readonly HELP_PACKAGE_VER_WIDTH=17
readonly HELP_PACKAGE_PATH_WIDTH=42
readonly HELP_PACKAGE_REPO_WIDTH=40
readonly HELP_FILE_NAME_WIDTH=33
readonly HELP_COL_SPACER=' '
readonly HELP_COL_MAIN_PREFIX='* '
readonly HELP_COL_OTHER_PREFIX='- '
readonly HELP_COL_BLANK_PREFIX='  '
readonly HELP_SYNTAX_PREFIX='# '
LenANSIDiff()
{
local stripped=$(StripANSI "${1:-}")
echo "$((${#1}-${#stripped}))"
return 0
}
DisplayAsProjSynExam()
{
Display
if [[ ${1: -1} = '!' ]]; then
printf "${HELP_COL_MAIN_PREFIX}%s\n%${HELP_SYNTAX_INDENT}s${HELP_SYNTAX_PREFIX}%s\n" "$(Capitalise "${1:-}")" '' "sherpa ${2:-}"
else
printf "${HELP_COL_MAIN_PREFIX}%s:\n%${HELP_SYNTAX_INDENT}s${HELP_SYNTAX_PREFIX}%s\n" "$(Capitalise "${1:-}")" '' "sherpa ${2:-}"
fi
Self.LineSpace.UnSet
}
DisplayAsProjSynIndentExam()
{
if [[ -z ${1:-} ]]; then
printf "%${HELP_SYNTAX_INDENT}s${HELP_SYNTAX_PREFIX}%s\n" '' "sherpa ${2:-}"
elif [[ ${1: -1} = '!' ]]; then
printf "\n%${HELP_DESC_INDENT}s%s\n%${HELP_SYNTAX_INDENT}s${HELP_SYNTAX_PREFIX}%s\n" '' "$(Capitalise "${1:-}")" '' "sherpa ${2:-}"
else
printf "\n%${HELP_DESC_INDENT}s%s:\n%${HELP_SYNTAX_INDENT}s${HELP_SYNTAX_PREFIX}%s\n" '' "$(Capitalise "${1:-}")" '' "sherpa ${2:-}"
fi
Self.LineSpace.UnSet
}
DisplayAsSynExam()
{
if [[ -z ${2:-} && ${1: -1} = ':' ]]; then
printf "\n${HELP_COL_MAIN_PREFIX}%s\n" "$1"
elif [[ ${1: -1} = '!' ]]; then
printf "\n${HELP_COL_MAIN_PREFIX}%s\n%${HELP_SYNTAX_INDENT}s${HELP_SYNTAX_PREFIX}%s\n" "$(Capitalise "${1:-}")" '' "${2:-}"
else
printf "\n${HELP_COL_MAIN_PREFIX}%s:\n%${HELP_SYNTAX_INDENT}s${HELP_SYNTAX_PREFIX}%s\n" "$(Capitalise "${1:-}")" '' "${2:-}"
fi
Self.LineSpace.UnSet
}
DisplayAsHelpTitlePackageNameAuthorDesc()
{
Display
printf "${HELP_COL_MAIN_PREFIX}%-${HELP_PACKAGE_NAME_WIDTH}s${HELP_COL_SPACER}${HELP_COL_MAIN_PREFIX}%-${HELP_PACKAGE_AUTHOR_WIDTH}s${HELP_COL_SPACER}${HELP_COL_MAIN_PREFIX}%s\n" "$(Capitalise "${1:-}"):" "$(Capitalise "${2:-}"):" "$(Capitalise "${3:-}"):"
}
DisplayAsHelpPackageNameAuthorDesc()
{
if [[ -z ${4:-} ]]; then
printf "${HELP_COL_SPACER}${HELP_COL_BLANK_PREFIX}%-${HELP_PACKAGE_NAME_WIDTH}s${HELP_COL_SPACER}${HELP_COL_BLANK_PREFIX}%-${HELP_PACKAGE_AUTHOR_WIDTH}s${HELP_COL_SPACER}${HELP_COL_OTHER_PREFIX}%s\n" "${1:-}" "${2:-}" "${3:-}"
else
printf "${HELP_COL_SPACER}${HELP_COL_BLANK_PREFIX}%-${HELP_PACKAGE_NAME_WIDTH}s${HELP_COL_SPACER}${HELP_COL_BLANK_PREFIX}%-${HELP_PACKAGE_AUTHOR_WIDTH}s${HELP_COL_SPACER}${HELP_COL_OTHER_PREFIX}%s $(ColourTextBrightOrange "%s")\n" "${1:-}" "${2:-}" "${3:-}" "${4:-}"
fi
}
DisplayAsHelpTitlePackageNameAbs()
{
Display
printf "${HELP_COL_MAIN_PREFIX}%-${HELP_PACKAGE_NAME_WIDTH}s${HELP_COL_SPACER}${HELP_COL_MAIN_PREFIX}%s\n" "$(Capitalise "${1:-}"):" "$(Capitalise "${2:-}"):"
}
DisplayAsHelpPackageNameAbs()
{
printf "${HELP_COL_SPACER}${HELP_COL_BLANK_PREFIX}%-${HELP_PACKAGE_NAME_WIDTH}s${HELP_COL_SPACER}${HELP_COL_OTHER_PREFIX}%s\n" "${1:-}" "${2:-}"
}
CalcMaxStatusColsToDisplay()
{
local col1_width=$((${#HELP_COL_MAIN_PREFIX}+HELP_PACKAGE_NAME_WIDTH))
local col2_width=$((${#HELP_COL_SPACER}+${#HELP_COL_MAIN_PREFIX}+HELP_PACKAGE_STATUS_WIDTH))
local col3_width=$((${#HELP_COL_SPACER}+${#HELP_COL_MAIN_PREFIX}+HELP_PACKAGE_VER_WIDTH))
local col4_width=$((${#HELP_COL_SPACER}+${#HELP_COL_MAIN_PREFIX}+HELP_PACKAGE_PATH_WIDTH))
if [[ $((col1_width+col2_width)) -ge $SESS_COLS ]]; then
echo 1
elif [[ $((col1_width+col2_width+col3_width)) -ge $SESS_COLS ]]; then
echo 2
elif [[ $((col1_width+col2_width+col3_width+col4_width)) -ge $SESS_COLS ]]; then
echo 3
else
echo 4
fi
return 0
}
CalcMaxRepoColsToDisplay()
{
local col1_width=$((${#HELP_COL_MAIN_PREFIX}+HELP_PACKAGE_NAME_WIDTH))
local col2_width=$((${#HELP_COL_SPACER}+${#HELP_COL_MAIN_PREFIX}+HELP_PACKAGE_REPO_WIDTH))
if [[ $((col1_width+col2_width)) -ge $SESS_COLS ]]; then
echo 1
else
echo 2
fi
return 0
}
DisplayAsHelpTitlePackageNameVerStatus()
{
local maxcols=$(CalcMaxStatusColsToDisplay)
DisplayLineSpaceIfNoneAlready
if [[ -n ${1:-} && $maxcols -ge 1 ]]; then
printf "${HELP_COL_MAIN_PREFIX}%-${HELP_PACKAGE_NAME_WIDTH}s" "$(Capitalise "$1"):"
fi
if [[ -n ${2:-} && $maxcols -ge 2 ]]; then
printf "${HELP_COL_SPACER}${HELP_COL_MAIN_PREFIX}%-${HELP_PACKAGE_STATUS_WIDTH}s" "$(Capitalise "$2"):"
fi
if [[ -n ${3:-} && $maxcols -ge 3 ]]; then
printf "${HELP_COL_SPACER}${HELP_COL_MAIN_PREFIX}%-${HELP_PACKAGE_VER_WIDTH}s" "$(Capitalise "$3"):"
fi
if [[ -n ${4:-} && $maxcols -ge 4 ]]; then
printf "${HELP_COL_SPACER}${HELP_COL_MAIN_PREFIX}%s" "$(Capitalise "$4"):"
fi
printf '\n'
}
DisplayAsHelpPackageNameVerStatus()
{
local maxcols=$(CalcMaxStatusColsToDisplay)
if [[ -n ${1:-} && $maxcols -ge 1 ]]; then
printf "${HELP_COL_SPACER}${HELP_COL_BLANK_PREFIX}%-$((HELP_PACKAGE_NAME_WIDTH+$(LenANSIDiff "$1")))s" "$1"
fi
if [[ -n ${2:-} && $maxcols -ge 2 ]]; then
printf "${HELP_COL_SPACER}${HELP_COL_OTHER_PREFIX}%-$((HELP_PACKAGE_STATUS_WIDTH+$(LenANSIDiff "$2")))s" "$2"
fi
if [[ -n ${3:-} && $maxcols -ge 3 ]]; then
printf "${HELP_COL_SPACER}${HELP_COL_OTHER_PREFIX}%-$((HELP_PACKAGE_VER_WIDTH+$(LenANSIDiff "$3")))s" "$3"
fi
if [[ -n ${4:-} && $maxcols -ge 4 ]]; then
printf "${HELP_COL_SPACER}${HELP_COL_BLANK_PREFIX}%s" "$4"
fi
printf '\n'
}
DisplayAsHelpTitlePackageNameRepo()
{
local maxcols=$(CalcMaxStatusColsToDisplay)
DisplayLineSpaceIfNoneAlready
if [[ -n ${1:-} && $maxcols -ge 1 ]]; then
printf "${HELP_COL_MAIN_PREFIX}%-${HELP_PACKAGE_NAME_WIDTH}s" "$(Capitalise "$1"):"
fi
if [[ -n ${2:-} && $maxcols -ge 2 ]]; then
printf "${HELP_COL_SPACER}${HELP_COL_MAIN_PREFIX}%-${HELP_PACKAGE_REPO_WIDTH}s" "$(Capitalise "$2"):"
fi
printf '\n'
Self.LineSpace.UnSet
}
DisplayAsHelpPackageNameRepo()
{
local maxcols=$(CalcMaxRepoColsToDisplay)
if [[ -n ${1:-} && $maxcols -ge 1 ]]; then
printf "${HELP_COL_SPACER}${HELP_COL_BLANK_PREFIX}%-$((HELP_PACKAGE_NAME_WIDTH+$(LenANSIDiff "$1")))s" "$1"
fi
if [[ -n ${2:-} && $maxcols -ge 2 ]]; then
printf "${HELP_COL_SPACER}${HELP_COL_OTHER_PREFIX}%-$((HELP_PACKAGE_REPO_WIDTH+$(LenANSIDiff "$2")))s" "$2"
fi
printf '\n'
}
DisplayAsHelpTitleFileNamePlusSomething()
{
DisplayLineSpaceIfNoneAlready
printf "${HELP_COL_MAIN_PREFIX}%-${HELP_FILE_NAME_WIDTH}s ${HELP_COL_MAIN_PREFIX}%s\n" "$(Capitalise "${1:-}"):" "$(Capitalise "${2:-}"):"
Self.LineSpace.UnSet
}
DisplayAsHelpTitle()
{
DisplayLineSpaceIfNoneAlready
printf "${HELP_COL_MAIN_PREFIX}%s\n" "$(Capitalise "${1:-}" | tr -s ' ')"
Self.LineSpace.UnSet
}
DisplayAsHelpTitleHighlighted()
{
DisplayLineSpaceIfNoneAlready
printf "$(ColourTextBrightOrange "${HELP_COL_MAIN_PREFIX}%s\n")" "$(Capitalise "${1:-}")"
Self.LineSpace.UnSet
}
DisplayAsActionResultNtLastLine()
{
printf "%${ACTION_RESULT_INDENT}s├─ %s\n" '' "$1"
}
DisplayAsActionResultLastLine()
{
printf "%${ACTION_RESULT_INDENT}s└─ %s\n" '' "$1"
}
EraseThisLine()
{
[[ $(type -t Self.Debug.ToScreen.Init) = function ]] && Self.Debug.ToScreen.IsSet && return
echo -en "\033[2K\r"
} >&2
Display()
{
echo -e "${1:-}"
[[ $(type -t Self.LineSpace.Init) = function ]] && Self.LineSpace.UnSet
}
DisplayWait()
{
echo -en "${1:-}"
}
Help.Actions.Show()
{
DisableDebugToArchiveAndFile
Help.Basic.Show
DisplayAsHelpTitle "$(FormatAsAction) usage examples:"
DisplayAsProjSynIndentExam 'show package statuses' 'status'
DisplayAsProjSynIndentExam '' s
DisplayAsProjSynIndentExam 'show package repositories' 'repos'
DisplayAsProjSynIndentExam '' r
DisplayAsProjSynIndentExam 'ensure all application dependencies are installed' 'check'
DisplayAsProjSynIndentExam '' c
DisplayAsProjSynIndentExam 'install these packages' "install $(FormatAsPackages)"
DisplayAsProjSynIndentExam 'uninstall these packages' "uninstall $(FormatAsPackages)"
DisplayAsProjSynIndentExam 'reinstall these packages' "reinstall $(FormatAsPackages)"
DisplayAsProjSynIndentExam "rebuild these packages ('install' packages, then 'restore' configuration backups)" "rebuild $(FormatAsPackages)"
DisplayAsProjSynIndentExam 'upgrade these packages (and internal applications where supported)' "upgrade $(FormatAsPackages)"
DisplayAsProjSynIndentExam 'enable then start these packages' "start $(FormatAsPackages)"
DisplayAsProjSynIndentExam 'stop then disable these packages (disabling will prevent them starting on reboot)' "stop $(FormatAsPackages)"
DisplayAsProjSynIndentExam 'restart these packages (this will upgrade internal applications where supported)' "restart $(FormatAsPackages)"
DisplayAsProjSynIndentExam "reassign these packages to the $(FormatAsTitle) repository" "reassign $(FormatAsPackages)"
DisplayAsProjSynIndentExam 'clear local repository files from these packages' "clean $(FormatAsPackages)"
DisplayAsProjSynIndentExam 'backup these application configurations to the backup location' "backup $(FormatAsPackages)"
DisplayAsProjSynIndentExam 'restore these application configurations from the backup location' "restore $(FormatAsPackages)"
DisplayAsProjSynIndentExam 'show application backup files' 'list backups'
DisplayAsProjSynIndentExam '' b
DisplayAsProjSynIndentExam "list $(FormatAsTitle) object version numbers" 'list versions'
DisplayAsProjSynIndentExam '' v
DisplayAsProjSynExam "$(FormatAsAction)s to affect all packages can be seen with" 'all-actions'
DisplayAsProjSynExam "multiple $(FormatAsAction)s are supported like this" "$(FormatAsAction) $(FormatAsPackages) $(FormatAsAction) $(FormatAsPackages)"
DisplayAsProjSynIndentExam '' 'install sabnzbd sickgear restart transmission uninstall lazy nzbget upgrade nzbtomedia'
return 0
}
Help.ActionsAll.Show()
{
DisableDebugToArchiveAndFile
Help.Basic.Show
DisplayAsHelpTitle "the 'all' group applies to all installed packages. If $(FormatAsAction) is 'install all' then all available packages will be installed."
DisplayAsHelpTitle "$(FormatAsAction) $(FormatAsGroups) usage examples:"
DisplayAsProjSynIndentExam 'install everything!' 'install all'
DisplayAsProjSynIndentExam 'uninstall everything!' 'force uninstall all'
DisplayAsProjSynIndentExam 'reinstall all installed packages' 'reinstall all'
DisplayAsProjSynIndentExam "rebuild all packages with backups ('install' packages and 'restore' backups)" 'rebuild all'
DisplayAsProjSynIndentExam 'upgrade all installed packages (and internal applications where supported)' 'upgrade all'
DisplayAsProjSynIndentExam 'enable then start all installed packages (upgrade internal applications, not packages)' 'start all'
DisplayAsProjSynIndentExam 'stop then disable all installed packages (disabling will prevent them starting on reboot)' 'stop all'
DisplayAsProjSynIndentExam 'restart packages (this will upgrade internal applications where supported)' 'restart all'
DisplayAsProjSynIndentExam 'clear local repository files from all packages' 'clean all'
DisplayAsProjSynIndentExam 'list all available packages' 'list all'
DisplayAsProjSynIndentExam 'list only installed packages' 'list installed'
DisplayAsProjSynIndentExam '' 'installed'
DisplayAsProjSynIndentExam 'list only packages that can be installed' 'list installable'
DisplayAsProjSynIndentExam '' 'installable'
DisplayAsProjSynIndentExam 'list only packages that are not installed' 'list not-installed'
DisplayAsProjSynIndentExam '' 'not-installed'
DisplayAsProjSynIndentExam 'list only upgradable packages' 'list upgradable'
DisplayAsProjSynIndentExam '' 'upgradable'
DisplayAsProjSynIndentExam 'backup all application configurations to the backup location' 'backup all'
DisplayAsProjSynIndentExam 'restore all application configurations from the backup location' 'restore all'
return 0
}
Help.BackupLocation.Show()
{
DisplayAsSynExam 'the backup location can be accessed by running' "cd $BACKUP_PATH"
return 0
}
Help.Basic.Show()
{
DisplayAsHelpTitle "Usage: sherpa $(FormatAsAction) $(FormatAsPackages) $(FormatAsGroups) $(FormatAsOptions)"
return 0
}
Help.Basic.Example.Show()
{
DisplayAsProjSynIndentExam "to list available $(FormatAsAction)s, type" 'list actions'
DisplayAsProjSynIndentExam "to list available $(FormatAsPackages), type" 'list packages'
DisplayAsProjSynIndentExam '' p
DisplayAsProjSynIndentExam "to list available $(FormatAsGroups)s, type" 'list groups'
DisplayAsProjSynIndentExam "or, for more $(FormatAsOptions), type" 'list options'
DisplayAsHelpTitle "More in the wiki: $(FormatAsURL "https://github.com/OneCDOnly/sherpa/wiki")"
return 0
}
Help.Groups.Show()
{
DisableDebugToArchiveAndFile
Help.Basic.Show
DisplayAsHelpTitle "$(FormatAsGroups) usage examples:"
DisplayAsProjSynIndentExam 'select every package' "$(FormatAsAction) all"
DisplayAsProjSynIndentExam 'select only standalone packages (these do not depend on other QPKGs)' "$(FormatAsAction) standalone"
DisplayAsProjSynIndentExam 'select only dependent packages (these require another QPKG to be installed and started)' "$(FormatAsAction) dependent"
DisplayAsProjSynIndentExam 'select only started packages' "$(FormatAsAction) started"
DisplayAsProjSynIndentExam 'select only stopped packages' "$(FormatAsAction) stopped"
DisplayAsProjSynIndentExam 'select only installed packages' "$(FormatAsAction) installed"
DisplayAsProjSynIndentExam 'select only packages that are not installed' "$(FormatAsAction) not-installed"
DisplayAsProjSynIndentExam 'select only packages that are backed-up' "$(FormatAsAction) backedup"
DisplayAsProjSynIndentExam 'select only packages that are not backed-up' "$(FormatAsAction) not-backedup"
DisplayAsProjSynIndentExam 'select only packages that are upgradable' "$(FormatAsAction) upgradable"
DisplayAsProjSynIndentExam 'select only missing packages (these are partly installed and broken)' "$(FormatAsAction) missing"
DisplayAsProjSynExam 'multiple groups are supported like this' "$(FormatAsAction) $(FormatAsGroups) $(FormatAsGroups)"
return 0
}
Help.Issue.Show()
{
DisplayAsHelpTitle "please consider creating a new issue for this on GitHub:\n\thttps://github.com/OneCDOnly/sherpa/issues"
DisplayAsHelpTitle "alternatively, post on the QNAP NAS Community Forum:\n\thttps://forum.qnap.com/viewtopic.php?f=320&t=132373"
DisplayAsProjSynIndentExam "view only the most recent $(FormatAsTitle) session log" 'last'
DisplayAsProjSynIndentExam "view the entire $(FormatAsTitle) session log" 'log'
DisplayAsProjSynIndentExam "upload the most-recent $(FormatAsThous "$LOG_TAIL_LINES") lines in your $(FormatAsTitle) log to the $(FormatAsURL 'https://termbin.com') public pastebin. A URL will be generated afterward" 'paste log'
DisplayAsHelpTitleHighlighted "If you need help, please include a copy of your $(FormatAsTitle) $(ColourTextBrightOrange "log for analysis!")"
return 0
}
Actions.Results.Show()
{
local -i datetime=0
local action=''
local package_name=''
local result=''
local -i duration=0
local reason=''
local found=false
DisableDebugToArchiveAndFile
if [[ -e $ACTIONS_LOG_PATHFILE ]]; then
local IFS='#'
while read -r datetime action package_name result duration reason; do
if [[ $display_last_action_datetime = true ]]; then
DisplayAsHelpTitle "the following package actions were run: $($DATE_CMD -d @"$datetime")"
display_last_action_datetime=false
fi
if [[ $result = "$1" ]] || [[ $1 = skipped && $result = 'skipped-error' ]]; then
case $result in
ok)
[[ $found = false ]] && DisplayAsHelpTitle "these package actions completed $(ColourTextBrightGreen OK):"
;;
skipped|skipped-ok|skipped-error)
[[ $found = false ]] && DisplayAsHelpTitle "these package actions were $(ColourTextBrightOrange skipped):"
;;
failed)
[[ $found = false ]] && DisplayAsHelpTitle "these package actions $(ColourTextBrightRed failed):"
esac
ShowAsActionLogDetail "$datetime" "$package_name" "$action" "$result" "$duration" "$reason"
found=true
fi
done < "$ACTIONS_LOG_PATHFILE"
fi
if [[ $found = false ]]; then
case $1 in
ok)
DisplayAsHelpTitle "No package actions completed $(ColourTextBrightGreen OK)"
;;
skipped)
DisplayAsHelpTitle "No package actions were $(ColourTextBrightOrange skipped)"
;;
failed)
DisplayAsHelpTitle "No package actions $(ColourTextBrightRed failed)"
esac
fi
return 0
}
Help.Options.Show()
{
DisableDebugToArchiveAndFile
Help.Basic.Show
DisplayAsHelpTitle "$(FormatAsOptions) usage examples:"
DisplayAsProjSynIndentExam 'show package statuses' 'status'
DisplayAsProjSynIndentExam '' s
DisplayAsProjSynIndentExam 'show package repositories' 'repos'
DisplayAsProjSynIndentExam '' r
DisplayAsProjSynIndentExam 'process one-or-more packages and show live debugging information' "$(FormatAsAction) $(FormatAsPackages) debug"
DisplayAsProjSynIndentExam '' "$(FormatAsAction) $(FormatAsPackages) verbose"
return 0
}
Help.Packages.Show()
{
local tier=''
local package=''
DisableDebugToArchiveAndFile
Help.Basic.Show
DisplayAsHelpTitle "One-or-more $(FormatAsPackages) may be specified at-once"
for tier in Standalone Dependent; do
DisplayAsHelpTitlePackageNameAuthorDesc "$tier QPKGs" author 'package description'
for package in $(QPKGs.Sc${tier}.Array); do
DisplayAsHelpPackageNameAuthorDesc "$package" "$(QPKG.Author "$package")" "$(QPKG.Desc "$package")" "$(QPKG.Note "$package")"
done
done
DisplayAsProjSynExam "abbreviations may also be used to specify $(FormatAsPackages). To list these" 'list abs'
DisplayAsProjSynIndentExam '' a
return 0
}
Help.PackageAbbreviations.Show()
{
local tier=''
local package=''
local abs=''
DisableDebugToArchiveAndFile
Help.Basic.Show
DisplayAsHelpTitle "$(FormatAsTitle) can recognise various abbreviations as $(FormatAsPackages)"
for tier in Standalone Dependent; do
DisplayAsHelpTitlePackageNameAbs "$tier QPKGs" 'acceptable package name abreviations'
for package in $(QPKGs.Sc${tier}.Array); do
abs=$(QPKG.Abbrvs "$package")
[[ -n $abs ]] && DisplayAsHelpPackageNameAbs "$package" "${abs// /, }"
done
done
DisplayAsProjSynExam "example: to install $(FormatAsPackName SABnzbd), $(FormatAsPackName Mylar3) and $(FormatAsPackName nzbToMedia) all-at-once" 'install sab my nzb2'
return 0
}
Help.Problems.Show()
{
DisableDebugToArchiveAndFile
Help.Basic.Show
DisplayAsHelpTitle 'usage examples for dealing with problems:'
DisplayAsProjSynIndentExam 'show package statuses' 'status'
DisplayAsProjSynIndentExam '' s
DisplayAsProjSynIndentExam 'process one-or-more packages and show live debugging information' "$(FormatAsAction) $(FormatAsPackages) debug"
DisplayAsProjSynIndentExam '' "$(FormatAsAction) $(FormatAsPackages) verbose"
DisplayAsProjSynIndentExam 'ensure all dependencies exist for installed packages' 'check'
DisplayAsProjSynIndentExam '' c
DisplayAsProjSynIndentExam 'clear local repository files from these packages' "clean $(FormatAsPackages)"
DisplayAsProjSynIndentExam "remove all cached $(FormatAsTitle) items and logs" 'reset'
DisplayAsProjSynIndentExam 'restart all installed packages (upgrades internal applications where supported)' 'restart all'
DisplayAsProjSynIndentExam 'enable then start these packages' "start $(FormatAsPackages)"
DisplayAsProjSynIndentExam 'stop then disable these packages (disabling will prevent them starting on reboot)' "stop $(FormatAsPackages)"
DisplayAsProjSynIndentExam "view only the most recent $(FormatAsTitle) session log" 'last'
DisplayAsProjSynIndentExam '' l
DisplayAsProjSynIndentExam "view the entire $(FormatAsTitle) session log" 'log'
DisplayAsProjSynIndentExam "upload the most-recent session in your $(FormatAsTitle) log to the $(FormatAsURL 'https://termbin.com') public pastebin. A URL will be generated afterward" 'paste last'
DisplayAsProjSynIndentExam "upload the most-recent $(FormatAsThous "$LOG_TAIL_LINES") lines in your $(FormatAsTitle) log to the $(FormatAsURL 'https://termbin.com') public pastebin. A URL will be generated afterward" 'paste log'
DisplayAsHelpTitleHighlighted "If you need help, please include a copy of your $(FormatAsTitle) $(ColourTextBrightOrange "log for analysis!")"
return 0
}
Help.Tips.Show()
{
DisableDebugToArchiveAndFile
Help.Basic.Show
DisplayAsHelpTitle 'helpful tips and shortcuts:'
DisplayAsProjSynIndentExam "install all available $(FormatAsTitle) packages" 'install all'
DisplayAsProjSynIndentExam 'package abbreviations also work. To see these' 'list abs'
DisplayAsProjSynIndentExam '' a
DisplayAsProjSynIndentExam 'restart all installed packages (upgrades internal applications where supported)' 'restart all'
DisplayAsProjSynIndentExam 'list only packages that can be installed' 'list installable'
DisplayAsProjSynIndentExam "view only the most recent $(FormatAsTitle) session log" 'last'
DisplayAsProjSynIndentExam '' l
DisplayAsProjSynIndentExam 'start all stopped packages' 'start stopped'
DisplayAsProjSynIndentExam 'upgrade the internal applications only' "restart $(FormatAsPackages)"
Help.BackupLocation.Show
return 0
}
Log.Last.View()
{
DisableDebugToArchiveAndFile
ExtractPrevSessFromTail
if [[ -e $SESS_LAST_PATHFILE ]]; then
if [[ -e $GNU_LESS_CMD ]]; then
LESSSECURE=1 $GNU_LESS_CMD +G --quit-on-intr --tilde --LINE-NUMBERS --prompt ' use arrow-keys to scroll up-down left-right, press Q to quit' "$SESS_LAST_PATHFILE"
elif [[ -e $LESS_CMD ]]; then
$LESS_CMD -N~ "$SESS_LAST_PATHFILE"
else
$CAT_CMD --number "$SESS_LAST_PATHFILE"
fi
else
ShowAsError 'no last session log to display'
fi
return 0
}
Log.Tail.View()
{
DisableDebugToArchiveAndFile
ExtractTailFromLog
if [[ -e $SESS_TAIL_PATHFILE ]]; then
if [[ -e $GNU_LESS_CMD ]]; then
LESSSECURE=1 $GNU_LESS_CMD +G --quit-on-intr --tilde --LINE-NUMBERS --prompt ' use arrow-keys to scroll up-down left-right, press Q to quit' "$SESS_TAIL_PATHFILE"
elif [[ -e $LESS_CMD ]]; then
$LESS_CMD -N~ "$SESS_TAIL_PATHFILE"
else
$CAT_CMD --number "$SESS_TAIL_PATHFILE"
fi
else
ShowAsError 'no session log tail to display'
fi
return 0
}
Log.Last.Paste()
{
local link=''
DisableDebugToArchiveAndFile
ExtractPrevSessFromTail
if [[ -e $SESS_LAST_PATHFILE ]]; then
if Quiz "Press 'Y' to post the most-recent session in your $(FormatAsTitle) log to a public pastebin, or any other key to abort"; then
ShowAsProc "uploading $(FormatAsTitle) log"
link=$($CAT_CMD --number "$SESS_LAST_PATHFILE" | (exec 3<>/dev/tcp/termbin.com/9999; $CAT_CMD >&3; $CAT_CMD <&3; exec 3<&-))
if [[ $? -eq 0 ]]; then
ShowAsDone "your $(FormatAsTitle) log is now online at $(FormatAsURL "$link") and will be deleted in 1 month"
else
ShowAsFail "a link could not be generated. Most likely a problem occurred when talking with $(FormatAsURL 'https://termbin.com')"
fi
else
DebugInfoMinSepr
DebugScript 'user abort'
Self.Summary.UnSet
return 1
fi
else
ShowAsError 'no last session log found'
fi
return 0
}
Log.Tail.Paste()
{
local link=''
DisableDebugToArchiveAndFile
ExtractTailFromLog
if [[ -e $SESS_TAIL_PATHFILE ]]; then
if Quiz "Press 'Y' to post the most-recent $(FormatAsThous "$LOG_TAIL_LINES") lines in your $(FormatAsTitle) log to a public pastebin, or any other key to abort"; then
ShowAsProc "uploading $(FormatAsTitle) log"
link=$($CAT_CMD --number "$SESS_TAIL_PATHFILE" | (exec 3<>/dev/tcp/termbin.com/9999; $CAT_CMD >&3; $CAT_CMD <&3; exec 3<&-))
if [[ $? -eq 0 ]]; then
ShowAsDone "your $(FormatAsTitle) log is now online at $(FormatAsURL "$link") and will be deleted in 1 month"
else
ShowAsFail "a link could not be generated. Most likely a problem occurred when talking with $(FormatAsURL 'https://termbin.com')"
fi
else
DebugInfoMinSepr
DebugScript 'user abort'
Self.Summary.UnSet
return 1
fi
else
ShowAsError 'no session log tail found'
fi
return 0
}
GetLogSessStartLine()
{
local -i linenum=$(($($GREP_CMD -n 'SCRIPT:.*started:' "$SESS_TAIL_PATHFILE" | $TAIL_CMD -n${1:-1} | $HEAD_CMD -n1 | cut -d':' -f1)-1))
[[ $linenum -lt 1 ]] && linenum=1
echo $linenum
}
GetLogSessFinishLine()
{
local -i linenum=$(($($GREP_CMD -n 'SCRIPT:.*finished:' "$SESS_TAIL_PATHFILE" | $TAIL_CMD -n${1:-1} | cut -d':' -f1)+2))
[[ $linenum -eq 2 ]] && linenum=3
echo $linenum
}
ArchiveActiveSessLog()
{
[[ -e $sess_active_pathfile ]] && $CAT_CMD "$sess_active_pathfile" >> "$SESS_ARCHIVE_PATHFILE"
}
ArchivePriorSessLogs()
{
local log_pathfile=''
for log_pathfile in "$PROJECT_PATH/session."*".active.log"; do
if [[ -f $log_pathfile && $log_pathfile != "$sess_active_pathfile" ]]; then
$CAT_CMD "$log_pathfile" >> "$SESS_ARCHIVE_PATHFILE"
rm -f "$log_pathfile"
fi
done
}
ResetActiveSessLog()
{
[[ -e $sess_active_pathfile ]] && rm -f "$sess_active_pathfile"
}
ExtractPrevSessFromTail()
{
local -i start_line=0
local -i end_line=0
local -i old_session=1
local -i old_session_limit=12
ExtractTailFromLog
if [[ -e $SESS_TAIL_PATHFILE ]]; then
end_line=$(GetLogSessFinishLine "$old_session")
start_line=$((end_line+1))     
while [[ $start_line -ge $end_line ]]; do
start_line=$(GetLogSessStartLine "$old_session")
((old_session++))
[[ $old_session -gt $old_session_limit ]] && break
done
$SED_CMD "$start_line,$end_line!d" "$SESS_TAIL_PATHFILE" > "$SESS_LAST_PATHFILE"
else
[[ -e $SESS_LAST_PATHFILE ]] && rm -f "$SESS_LAST_PATHFILE"
fi
return 0
}
ExtractTailFromLog()
{
if [[ -e $SESS_ARCHIVE_PATHFILE ]]; then
$TAIL_CMD -n${LOG_TAIL_LINES} "$SESS_ARCHIVE_PATHFILE" > "$SESS_TAIL_PATHFILE"  
else
[[ -e $SESS_TAIL_PATHFILE ]] && rm -f "$SESS_TAIL_PATHFILE"
fi
return 0
}
Self.Vers.Show()
{
DisableDebugToArchiveAndFile
Display "QPKG: ${THIS_PACKAGE_VER:-unknown}"
Display "manager: ${MANAGER_SCRIPT_VER:-unknown}"
Display "loader: ${LOADER_SCRIPT_VER:-unknown}"
Display "objects: ${OBJECTS_VER:-unknown}"
Display "packages: ${PACKAGES_VER:-unknown}"
return 0
}
InitForkCounts()
{
PROC_COUNTS_PATH=$(/bin/mktemp -d /var/run/"${FUNCNAME[1]}"_XXXXXX)
[[ -n ${PROC_COUNTS_PATH:?undefined proc counts path} ]] || return
EraseForkCountPaths
proc_fork_count_path=${PROC_COUNTS_PATH}/fork.count
proc_ok_count_path=${PROC_COUNTS_PATH}/ok.count
proc_skip_ok_count_path=${PROC_COUNTS_PATH}/skip.ok.count
proc_skip_count_path=${PROC_COUNTS_PATH}/skip.count
proc_skip_error_count_path=${PROC_COUNTS_PATH}/skip.error.count
proc_fail_count_path=${PROC_COUNTS_PATH}/fail.count
mkdir -p "$proc_fork_count_path"
mkdir -p "$proc_ok_count_path"
mkdir -p "$proc_skip_ok_count_path"
mkdir -p "$proc_skip_count_path"
mkdir -p "$proc_skip_error_count_path"
mkdir -p "$proc_fail_count_path"
InitProgress
}
IncForkProgressIndex()
{
((progress_index++))
local formatted_index="$(printf '%02d' "$progress_index")"
proc_fork_pathfile="$proc_fork_count_path/$formatted_index"
proc_ok_pathfile="$proc_ok_count_path/$formatted_index"
proc_skipok_pathfile="$proc_skip_ok_count_path/$formatted_index"
proc_skip_pathfile="$proc_skip_count_path/$formatted_index"
proc_skip_error_pathfile="$proc_skip_error_count_path/$formatted_index"
proc_fail_pathfile="$proc_fail_count_path/$formatted_index"
}
RefreshForkCounts()
{
fork_count="$(ls -A -1 "$proc_fork_count_path" | $WC_CMD -l)"
ok_count="$(ls -A -1 "$proc_ok_count_path" | $WC_CMD -l)"
skip_ok_count="$(ls -A -1 "$proc_skip_ok_count_path" | $WC_CMD -l)"
skip_count="$(ls -A -1 "$proc_skip_count_path" | $WC_CMD -l)"
skip_error_count="$(ls -A -1 "$proc_skip_error_count_path" | $WC_CMD -l)"
fail_count="$(ls -A -1 "$proc_fail_count_path" | $WC_CMD -l)"
}
EraseForkCountPaths()
{
[[ -d ${PROC_COUNTS_PATH:?undefined proc counts path} ]] && rm -r "$PROC_COUNTS_PATH"
}
InitProgress()
{
progress_index=0
prev_clean_msg=''
RefreshForkCounts
}
UpdateForkProgress()
{
local msg=': '
RefreshForkCounts
Self.Debug.ToScreen.IsSet && return    
msg+="$(PercFrac "$ok_count" "$((skip_count+skip_ok_count+skip_error_count))" "$fail_count" "$total_count")"
if [[ $fork_count -gt 0 ]]; then
[[ -n $msg ]] && msg+=': '
msg+="$(ColourTextBrightYellow "$fork_count") in-progress"
fi
if [[ $ok_count -gt 0 ]]; then
[[ -n $msg ]] && msg+=': '
msg+="$(ColourTextBrightGreen "$ok_count") OK"
fi
if [[ $skip_count -gt 0 || $skip_error_count -gt 0 ]]; then    
[[ -n $msg ]] && msg+=': '
msg+="$(ColourTextBrightOrange "$((skip_count+skip_error_count))") skipped"
fi
if [[ $fail_count -gt 0 ]]; then
[[ -n $msg ]] && msg+=': '
msg+="$(ColourTextBrightRed "$fail_count") failed"
fi
[[ -n $msg ]] && WriteMsgInPlace "$msg"
return 0
}
QPKGs.NewVers.Show()
{
local -a upgradable_packages=()
local -i index=0
local names_formatted=''
local msg=''
Self.Display.Clean.IsNt || return
QPKGs.States.Build
if [[ $(QPKGs.ScUpgradable.Count) -eq 0 ]]; then
return 0
else
upgradable_packages+=($(QPKGs.ScUpgradable.Array))
fi
for ((index=0; index<=((${#upgradable_packages[@]}-1)); index++)); do
names_formatted+=$(ColourTextBrightOrange "${upgradable_packages[$index]}")
if [[ $((index+2)) -lt ${#upgradable_packages[@]} ]]; then
names_formatted+=', '
elif [[ $((index+2)) -eq ${#upgradable_packages[@]} ]]; then
names_formatted+=' & '
fi
done
if [[ ${#upgradable_packages[@]} -eq 1 ]]; then
msg='a new QPKG is'
else
msg='new QPKGs are'
fi
EraseThisLine
DisplayLineSpaceIfNoneAlready
ShowAsInfo "$msg available for $names_formatted"
return 1
}
QPKGs.Conflicts.Check()
{
local package=''
if [[ -n ${BASE_QPKG_CONFLICTS_WITH:-} ]]; then
for package in "${BASE_QPKG_CONFLICTS_WITH[@]}"; do
if QPKG.IsEnabled "$package"; then
ShowAsError "the '$package' QPKG is enabled. $(FormatAsTitle) is incompatible with this package. Please consider 'stop'ing this QPKG in your App Center"
return 1
fi
done
fi
return 0
}
QPKGs.Warnings.Check()
{
local package=''
if [[ -n ${BASE_QPKG_WARNINGS:-} ]]; then
for package in "${BASE_QPKG_WARNINGS[@]}"; do
if QPKG.IsEnabled "$package"; then
ShowAsWarn "the '$package' QPKG is enabled. This may cause problems with $(FormatAsTitle) applications. Please consider 'stop'ing this QPKG in your App Center"
fi
done
fi
return 0
}
IPKs.Actions.List()
{
DebugScriptFuncEn
local action=''
local prefix=''
DebugInfoMinSepr
for action in "${PACKAGE_ACTIONS[@]}"; do
case $action in
Backup|Clean|Disable|Enable|Reassign|Rebuild|Restart|Restore|Start|Stop)
continue
esac
IPKs.AcOk${action}.IsAny && DebugIPKInfo "AcOk${action}" "($(IPKs.AcOk${action}.Count)) $(IPKs.AcOk${action}.ListCSV) "
IPKs.AcEr${action}.IsAny && DebugIPKError "AcEr${action}" "($(IPKs.AcEr${action}.Count)) $(IPKs.AcEr${action}.ListCSV) "
done
DebugInfoMinSepr
DebugScriptFuncEx
}
QPKGs.Actions.List()
{
DebugScriptFuncEn
local action=''
local prefix=''
DebugInfoMinSepr
for action in "${PACKAGE_ACTIONS[@]}"; do
[[ $action = Enable || $action = Disable ]] && continue    
for prefix in Ok Er Sk; do
if QPKGs.Ac${prefix}${action}.IsAny; then
case $prefix in
Ok)
DebugQPKGInfo "Ac${prefix}${action}" "($(QPKGs.Ac${prefix}${action}.Count)) $(QPKGs.Ac${prefix}${action}.ListCSV) "
;;
Sk)
DebugQPKGWarning "Ac${prefix}${action}" "($(QPKGs.Ac${prefix}${action}.Count)) $(QPKGs.Ac${prefix}${action}.ListCSV) "
;;
Er)
DebugQPKGError "Ac${prefix}${action}" "($(QPKGs.Ac${prefix}${action}.Count)) $(QPKGs.Ac${prefix}${action}.ListCSV) "
esac
fi
done
done
DebugInfoMinSepr
DebugScriptFuncEx
}
QPKGs.Actions.ListAll()
{
DebugScriptFuncEn
local action=''
local prefix=''
DebugInfoMinSepr
for action in "${PACKAGE_ACTIONS[@]}"; do
[[ $action = Enable || $action = Disable ]] && continue    
for prefix in To Ok Er Sk; do
if QPKGs.Ac${prefix}${action}.IsAny; then
DebugQPKGInfo "Ac${prefix}${action}" "($(QPKGs.Ac${prefix}${action}.Count)) $(QPKGs.Ac${prefix}${action}.ListCSV) "
fi
done
done
DebugInfoMinSepr
DebugScriptFuncEx
}
QPKGs.States.List()
{
DebugScriptFuncEn
local state=''
local prefix=''
QPKGs.States.Build "${1:-}"
DebugInfoMinSepr
for state in "${PACKAGE_STATES[@]}" "${PACKAGE_RESULTS[@]}"; do
for prefix in Is IsNt; do
if [[ $state = Installed ]]; then
continue
elif [[ $prefix = Is && $state = Enabled ]]; then
continue
elif [[ $prefix = IsNt && $state = Upgradable ]]; then
continue
elif [[ $prefix = IsNt && $state = Ok ]]; then
QPKGs.${prefix}${state}.IsAny && DebugQPKGError "${prefix}${state}" "($(QPKGs.${prefix}${state}.Count)) $(QPKGs.${prefix}${state}.ListCSV) "
elif [[ $prefix = IsNt && $state = BackedUp ]]; then
QPKGs.${prefix}${state}.IsAny && DebugQPKGWarning "${prefix}${state}" "($(QPKGs.${prefix}${state}.Count)) $(QPKGs.${prefix}${state}.ListCSV) "
elif [[ $prefix = Is && $state = Unknown ]]; then
QPKGs.${prefix}${state}.IsAny && DebugQPKGWarning "${prefix}${state}" "($(QPKGs.${prefix}${state}.Count)) $(QPKGs.${prefix}${state}.ListCSV) "
else
QPKGs.${prefix}${state}.IsAny && DebugQPKGInfo "${prefix}${state}" "($(QPKGs.${prefix}${state}.Count)) $(QPKGs.${prefix}${state}.ListCSV) "
fi
done
done
for state in "${PACKAGE_STATES_TRANSIENT[@]}"; do
for prefix in Is; do
QPKGs.${prefix}${state}.IsAny && DebugQPKGInfo "${prefix}${state}" "($(QPKGs.${prefix}${state}.Count)) $(QPKGs.${prefix}${state}.ListCSV) "
done
done
DebugInfoMinSepr
DebugScriptFuncEx
}
QPKGs.StandaloneDependent.Build()
{
local package=''
for package in "${QPKG_NAME[@]}"; do
if QPKG.IsDependent "$package"; then
QPKGs.ScDependent.Add "$package"
else
QPKGs.ScStandalone.Add "$package"
fi
done
return 0
}
QPKGs.States.Build()
{
local state=''
if [[ ${1:-} = rebuild ]]; then
DebugAsProc 'clearing existing state lists'
for state in "${PACKAGE_STATES[@]}" "${PACKAGE_STATES_TRANSIENT[@]}"; do
QPKGs.Is${state}.Init
QPKGs.IsNt${state}.Init
done
DebugAsDone 'cleared existing state lists'
QPKGs.States.Built.UnSet
fi
QPKGs.States.Built.IsSet && return
DebugScriptFuncEn
local -i index=0
local package=''
local prev=''
ShowAsProc 'package states'
for index in "${!QPKG_NAME[@]}"; do
package="${QPKG_NAME[$index]}"
[[ $package = "$prev" ]] && continue || prev=$package
if QPKG.IsInstalled "$package"; then
if [[ ! -d $(QPKG.InstallationPath "$package") ]]; then
QPKGs.IsMissing.Add "$package"
continue
fi
QPKGs.IsInstalled.Add "$package"
if [[ $(QPKG.Local.Ver "$package") != "${QPKG_VERSION[$index]}" ]]; then
QPKGs.ScUpgradable.Add "$package"
else
QPKGs.ScNtUpgradable.Add "$package"
fi
if QPKG.IsEnabled "$package"; then
QPKGs.IsEnabled.Add "$package"
else
QPKGs.IsNtEnabled.Add "$package"
fi
if QPKG.IsStarted "$package"; then
QPKGs.IsStarted.Add "$package"
else
QPKGs.IsNtStarted.Add "$package"
fi
if [[ -e /var/run/$package.last.operation ]]; then
case $(</var/run/$package.last.operation) in
starting)
QPKGs.IsStarting.Add "$package"
;;
restarting)
QPKGs.IsRestarting.Add "$package"
;;
stopping)
QPKGs.IsStopping.Add "$package"
;;
failed)
QPKGs.IsNtOk.Add "$package"
;;
ok)
QPKGs.IsOk.Add "$package"
esac
else
QPKGs.IsUnknown.Add "$package"
fi
else
QPKGs.IsNtInstalled.Add "$package"
if [[ -n ${QPKG_ABBRVS[$index]} ]] && [[ ${QPKG_ARCH[$index]} = all || ${QPKG_ARCH[$index]} = "$NAS_QPKG_ARCH" ]]; then
if [[ ${QPKG_MIN_RAM_KB[$index]} = none || $NAS_RAM_KB -ge ${QPKG_MIN_RAM_KB[$index]} ]]; then
QPKGs.ScInstallable.Add "$package"
fi
fi
fi
if QPKG.IsCanBackup "$package"; then
if QPKG.IsBackupExist "$package"; then
QPKGs.IsBackedUp.Add "$package"
else
QPKGs.IsNtBackedUp.Add "$package"
fi
fi
done
QPKGs.States.Built.Set
[[ ${FUNCNAME[1]} != Self.LogEnv ]] && EraseThisLine       
DebugScriptFuncEx
}
QPKGs.IsCanBackup.Build()
{
DebugScriptFuncEn
local package=''
for package in $(QPKGs.ScAll.Array); do
if QPKG.IsCanBackup "$package"; then
QPKGs.ScCanBackup.Add "$package"
else
QPKGs.ScNtCanBackup.Add "$package"
fi
done
DebugScriptFuncEx
}
QPKGs.IsCanRestartToUpdate.Build()
{
DebugScriptFuncEn
local package=''
for package in $(QPKGs.ScAll.Array); do
if QPKG.IsCanRestartToUpdate "$package"; then
QPKGs.ScCanRestartToUpdate.Add "$package"
else
QPKGs.ScNtCanRestartToUpdate.Add "$package"
fi
done
DebugScriptFuncEx
}
QPKGs.IsCanClean.Build()
{
DebugScriptFuncEn
local package=''
for package in $(QPKGs.ScAll.Array); do
if QPKG.IsCanClean "$package"; then
QPKGs.ScCanClean.Add "$package"
else
QPKGs.ScNtCanClean.Add "$package"
fi
done
DebugScriptFuncEx
}
QPKGs.Backups.Show()
{
local epochtime=0      
local filename=''
local highlight_older_than='2 weeks ago'
local format=''
DisableDebugToArchiveAndFile
DisplayAsHelpTitle "the location for $(FormatAsTitle) backups is: $BACKUP_PATH"
if [[ -e $GNU_FIND_CMD ]]; then
DisplayAsHelpTitle "backups are listed oldest-first, and those $(ColourTextBrightRed 'in red') were last updated more than $highlight_older_than"
DisplayAsHelpTitleFileNamePlusSomething 'backup file' 'last backup date'
while read -r epochtime filename; do
[[ -z $epochtime || -z $filename ]] && break
if [[ ${epochtime%.*} -lt $($DATE_CMD --date="$highlight_older_than" +%s) ]]; then
format="$(ColourTextBrightRed "%${HELP_DESC_INDENT}s%-${HELP_FILE_NAME_WIDTH}s - %s\n")"
else
format="%${HELP_DESC_INDENT}s%-${HELP_FILE_NAME_WIDTH}s - %s\n"
fi
printf "$format" '' "$filename" "$($DATE_CMD -d @"$epochtime" +%c)"
done <<< "$($GNU_FIND_CMD "$BACKUP_PATH"/*.config.tar.gz -maxdepth 1 -printf '%C@ %f\n' 2>/dev/null | $SORT_CMD)"
else
DisplayAsHelpTitle 'backups are listed oldest-first'
Display
(cd "$BACKUP_PATH" && ls -1 ./*.config.tar.gz 2>/dev/null)
fi
return 0
}
QPKGs.Repos.Show()
{
local tier=''
local -i index=0
local package_name=''
local package_store_id=''
local package_repo_URL_formatted=''
local maxcols=$(CalcMaxRepoColsToDisplay)
QPKGs.States.Build
for tier in Standalone Dependent; do
DisplayAsHelpTitlePackageNameRepo "$tier packages" 'repository'
for package_name in $(QPKGs.Sc$tier.Array); do
package_store_id=''
package_repo_URL_formatted=''
if ! QPKG.URL "$package_name" &>/dev/null; then
DisplayAsHelpPackageNameRepo "$package_name" 'not installable: no arch'
elif ! QPKG.MinRAM "$package_name" &>/dev/null; then
DisplayAsHelpPackageNameRepo "$package_name" 'not installable: low RAM'
elif QPKGs.IsNtInstalled.Exist "$package_name"; then
DisplayAsHelpPackageNameRepo "$package_name" 'not installed'
else
package_store_id=$(QPKG.StoreID "$package_name")
if [[ $package_store_id = sherpa ]]; then
package_repo_URL_formatted=$(ColourTextBrightGreen "$package_store_id")
else
package_repo_URL_formatted=$(ColourTextBrightOrange "$(GetRepoURLFromStoreID "$package_store_id")")
fi
DisplayAsHelpPackageNameRepo "$package_name" "$package_repo_URL_formatted"
fi
done
Display; Self.LineSpace.Set
done
QPKGs.Actions.List
QPKGs.States.List
return 0
}
QPKGs.Statuses.Show()
{
local tier=''
local -a package_status_notes=()
local -i index=0
local package_name=''
local package_name_formatted=''
local package_status=''
local package_ver=''
local maxcols=$(CalcMaxStatusColsToDisplay)
QPKGs.States.Build
for tier in Standalone Dependent; do
DisplayAsHelpTitlePackageNameVerStatus "$tier packages" 'package statuses (last result)' 'QPKG version' 'installation path'
for package_name in $(QPKGs.Sc$tier.Array); do
package_name_formatted=''
package_status=''
package_ver=''
package_status_notes=()
if ! QPKG.URL "$package_name" &>/dev/null; then
DisplayAsHelpPackageNameVerStatus "$package_name" 'not installable: no arch'
elif ! QPKG.MinRAM "$package_name" &>/dev/null; then
DisplayAsHelpPackageNameVerStatus "$package_name" 'not installable: low RAM'
elif QPKGs.IsNtInstalled.Exist "$package_name"; then
DisplayAsHelpPackageNameVerStatus "$package_name" 'not installed' "$(QPKG.Avail.Ver "$package_name")"
else
if [[ $maxcols -eq 1 ]]; then
if QPKGs.IsMissing.Exist "$package_name"; then
package_name_formatted=$(ColourTextBrightRedBlink "$package_name")
elif QPKGs.IsEnabled.Exist "$package_name"; then
package_name_formatted=$(ColourTextBrightGreen "$package_name")
elif QPKGs.IsNtEnabled.Exist "$package_name"; then
package_name_formatted=$(ColourTextBrightRed "$package_name")
fi
if QPKGs.IsStarting.Exist "$package_name"; then
package_name_formatted=$(ColourTextBrightOrange "$package_name")
elif QPKGs.IsStopping.Exist "$package_name"; then
package_name_formatted=$(ColourTextBrightOrange "$package_name")
elif QPKGs.IsRestarting.Exist "$package_name"; then
package_name_formatted=$(ColourTextBrightOrange "$package_name")
elif QPKGs.IsStarted.Exist "$package_name"; then
package_name_formatted=$(ColourTextBrightGreen "$package_name")
elif QPKGs.IsNtStarted.Exist "$package_name"; then
package_name_formatted=$(ColourTextBrightRed "$package_name")
fi
else
if QPKGs.IsMissing.Exist "$package_name"; then
package_status_notes=($(ColourTextBrightRedBlink missing))
elif QPKGs.IsEnabled.Exist "$package_name"; then
package_status_notes+=($(ColourTextBrightGreen enabled))
elif QPKGs.IsNtEnabled.Exist "$package_name"; then
package_status_notes+=($(ColourTextBrightRed disabled))
fi
if QPKGs.IsStarting.Exist "$package_name"; then
package_status_notes+=($(ColourTextBrightOrange starting))
elif QPKGs.IsStopping.Exist "$package_name"; then
package_status_notes+=($(ColourTextBrightOrange stopping))
elif QPKGs.IsRestarting.Exist "$package_name"; then
package_status_notes+=($(ColourTextBrightOrange restarting))
elif QPKGs.IsStarted.Exist "$package_name"; then
package_status_notes+=($(ColourTextBrightGreen started))
elif QPKGs.IsNtStarted.Exist "$package_name"; then
package_status_notes+=($(ColourTextBrightRed stopped))
fi
if QPKGs.ScUpgradable.Exist "$package_name"; then
package_ver="$(QPKG.Local.Ver "$package_name") $(ColourTextBrightOrange "($(QPKG.Avail.Ver "$package_name"))")"
package_status_notes+=($(ColourTextBrightOrange upgradable))
else
package_ver=$(QPKG.Avail.Ver "$package_name")
fi
if QPKGs.IsNtOk.Exist "$package_name"; then
package_status_notes+=("($(ColourTextBrightRed failed))")
elif QPKGs.IsOk.Exist "$package_name"; then
package_status_notes+=("($(ColourTextBrightGreen ok))")
elif QPKGs.IsUnknown.Exist "$package_name"; then
package_status_notes+=("($(ColourTextBrightOrange unknown))")
fi
for ((index=0; index<=((${#package_status_notes[@]}-1)); index++)); do
package_status+=${package_status_notes[$index]}
[[ $((index+2)) -le ${#package_status_notes[@]} ]] && package_status+=', '
done
package_name_formatted=$package_name
fi
DisplayAsHelpPackageNameVerStatus "$package_name_formatted" "$package_status" "$package_ver" "$(QPKG.InstallationPath "$package_name")"
fi
done
Display; Self.LineSpace.Set
done
QPKGs.Actions.List
QPKGs.States.List
return 0
}
QPKGs.IsBackedUp.Show()
{
local package=''
QPKGs.States.Build
DisableDebugToArchiveAndFile
for package in $(QPKGs.IsBackedUp.Array); do
Display "$package"
done
return 0
}
QPKGs.IsNtBackedUp.Show()
{
local package=''
QPKGs.States.Build
DisableDebugToArchiveAndFile
for package in $(QPKGs.IsNtBackedUp.Array); do
Display "$package"
done
return 0
}
QPKGs.IsInstalled.Show()
{
local package=''
QPKGs.States.Build
DisableDebugToArchiveAndFile
for package in $(QPKGs.IsInstalled.Array); do
Display "$package"
done
return 0
}
QPKGs.ScInstallable.Show()
{
local package=''
QPKGs.States.Build
DisableDebugToArchiveAndFile
for package in $(QPKGs.ScInstallable.Array); do
Display "$package"
done
return 0
}
QPKGs.IsNtInstalled.Show()
{
local package=''
QPKGs.States.Build
DisableDebugToArchiveAndFile
for package in $(QPKGs.IsNtInstalled.Array); do
Display "$package"
done
return 0
}
QPKGs.IsStarted.Show()
{
local package=''
QPKGs.States.Build
DisableDebugToArchiveAndFile
for package in $(QPKGs.IsStarted.Array); do
Display "$package"
done
return 0
}
QPKGs.IsNtStarted.Show()
{
local package=''
QPKGs.States.Build
DisableDebugToArchiveAndFile
for package in $(QPKGs.IsNtStarted.Array); do
Display "$package"
done
return 0
}
QPKGs.ScUpgradable.Show()
{
local package=''
QPKGs.States.Build
DisableDebugToArchiveAndFile
for package in $(QPKGs.ScUpgradable.Array); do
Display "$package"
done
return 0
}
QPKGs.ScStandalone.Show()
{
local package=''
QPKGs.States.Build
DisableDebugToArchiveAndFile
for package in $(QPKGs.ScStandalone.Array); do
Display "$package"
done
return 0
}
QPKGs.ScDependent.Show()
{
local package=''
QPKGs.States.Build
DisableDebugToArchiveAndFile
for package in $(QPKGs.ScDependent.Array); do
Display "$package"
done
return 0
}
SendParentChangeEnv()
{
WriteMsgToActionPipe env "$1" '' ''
}
SendPackageStateChange()
{
WriteMsgToActionPipe change "$1" package "$PACKAGE_NAME"
}
SendActionStatus()
{
WriteMsgToActionPipe status "$1" package "$PACKAGE_NAME"
}
WriteMsgToActionPipe()
{
[[ $msg_pipe_fd != null && -e /proc/$$/fd/$msg_pipe_fd ]] && echo "$1#$2#$3#$4" >&$msg_pipe_fd
}
FindNextFD()
{
local -i fd=-1
for fd in {10..100}; do
if [[ ! -e /proc/$$/fd/$fd ]]; then
echo "$fd"
return 0
fi
done
return 1
}
MarkThisActionForkAsStarted()
{
[[ -n ${proc_fork_pathfile:-} ]] && touch "$proc_fork_pathfile"
}
MarkThisActionForkAsOk()
{
[[ -n ${proc_fork_pathfile:-} && -e $proc_fork_pathfile ]] && mv "$proc_fork_pathfile" "$proc_ok_pathfile"
SendActionStatus Ok
}
MarkThisActionForkAsSkippedOK()
{
[[ -n ${proc_fork_pathfile:-} && -e $proc_fork_pathfile ]] && mv "$proc_fork_pathfile" "$proc_skipok_pathfile"
SendActionStatus So
}
MarkThisActionForkAsSkipped()
{
[[ -n ${proc_fork_pathfile:-} && -e $proc_fork_pathfile ]] && mv "$proc_fork_pathfile" "$proc_skip_pathfile"
SendActionStatus Sk
}
MarkThisActionForkAsSkippedError()
{
[[ -n ${proc_fork_pathfile:-} && -e $proc_fork_pathfile ]] && mv "$proc_fork_pathfile" "$proc_skip_error_pathfile"
SendActionStatus Se
}
MarkThisActionForkAsFailed()
{
[[ -n ${proc_fork_pathfile:-} && -e $proc_fork_pathfile ]] && mv "$proc_fork_pathfile" "$proc_fail_pathfile"
SendActionStatus Er
}
NoteIPKAcAsOk()
{
IPKs.AcTo"$(Capitalise "$2")".Remove "$1"
IPKs.AcOk"$(Capitalise "$2")".Add "$1"
return 0
}
NoteIPKAcAsEr()
{
local msg="failing request to $2 $(FormatAsPackName "$1")"
[[ -n ${3:-} ]] && msg+=" as $3"
DebugAsError "$msg" >&2
IPKs.AcTo"$(Capitalise "$2")".Remove "$1"
IPKs.AcEr"$(Capitalise "$2")".Add "$1"
return 0
}
ModPathToEntware()
{
local opkg_prefix=/opt/bin:/opt/sbin
local temp=''
if QPKGs.IsStarted.Exist Entware; then
[[ $PATH =~ $opkg_prefix ]] && return
temp="$($SED_CMD "s|$opkg_prefix:||" <<< "$PATH:")"    
export PATH="$opkg_prefix:${temp%:}"                   
DebugAsDone 'prepended $PATH to Entware'
DebugVar PATH
elif ! QPKGs.IsStarted.Exist Entware; then
! [[ $PATH =~ $opkg_prefix ]] && return
temp="$($SED_CMD "s|$opkg_prefix:||" <<< "$PATH:")"    
export PATH="${temp%:}"                                
DebugAsDone 'removed $PATH to Entware'
DebugVar PATH
fi
return 0
}
GetCPUInfo()
{
if $GREP_CMD -q '^model name' /proc/cpuinfo; then
$GREP_CMD '^model name' /proc/cpuinfo | $HEAD_CMD -n1 | $SED_CMD 's|^.*: ||'
elif $GREP_CMD -q '^Processor name' /proc/cpuinfo; then
$GREP_CMD '^Processor name' /proc/cpuinfo | $HEAD_CMD -n1 | $SED_CMD 's|^.*: ||'
else
echo unknown
return 1
fi
return 0
}
GetArch()
{
$UNAME_CMD -m
}
GetKernel()
{
$UNAME_CMD -r
}
GetPlatform()
{
$GETCFG_CMD '' Platform -d unknown -f /etc/platform.conf
}
GetDefVol()
{
$GETCFG_CMD SHARE_DEF defVolMP -f /etc/config/def_share.info
}
OS.IsAllowUnsignedPackages()
{
[[ $($GETCFG_CMD 'QPKG Management' Ignore_Cert) = TRUE ]]
}
GetRepoURLFromStoreID()
{
[[ -n ${1:-} ]] || return
$GETCFG_CMD "$1" u -d unknown -f /etc/config/3rd_pkg_v2.conf
}
GetUptime()
{
raw=$(</proc/uptime)
FormatSecsToHoursMinutesSecs "${raw%%.*}"
}
GetTimeInShell()
{
local duration=0
if [[ -n ${LOADER_SCRIPT_PPID:-} ]]; then
duration=$(ps -o pid,etime | $GREP_CMD $LOADER_SCRIPT_PPID | $HEAD_CMD -n1)
fi
FormatLongMinutesSecs "${duration:6}"
}
GetSysLoadAverages()
{
$UPTIME_CMD | $SED_CMD 's|.*load average: ||' | $AWK_CMD -F', ' '{print "1m:"$1", 5m:"$2", 15m:"$3}'
}
GetCPUCores()
{
local num=$($GREP_CMD -c '^processor' /proc/cpuinfo)
[[ $num -eq 0 ]] && num=$($GREP_CMD -c '^Processor' /proc/cpuinfo)
echo "$num"
}
GetInstalledRAM()
{
$GREP_CMD MemTotal /proc/meminfo | $SED_CMD 's|.*: ||;s|kB||;s| ||g'
}
GetFirmwareVer()
{
$GETCFG_CMD System Version -f /etc/config/uLinux.conf
}
GetFirmwareBuild()
{
$GETCFG_CMD System Number -f /etc/config/uLinux.conf
}
GetFirmwareDate()
{
$GETCFG_CMD System 'Build Number' -f /etc/config/uLinux.conf
}
GetQnapOS()
{
if $GREP_CMD -q zfs /proc/filesystems; then
echo 'QuTS hero'
else
echo QTS
fi
}
GetQPKGArch()
{
case $NAS_ARCH in
x86_64)
[[ ${NAS_FIRMWARE_VER//.} -ge 430 ]] && echo x64 || echo x86
;;
i686|x86)
echo x86
;;
armv5tel)
echo x19
;;
armv7l)
case $NAS_PLATFORM in
ARM_MS)
echo x31
;;
ARM_AL)
echo x41
;;
*)
echo none
esac
;;
aarch64)
echo a64
;;
*)
echo none
esac
}
GetEntwareType()
{
if QPKG.IsInstalled Entware; then
if [[ -e /opt/etc/passwd ]]; then
if [[ -L /opt/etc/passwd ]]; then
echo std
else
echo alt
fi
else
echo none
fi
fi
}
Self.Error.Set()
{
[[ $(type -t QPKGs.SkProc.Init) = function ]] && QPKGs.SkProc.Set
Self.Error.IsSet && return
_script_error_flag_=true
DebugVar _script_error_flag_
}
Self.Error.IsSet()
{
[[ ${_script_error_flag_:-} = true ]]
}
Self.Error.IsNt()
{
[[ ${_script_error_flag_:-} != true ]]
}
ShowSummary()
{
local state=''
local action=''
for state in "${PACKAGE_STATES[@]}"; do
for action in "${PACKAGE_ACTIONS[@]}"; do
case $action in
Disable|Enable)
continue       
esac
QPKGs.Ac${action}.Is${state}.IsSet && QPKGs.AcOk${action}.IsNone && ShowAsWarn "no QPKGs were able to $(Lowercase "$action")"
done
done
return 0
}
ClaimLockFile()
{
readonly LOCK_PATHFILE=${1:?null}
if [[ -e $LOCK_PATHFILE && -d /proc/$(<"$LOCK_PATHFILE") && $(</proc/"$(<"$LOCK_PATHFILE")"/cmdline) =~ $MANAGER_FILE ]]; then
ShowAsAbort "another instance is running (PID: $(<"$LOCK_PATHFILE"))"
return 1
fi
echo "$$" > "$LOCK_PATHFILE"
return 0
}
ReleaseLockFile()
{
[[ -e ${LOCK_PATHFILE:?null} ]] && rm -f "$LOCK_PATHFILE"
}
DisableDebugToArchiveAndFile()
{
Self.Debug.ToArchive.UnSet
Self.Debug.ToFile.UnSet
}
_QPKG.Reassign_()
{
DebugForkFuncEn
PACKAGE_NAME=${1:?package name null}
local -i result_code=0
local -r LOG_PATHFILE=$LOGS_PATH/$PACKAGE_NAME.$REASSIGN_LOG_FILE
local package_store_id=$(QPKG.StoreID "$PACKAGE_NAME")
if ! QPKGs.IsInstalled.Exist "$PACKAGE_NAME"; then
SaveActionResultToLog "$PACKAGE_NAME" Reassignment skipped 'not installed'
MarkThisActionForkAsSkipped
DebugForkFuncEx 2
elif [[ $package_store_id = sherpa ]]; then
SaveActionResultToLog "$PACKAGE_NAME" Reassignment skipped-ok 'already assigned to sherpa'
MarkThisActionForkAsSkipped
DebugForkFuncEx 0
fi
DebugAsProc "reassigning $(FormatAsPackName "$PACKAGE_NAME")"
RunAndLog "$SETCFG_CMD $PACKAGE_NAME store '' -f /etc/config/qpkg.conf" "$LOG_PATHFILE" log:failure-only
result_code=$?
if [[ $result_code -eq 0 ]]; then
SaveActionResultToLog "$PACKAGE_NAME" Reassignment ok
SendPackageStateChange IsReassigned
MarkThisActionForkAsOk
else
SaveActionResultToLog "$PACKAGE_NAME" Reassign failed "$result_code"
result_code=1   
MarkThisActionForkAsFailed
fi
DebugForkFuncEx $result_code
}
SaveActionResultToLog()
{
local var_name=${FUNCNAME[1]}_STARTSECONDS
local var_safe_name=${var_name//[.-]/_}
local duration="$(CalcMilliDifference "${!var_safe_name}" "$($DATE_CMD +%s%N)")"
echo "$(/bin/date +%s)#${2:?action empty}#${1:?package name empty}#${3:?result empty}#$duration#${4:-}" >> "$ACTIONS_LOG_PATHFILE"
case $3 in
ok)
DebugAsInfo "${4:-}"
;;
skipped-ok)
DebugAsInfo "${4:?reason empty}"
;;
skipped)
DebugAsWarn "${4:?reason empty}"
;;
failed|skipped-error)
DebugAsError "${4:?reason empty}"
esac
return 0
}
_QPKG.Download_()
{
DebugForkFuncEn
PACKAGE_NAME=${1:?package name null}
local -i result_code=0
local -r REMOTE_URL=$(QPKG.URL "$PACKAGE_NAME")
local -r REMOTE_FILENAME=$($BASENAME_CMD "$REMOTE_URL")
local -r REMOTE_MD5=$(QPKG.MD5 "$PACKAGE_NAME")
local -r LOCAL_PATHFILE=$QPKG_DL_PATH/$REMOTE_FILENAME
local -r LOCAL_FILENAME=$($BASENAME_CMD "$LOCAL_PATHFILE")
local -r LOG_PATHFILE=$LOGS_PATH/$LOCAL_FILENAME.$DOWNLOAD_LOG_FILE
if [[ -z $REMOTE_URL || -z $REMOTE_MD5 ]]; then
SaveActionResultToLog "$PACKAGE_NAME" Download skipped 'NAS is unsupported'
MarkThisActionForkAsSkipped
result_code=2
elif [[ -f $LOCAL_PATHFILE ]]; then
if FileMatchesMD5 "$LOCAL_PATHFILE" "$REMOTE_MD5"; then
SaveActionResultToLog "$PACKAGE_NAME" Download skipped-ok "existing file $(FormatAsFileName "$LOCAL_FILENAME") checksum correct"
MarkThisActionForkAsSkippedOK
DebugForkFuncEx 0
else
DebugInfo "deleting $(FormatAsFileName "$LOCAL_FILENAME") as checksum is incorrect"
rm -f "$LOCAL_PATHFILE"
fi
fi
if [[ $result_code -gt 0 ]]; then
DebugForkFuncEx $result_code
fi
if [[ ! -f $LOCAL_PATHFILE ]]; then
DebugAsProc "downloading $(FormatAsFileName "$REMOTE_FILENAME")"
[[ -e $LOG_PATHFILE ]] && rm -f "$LOG_PATHFILE"
RunAndLog "$CURL_CMD${curl_insecure_arg} --output $LOCAL_PATHFILE $REMOTE_URL" "$LOG_PATHFILE" log:failure-only
result_code=$?
if [[ $result_code -eq 0 ]]; then
if FileMatchesMD5 "$LOCAL_PATHFILE" "$REMOTE_MD5"; then
SaveActionResultToLog "$PACKAGE_NAME" Downloaded ok
SendPackageStateChange IsDownloaded
MarkThisActionForkAsOk
else
SaveActionResultToLog "$PACKAGE_NAME" Downloaded failed "downloaded file $(FormatAsFileName "$LOCAL_PATHFILE") has incorrect checksum"
SendPackageStateChange IsNtDownloaded
result_code=1
MarkThisActionForkAsFailed
fi
else
SaveActionResultToLog "$PACKAGE_NAME" Download failed "$result_code"
result_code=1   
MarkThisActionForkAsFailed
fi
fi
DebugForkFuncEx $result_code
}
_QPKG.Install_()
{
DebugForkFuncEn
PACKAGE_NAME=${1:?package name null}
local -i result_code=0
local debug_cmd=''
if QPKGs.IsInstalled.Exist "$PACKAGE_NAME"; then
SaveActionResultToLog "$PACKAGE_NAME" Install skipped 'already installed'
result_code=2
elif ! QPKG.URL "$PACKAGE_NAME" &>/dev/null; then
SaveActionResultToLog "$PACKAGE_NAME" Install skipped 'NAS is unsupported'
result_code=2
elif ! QPKG.MinRAM "$PACKAGE_NAME" &>/dev/null; then
SaveActionResultToLog "$PACKAGE_NAME" Install skipped 'NAS has insufficient RAM'
result_code=2
fi
if [[ $result_code -eq 2 ]]; then
MarkThisActionForkAsSkipped
DebugForkFuncEx $result_code
fi
local local_pathfile=$(QPKG.PathFilename "$PACKAGE_NAME")
if [[ ${local_pathfile##*.} = zip ]]; then
$UNZIP_CMD -nq "$local_pathfile" -d "$QPKG_DL_PATH"
local_pathfile=${local_pathfile%.*}
fi
if [[ -z $local_pathfile ]]; then
SaveActionResultToLog "$PACKAGE_NAME" Install skipped-error 'no local file found for processing: please report this issue'
MarkThisActionForkAsSkippedError
DebugForkFuncEx 2
fi
if [[ $PACKAGE_NAME = Entware ]] && ! QPKGs.IsInstalled.Exist Entware && QPKGs.AcToInstall.Exist Entware; then
local -r OPT_PATH=/opt
local -r OPT_BACKUP_PATH=/opt.orig
if [[ -d $OPT_PATH && ! -L $OPT_PATH && ! -e $OPT_BACKUP_PATH ]]; then
DebugAsProc 'backup original /opt'
mv "$OPT_PATH" "$OPT_BACKUP_PATH"
DebugAsDone 'complete'
fi
fi
local -r TARGET_FILE=$($BASENAME_CMD "$local_pathfile")
local -r LOG_PATHFILE=$LOGS_PATH/$TARGET_FILE.$INSTALL_LOG_FILE
local target_path=''
DebugAsProc "installing $(FormatAsPackName "$PACKAGE_NAME")"
Self.Debug.ToScreen.IsSet && debug_cmd='DEBUG_QPKG=true '
[[ ${QPKGs_were_installed_name[*]:-} == *"$PACKAGE_NAME"* ]] && target_path="QINSTALL_PATH=$(QPKG.OriginalPath "$PACKAGE_NAME") "
RunAndLog "${debug_cmd}${target_path}${SH_CMD} $local_pathfile" "$LOG_PATHFILE" log:failure-only 10
result_code=$?
if [[ $result_code -eq 0 || $result_code -eq 10 ]]; then
UpdateColourisation
QPKG.LogServiceStatus "$PACKAGE_NAME"
SendPackageStateChange IsInstalled
if QPKG.IsEnabled "$PACKAGE_NAME"; then
SendPackageStateChange IsEnabled
else
SendPackageStateChange IsNtEnabled
fi
if QPKG.IsStarted "$PACKAGE_NAME"; then
SendPackageStateChange IsStarted
else
SendPackageStateChange IsNtStarted
fi
local current_ver=$(QPKG.Local.Ver "$PACKAGE_NAME")
SaveActionResultToLog "$PACKAGE_NAME" Installed ok "version $current_ver"
if [[ $PACKAGE_NAME = Entware ]]; then
ModPathToEntware
SendParentChangeEnv 'ModPathToEntware'
PatchEntwareService
if [[ -L ${OPT_PATH:-} && -d ${OPT_BACKUP_PATH:-} ]]; then
DebugAsProc 'restoring original /opt'
mv "$OPT_BACKUP_PATH"/* "$OPT_PATH" && rm -rf "$OPT_BACKUP_PATH"
DebugAsDone 'complete'
fi
DebugAsProc 'installing essential IPKs'
RunAndLog "$OPKG_CMD install --force-overwrite $ESSENTIAL_IPKS --cache $IPK_CACHE_PATH --tmp-dir $IPK_DL_PATH" "$LOGS_PATH/ipks.essential.$INSTALL_LOG_FILE" log:failure-only
SendParentChangeEnv 'HideKeystrokes'
SendParentChangeEnv 'HideCursor'
UpdateColourisation
DebugAsDone 'installed essential IPKs'
fi
result_code=0   
MarkThisActionForkAsOk
else
SaveActionResultToLog "$PACKAGE_NAME" Install failed "$result_code"
result_code=1   
MarkThisActionForkAsFailed
fi
QPKG.ClearAppCenterNotifier "$PACKAGE_NAME"
DebugForkFuncEx $result_code
}
_QPKG.Reinstall_()
{
DebugForkFuncEn
PACKAGE_NAME=${1:?package name null}
local -i result_code=0
local debug_cmd=''
if ! QPKGs.IsInstalled.Exist "$PACKAGE_NAME"; then
SaveActionResultToLog "$PACKAGE_NAME" Reinstall skipped "not installed, please use 'install' instead"
MarkThisActionForkAsSkipped
DebugForkFuncEx 2
fi
local local_pathfile=$(QPKG.PathFilename "$PACKAGE_NAME")
if [[ ${local_pathfile##*.} = zip ]]; then
$UNZIP_CMD -nq "$local_pathfile" -d "$QPKG_DL_PATH"
local_pathfile=${local_pathfile%.*}
fi
if [[ -z $local_pathfile ]]; then
SaveActionResultToLog "$PACKAGE_NAME" Reinstall skipped-error 'no local file found for processing, please report this issue'
MarkThisActionForkAsSkippedError
DebugForkFuncEx 2
fi
local -r TARGET_FILE=$($BASENAME_CMD "$local_pathfile")
local -r LOG_PATHFILE=$LOGS_PATH/$TARGET_FILE.$REINSTALL_LOG_FILE
local target_path=''
DebugAsProc "reinstalling $(FormatAsPackName "$PACKAGE_NAME")"
Self.Debug.ToScreen.IsSet && debug_cmd='DEBUG_QPKG=true '
QPKG.IsInstalled "$PACKAGE_NAME" && target_path="QINSTALL_PATH=$($DIRNAME_CMD "$(QPKG.InstallationPath $PACKAGE_NAME)") "
RunAndLog "${debug_cmd}${target_path}${SH_CMD} $local_pathfile" "$LOG_PATHFILE" log:failure-only 10
result_code=$?
if [[ $result_code -eq 0 || $result_code -eq 10 ]]; then
QPKG.LogServiceStatus "$PACKAGE_NAME"
if QPKG.IsEnabled "$PACKAGE_NAME"; then
SendPackageStateChange IsEnabled
else
SendPackageStateChange IsNtEnabled
fi
if QPKG.IsStarted "$PACKAGE_NAME"; then
SendPackageStateChange IsStarted
else
SendPackageStateChange IsNtStarted
fi
local current_ver=$(QPKG.Local.Ver "$PACKAGE_NAME")
SaveActionResultToLog "$PACKAGE_NAME" Reinstalled ok "version $current_ver"
result_code=0   
MarkThisActionForkAsOk
else
SaveActionResultToLog "$PACKAGE_NAME" Reinstall failed "$result_code"
result_code=1   
MarkThisActionForkAsFailed
fi
QPKG.ClearAppCenterNotifier "$PACKAGE_NAME"
DebugForkFuncEx $result_code
}
_QPKG.Upgrade_()
{
DebugForkFuncEn
PACKAGE_NAME=${1:?package name null}
local -i result_code=0
local debug_cmd=''
if ! QPKGs.IsInstalled.Exist "$PACKAGE_NAME"; then
SaveActionResultToLog "$PACKAGE_NAME" Upgrade skipped 'not installed'
result_code=2
elif ! QPKGs.ScUpgradable.Exist "$PACKAGE_NAME"; then
SaveActionResultToLog "$PACKAGE_NAME" Upgrade skipped-ok 'no new package is available'
MarkThisActionForkAsSkippedOK
DebugForkFuncEx 0
fi
local package_store_id=$(QPKG.StoreID "$PACKAGE_NAME")
if [[ $package_store_id != sherpa ]]; then
SaveActionResultToLog "$PACKAGE_NAME" Upgrade skipped "assigned to another repository, please 'reassign' it first"
result_code=2
fi
if [[ $result_code -eq 2 ]]; then
MarkThisActionForkAsSkipped
DebugForkFuncEx $result_code
fi
local local_pathfile=$(QPKG.PathFilename "$PACKAGE_NAME")
if [[ ${local_pathfile##*.} = zip ]]; then
$UNZIP_CMD -nq "$local_pathfile" -d "$QPKG_DL_PATH"
local_pathfile=${local_pathfile%.*}
fi
if [[ -z $local_pathfile ]]; then
SaveActionResultToLog "$PACKAGE_NAME" Upgrade skipped-error 'no local file found for processing, please report this issue'
MarkThisActionForkAsSkippedError
DebugForkFuncEx 2
fi
local -r TARGET_FILE=$($BASENAME_CMD "$local_pathfile")
local -r LOG_PATHFILE=$LOGS_PATH/$TARGET_FILE.$UPGRADE_LOG_FILE
local prev_ver=$(QPKG.Local.Ver "$PACKAGE_NAME")
local target_path=''
DebugAsProc "upgrading $(FormatAsPackName "$PACKAGE_NAME")"
Self.Debug.ToScreen.IsSet && debug_cmd='DEBUG_QPKG=true '
QPKG.IsInstalled "$PACKAGE_NAME" && target_path="QINSTALL_PATH=$($DIRNAME_CMD "$(QPKG.InstallationPath $PACKAGE_NAME)") "
RunAndLog "${debug_cmd}${target_path}${SH_CMD} $local_pathfile" "$LOG_PATHFILE" log:failure-only 10
result_code=$?
if [[ $result_code -eq 0 || $result_code -eq 10 ]]; then
QPKG.LogServiceStatus "$PACKAGE_NAME"
SendPackageStateChange ScNtUpgradable
if QPKG.IsEnabled "$PACKAGE_NAME"; then
SendPackageStateChange IsEnabled
else
SendPackageStateChange IsNtEnabled
fi
if QPKG.IsStarted "$PACKAGE_NAME"; then
SendPackageStateChange IsStarted
else
SendPackageStateChange IsNtStarted
fi
local current_ver=$(QPKG.Local.Ver "$PACKAGE_NAME")
if [[ $current_ver = "$prev_ver" ]]; then
SaveActionResultToLog "$PACKAGE_NAME" Upgraded ok "version $current_ver"
else
SaveActionResultToLog "$PACKAGE_NAME" Upgraded ok "from version $prev_ver to version $current_ver"
fi
result_code=0   
MarkThisActionForkAsOk
else
SaveActionResultToLog "$PACKAGE_NAME" Upgrade failed "$result_code"
result_code=1   
MarkThisActionForkAsFailed
fi
QPKG.ClearAppCenterNotifier "$PACKAGE_NAME"
DebugForkFuncEx $result_code
}
_QPKG.Uninstall_()
{
DebugForkFuncEn
PACKAGE_NAME=${1:?package name null}
local -i result_code=0
local debug_cmd=''
if QPKGs.IsNtInstalled.Exist "$PACKAGE_NAME"; then
SaveActionResultToLog "$PACKAGE_NAME" Uninstall skipped 'not installed'
MarkThisActionForkAsSkipped
DebugForkFuncEx 2
elif [[ $PACKAGE_NAME = sherpa ]]; then
SaveActionResultToLog "$PACKAGE_NAME" Uninstall skipped-ok "it's needed here! 😉"
MarkThisActionForkAsSkippedOK
DebugForkFuncEx 0
fi
local -r QPKG_UNINSTALLER_PATHFILE=$(QPKG.InstallationPath "$PACKAGE_NAME")/.uninstall.sh
local -r LOG_PATHFILE=$LOGS_PATH/$PACKAGE_NAME.$UNINSTALL_LOG_FILE
[[ $PACKAGE_NAME = Entware ]] && SavePackageLists
if [[ -e $QPKG_UNINSTALLER_PATHFILE ]]; then
DebugAsProc "uninstalling $(FormatAsPackName "$PACKAGE_NAME")"
Self.Debug.ToScreen.IsSet && debug_cmd='DEBUG_QPKG=true '
if [[ $PACKAGE_NAME = Entware ]]; then
SendParentChangeEnv 'ShowCursor'
fi
RunAndLog "${debug_cmd}${SH_CMD} $QPKG_UNINSTALLER_PATHFILE" "$LOG_PATHFILE" log:failure-only
result_code=$?
if [[ $result_code -eq 0 ]]; then
SaveActionResultToLog "$PACKAGE_NAME" Uninstall ok
/sbin/rmcfg "$PACKAGE_NAME" -f /etc/config/qpkg.conf
DebugAsDone 'removed icon information from App Center'
if [[ $PACKAGE_NAME = Entware ]]; then
ModPathToEntware
SendParentChangeEnv 'ModPathToEntware'
UpdateColourisation
fi
SendPackageStateChange IsNtInstalled
SendPackageStateChange IsNtStarted
SendPackageStateChange IsNtEnabled
MarkThisActionForkAsOk
else
SaveActionResultToLog "$PACKAGE_NAME" Uninstall failed "$result_code"
if [[ $PACKAGE_NAME = Entware ]]; then
SendParentChangeEnv 'HideCursor'
fi
result_code=1   
MarkThisActionForkAsFailed
fi
else
SaveActionResultToLog "$PACKAGE_NAME" Uninstall failed '.uninstall.sh script is missing'
MarkThisActionForkAsFailed
fi
DebugForkFuncEx $result_code
}
_QPKG.Restart_()
{
DebugForkFuncEn
PACKAGE_NAME=${1:?package name null}
local -i result_code=0
local debug_cmd=''
if QPKGs.IsNtInstalled.Exist "$PACKAGE_NAME"; then
SaveActionResultToLog "$PACKAGE_NAME" Restart skipped 'not installed'
MarkThisActionForkAsSkipped
DebugForkFuncEx 2
fi
QPKG.ClearServiceStatus "$PACKAGE_NAME"
local -r PACKAGE_INIT_PATHFILE=$(QPKG.ServicePathFile "$PACKAGE_NAME")
local -r LOG_PATHFILE=$LOGS_PATH/$PACKAGE_NAME.$RESTART_LOG_FILE
QPKG.Enable "$PACKAGE_NAME"
result_code=$?
if [[ $result_code -eq 0 ]]; then
DebugAsProc "restarting $(FormatAsPackName "$PACKAGE_NAME")"
Self.Debug.ToScreen.IsSet && debug_cmd='DEBUG_QPKG=true '
RunAndLog "${debug_cmd}${PACKAGE_INIT_PATHFILE} restart" "$LOG_PATHFILE" log:failure-only
result_code=$?
fi
if [[ $result_code -eq 0 ]]; then
QPKG.LogServiceStatus "$PACKAGE_NAME"
SaveActionResultToLog "$PACKAGE_NAME" Restarted ok
SendPackageStateChange IsRestarted
MarkThisActionForkAsOk
else
SaveActionResultToLog "$PACKAGE_NAME" Restart failed "$result_code"
SendPackageStateChange IsNtRestarted
result_code=1   
MarkThisActionForkAsFailed
fi
QPKG.ClearAppCenterNotifier "$PACKAGE_NAME"
DebugForkFuncEx $result_code
}
_QPKG.Start_()
{
DebugForkFuncEn
PACKAGE_NAME=${1:?package name null}
local -i result_code=0
local debug_cmd=''
if QPKGs.IsNtInstalled.Exist "$PACKAGE_NAME"; then
SaveActionResultToLog "$PACKAGE_NAME" Start skipped 'not installed'
MarkThisActionForkAsSkipped
DebugForkFuncEx 2
elif QPKGs.IsStarted.Exist "$PACKAGE_NAME"; then
SaveActionResultToLog "$PACKAGE_NAME" Start skipped 'already started'
MarkThisActionForkAsSkipped
DebugForkFuncEx 0
fi
QPKG.ClearServiceStatus "$PACKAGE_NAME"
local -r PACKAGE_INIT_PATHFILE=$(QPKG.ServicePathFile "$PACKAGE_NAME")
local -r LOG_PATHFILE=$LOGS_PATH/$PACKAGE_NAME.$START_LOG_FILE
QPKG.Enable "$PACKAGE_NAME"
result_code=$?
if [[ $result_code -eq 0 ]]; then
DebugAsProc "starting $(FormatAsPackName "$PACKAGE_NAME")"
Self.Debug.ToScreen.IsSet && debug_cmd='DEBUG_QPKG=true '
RunAndLog "${debug_cmd}${PACKAGE_INIT_PATHFILE} start" "$LOG_PATHFILE" log:failure-only
result_code=$?
fi
if [[ $result_code -eq 0 ]]; then
QPKG.LogServiceStatus "$PACKAGE_NAME"
SaveActionResultToLog "$PACKAGE_NAME" Started ok
if [[ $PACKAGE_NAME = Entware ]]; then
ModPathToEntware
SendParentChangeEnv 'ModPathToEntware'
UpdateColourisation
fi
SendPackageStateChange IsStarted
MarkThisActionForkAsOk
else
SaveActionResultToLog "$PACKAGE_NAME" Start failed "$result_code"
SendPackageStateChange IsNtStarted
result_code=1   
MarkThisActionForkAsFailed
fi
QPKG.ClearAppCenterNotifier "$PACKAGE_NAME"
DebugForkFuncEx $result_code
}
_QPKG.Stop_()
{
DebugForkFuncEn
PACKAGE_NAME=${1:?package name null}
local -i result_code=0
local debug_cmd=''
if QPKGs.IsNtInstalled.Exist "$PACKAGE_NAME"; then
SaveActionResultToLog "$PACKAGE_NAME" Stop skipped 'not installed'
MarkThisActionForkAsSkipped
DebugForkFuncEx 2
elif QPKGs.IsNtStarted.Exist "$PACKAGE_NAME"; then
SaveActionResultToLog "$PACKAGE_NAME" Stop skipped 'already stopped'
MarkThisActionForkAsSkipped
DebugForkFuncEx 0
elif [[ $PACKAGE_NAME = sherpa ]]; then
SaveActionResultToLog "$PACKAGE_NAME" Stop skipped-ok "it's needed here! 😉"
MarkThisActionForkAsSkippedOK
DebugForkFuncEx 0
fi
QPKG.ClearServiceStatus "$PACKAGE_NAME"
local -r PACKAGE_INIT_PATHFILE=$(QPKG.ServicePathFile "$PACKAGE_NAME")
local -r LOG_PATHFILE=$LOGS_PATH/$PACKAGE_NAME.$STOP_LOG_FILE
DebugAsProc "stopping $(FormatAsPackName "$PACKAGE_NAME")"
Self.Debug.ToScreen.IsSet && debug_cmd='DEBUG_QPKG=true '
[[ $PACKAGE_NAME = Entware ]] && UpdateColourisation
RunAndLog "${debug_cmd}${PACKAGE_INIT_PATHFILE} stop" "$LOG_PATHFILE" log:failure-only
result_code=$?
if [[ $result_code -eq 0 ]]; then
QPKG.Disable "$PACKAGE_NAME"
result_code=$?
fi
if [[ $result_code -eq 0 ]]; then
QPKG.LogServiceStatus "$PACKAGE_NAME"
SaveActionResultToLog "$PACKAGE_NAME" Stopped ok
if [[ $PACKAGE_NAME = Entware ]]; then
ModPathToEntware
SendParentChangeEnv 'ModPathToEntware'
UpdateColourisation
fi
SendPackageStateChange IsNtStarted
MarkThisActionForkAsOk
else
SaveActionResultToLog "$PACKAGE_NAME" Stop failed "$result_code"
result_code=1   
MarkThisActionForkAsFailed
fi
QPKG.ClearAppCenterNotifier "$PACKAGE_NAME"
DebugForkFuncEx $result_code
}
QPKG.Enable()
{
PACKAGE_NAME=${1:?package name null}
local -i result_code=0
RunAndLog "/sbin/qpkg_service enable $PACKAGE_NAME" "$LOGS_PATH/$PACKAGE_NAME.$ENABLE_LOG_FILE" log:failure-only
result_code=$?
if [[ $result_code -eq 0 ]]; then
SendPackageStateChange IsEnabled
else
result_code=1   
fi
return $result_code
}
QPKG.Disable()
{
PACKAGE_NAME=${1:?package name null}
local -i result_code=0
RunAndLog "/sbin/qpkg_service disable $PACKAGE_NAME" "$LOGS_PATH/$PACKAGE_NAME.$DISABLE_LOG_FILE" log:failure-only
result_code=$?
if [[ $result_code -eq 0 ]]; then
SendPackageStateChange IsNtEnabled
else
result_code=1   
fi
return $result_code
}
_QPKG.Backup_()
{
DebugForkFuncEn
PACKAGE_NAME=${1:?package name null}
local -i result_code=0
local debug_cmd=''
if QPKGs.IsNtInstalled.Exist "$PACKAGE_NAME"; then
SaveActionResultToLog "$PACKAGE_NAME" Backup skipped 'not installed'
result_code=2
elif ! QPKG.IsCanBackup "$PACKAGE_NAME"; then
SaveActionResultToLog "$PACKAGE_NAME" Backup skipped 'does not support backup'
result_code=2
fi
if [[ $result_code -eq 2 ]]; then
MarkThisActionForkAsSkipped
DebugForkFuncEx $result_code
fi
local -r PACKAGE_INIT_PATHFILE=$(QPKG.ServicePathFile "$PACKAGE_NAME")
local -r LOG_PATHFILE=$LOGS_PATH/$PACKAGE_NAME.$BACKUP_LOG_FILE
DebugAsProc "backing-up $(FormatAsPackName "$PACKAGE_NAME") configuration"
Self.Debug.ToScreen.IsSet && debug_cmd='DEBUG_QPKG=true '
RunAndLog "${debug_cmd}${PACKAGE_INIT_PATHFILE} backup" "$LOG_PATHFILE" log:failure-only
result_code=$?
if [[ $result_code -eq 0 ]]; then
QPKG.LogServiceStatus "$PACKAGE_NAME"
SaveActionResultToLog "$PACKAGE_NAME" Backed-up ok
SendPackageStateChange IsBackedUp
MarkThisActionForkAsOk
else
SaveActionResultToLog "$PACKAGE_NAME" Backup failed "$result_code"
result_code=1   
MarkThisActionForkAsFailed
fi
DebugForkFuncEx $result_code
}
_QPKG.Restore_()
{
DebugForkFuncEn
PACKAGE_NAME=${1:?package name null}
local -i result_code=0
local debug_cmd=''
if QPKGs.IsNtInstalled.Exist "$PACKAGE_NAME"; then
SaveActionResultToLog "$PACKAGE_NAME" Restore skipped 'not installed'
result_code=2
elif ! QPKG.IsCanBackup "$PACKAGE_NAME"; then
SaveActionResultToLog "$PACKAGE_NAME" Restore skipped 'does not support restore'
result_code=2
fi
if [[ $result_code -eq 2 ]]; then
MarkThisActionForkAsSkipped
DebugForkFuncEx $result_code
fi
local -r PACKAGE_INIT_PATHFILE=$(QPKG.ServicePathFile "$PACKAGE_NAME")
local -r LOG_PATHFILE=$LOGS_PATH/$PACKAGE_NAME.$RESTORE_LOG_FILE
DebugAsProc "restoring $(FormatAsPackName "$PACKAGE_NAME") configuration"
Self.Debug.ToScreen.IsSet && debug_cmd='DEBUG_QPKG=true '
RunAndLog "${debug_cmd}${PACKAGE_INIT_PATHFILE} restore" "$LOG_PATHFILE" log:failure-only
result_code=$?
if [[ $result_code -eq 0 ]]; then
QPKG.LogServiceStatus "$PACKAGE_NAME"
SaveActionResultToLog "$PACKAGE_NAME" Restored ok
SendPackageStateChange IsRestored
MarkThisActionForkAsOk
else
SaveActionResultToLog "$PACKAGE_NAME" Restore failed "$result_code"
result_code=1   
MarkThisActionForkAsFailed
fi
DebugForkFuncEx $result_code
}
_QPKG.Clean_()
{
DebugForkFuncEn
PACKAGE_NAME=${1:?package name null}
local -i result_code=0
local debug_cmd=''
if QPKGs.IsNtInstalled.Exist "$PACKAGE_NAME"; then
SaveActionResultToLog "$PACKAGE_NAME" Clean skipped 'not installed'
result_code=2
elif ! QPKG.IsCanClean "$PACKAGE_NAME"; then
SaveActionResultToLog "$PACKAGE_NAME" Clean skipped 'does not support cleaning'
result_code=2
fi
if [[ $result_code -eq 2 ]]; then
MarkThisActionForkAsSkipped
DebugForkFuncEx $result_code
fi
local -r PACKAGE_INIT_PATHFILE=$(QPKG.ServicePathFile "$PACKAGE_NAME")
local -r LOG_PATHFILE=$LOGS_PATH/$PACKAGE_NAME.$CLEAN_LOG_FILE
DebugAsProc "cleaning $(FormatAsPackName "$PACKAGE_NAME")"
Self.Debug.ToScreen.IsSet && debug_cmd='DEBUG_QPKG=true '
RunAndLog "${debug_cmd}${PACKAGE_INIT_PATHFILE} clean" "$LOG_PATHFILE" log:failure-only
result_code=$?
if [[ $result_code -eq 0 ]]; then
QPKG.LogServiceStatus "$PACKAGE_NAME"
SaveActionResultToLog "$PACKAGE_NAME" Cleaned ok
SendPackageStateChange IsCleaned
MarkThisActionForkAsOk
else
SaveActionResultToLog "$PACKAGE_NAME" Clean failed "$result_code"
result_code=1   
MarkThisActionForkAsFailed
fi
DebugForkFuncEx $result_code
}
QPKG.ClearAppCenterNotifier()
{
local -r PACKAGE_NAME=${1:?package name null}
[[ -e /sbin/qpkg_cli ]] && /sbin/qpkg_cli --clean "$PACKAGE_NAME"
QPKG.IsNtInstalled "$PACKAGE_NAME" && return 0
$SETCFG_CMD "$PACKAGE_NAME" Status complete -f /etc/config/qpkg.conf
return 0
} &>/dev/null
QPKG.ClearServiceStatus()
{
[[ -e /var/run/${1:?package name null}.last.operation ]] && rm /var/run/"${1:?package name null}".last.operation
} &>/dev/null
QPKG.LogServiceStatus()
{
local -r PACKAGE_NAME=${1:?package name null}
if ! local status=$(QPKG.GetServiceStatus "$PACKAGE_NAME"); then
DebugAsWarn "unable to get status of $(FormatAsPackName "$PACKAGE_NAME") service. It may be a non-sherpa package, or a sherpa package earlier than 200816c that doesn't support service results."
return 1
fi
case $status in
starting|stopping|restarting)
DebugInfo "$(FormatAsPackName "$PACKAGE_NAME") service is $status"
;;
ok)
DebugInfo "$(FormatAsPackName "$PACKAGE_NAME") service action completed OK"
;;
failed)
if [[ -e /var/log/$PACKAGE_NAME.log ]]; then
DebugAsError "$(FormatAsPackName "$PACKAGE_NAME") service action failed. Check $(FormatAsFileName "/var/log/$PACKAGE_NAME.log") for more information"
AddFileToDebug /var/log/$PACKAGE_NAME.log
else
DebugAsError "$(FormatAsPackName "$PACKAGE_NAME") service action failed"
fi
;;
*)
DebugAsWarn "$(FormatAsPackName "$PACKAGE_NAME") service status is unrecognised or unsupported"
esac
return 0
}
QPKG.InstallationPath()
{
$GETCFG_CMD "${1:-sherpa}" Install_Path -f /etc/config/qpkg.conf
}
QPKG.ServicePathFile()
{
$GETCFG_CMD "${1:?package name null}" Shell -d unknown -f /etc/config/qpkg.conf
}
QPKG.Avail.Ver()
{
local -i index=0
local package=''
local prev=''
for index in "${!QPKG_NAME[@]}"; do
package="${QPKG_NAME[$index]}"
[[ $package = "$prev" ]] && continue || prev=$package
if [[ $1 = "$package" ]]; then
echo "${QPKG_VERSION[$index]}"
return 0
fi
done
return 1
}
QPKG.Local.Ver()
{
$GETCFG_CMD "${1:-sherpa}" Version -d unknown -f /etc/config/qpkg.conf
}
QPKG.StoreID()
{
local store=''
store=$($GETCFG_CMD "${1:?package name null}" store -d sherpa -f /etc/config/qpkg.conf)
[[ -z $store ]] && store=sherpa
echo "$store"
return 0
}
QPKG.IsBackupExist()
{
[[ -e $BACKUP_PATH/${1:?package name null}.config.tar.gz ]]
}
QPKG.Author()
{
local -i index=0
for index in "${!QPKG_NAME[@]}"; do
if [[ ${QPKG_NAME[$index]} = "${1:?package name null}" ]]; then
echo "${QPKG_AUTHOR[$index]}"
return 0
fi
done
return 1
}
QPKG.AppAuthor()
{
local -i index=0
for index in "${!QPKG_NAME[@]}"; do
if [[ ${QPKG_NAME[$index]} = "${1:?package name null}" ]]; then
echo "${QPKG_APP_AUTHOR[$index]}"
return 0
fi
done
return 1
}
QPKG.IsCanBackup()
{
local -i index=0
for index in "${!QPKG_NAME[@]}"; do
if [[ ${QPKG_NAME[$index]} = "${1:?package name null}" ]]; then
if ${QPKG_CAN_BACKUP[$index]}; then
return 0
else
break
fi
fi
done
return 1
}
QPKG.IsCanRestartToUpdate()
{
local -i index=0
for index in "${!QPKG_NAME[@]}"; do
if [[ ${QPKG_NAME[$index]} = "${1:?package name null}" ]]; then
if ${QPKG_CAN_RESTART_TO_UPDATE[$index]}; then
return 0
else
break
fi
fi
done
return 1
}
QPKG.IsCanClean()
{
local -i index=0
for index in "${!QPKG_NAME[@]}"; do
if [[ ${QPKG_NAME[$index]} = "${1:?package name null}" ]]; then
if ${QPKG_CAN_CLEAN[$index]}; then
return 0
else
break
fi
fi
done
return 1
}
QPKG.IsCanLog()
{
local -i index=0
for index in "${!QPKG_NAME[@]}"; do
if [[ ${QPKG_NAME[$index]} = "${1:?package name null}" ]]; then
if ${QPKG_CAN_LOG[$index]}; then
return 0
else
break
fi
fi
done
return 1
}
QPKG.IsDependent()
{
local -i index=0
for index in "${!QPKG_NAME[@]}"; do
if [[ ${QPKG_NAME[$index]} = "${1:?package name null}" ]]; then
if [[ -n ${QPKG_DEPENDS_ON[$index]} ]]; then
return 0
else
break
fi
fi
done
return 1
}
QPKG.OriginalPath()
{
local -i index=0
if [[ ${#QPKGs_were_installed_name[@]} -gt 0 ]]; then
for index in "${!QPKGs_were_installed_name[@]}"; do
if [[ ${QPKGs_were_installed_name[$index]} = "${1:?package name null}" ]]; then
echo "${QPKGs_were_installed_path[$index]}"
return 0
fi
done
fi
return 1
}
QPKG.Abbrvs()
{
local -i index=0
for index in "${!QPKG_NAME[@]}"; do
if [[ ${QPKG_NAME[$index]} = "${1:?package name null}" ]]; then
echo "${QPKG_ABBRVS[$index]}"
return 0
fi
done
return 1
}
QPKG.MatchAbbrv()
{
local -a abbs=()
local -i package_index=0
local -i abb_index=0
local -i result_code=1
for package_index in "${!QPKG_NAME[@]}"; do
abbs=(${QPKG_ABBRVS[$package_index]})
for abb_index in "${!abbs[@]}"; do
if [[ ${abbs[$abb_index]} = "$1" ]]; then
Display "${QPKG_NAME[$package_index]}"
result_code=0
break 2
fi
done
done
return $result_code
}
QPKG.PathFilename()
{
local -r URL=$(QPKG.URL "${1:?package name null}")
[[ -n ${URL:-} ]] || return
echo "$QPKG_DL_PATH/$($BASENAME_CMD "$URL")"
return 0
}
QPKG.URL()
{
local -i index=0
for index in "${!QPKG_NAME[@]}"; do
if [[ ${QPKG_NAME[$index]} = "${1:?package name null}" ]] && [[ ${QPKG_ARCH[$index]} = all || ${QPKG_ARCH[$index]} = "$NAS_QPKG_ARCH" ]]; then
echo "${QPKG_URL[$index]}"
return 0
fi
done
return 1
}
QPKG.Desc()
{
local -i index=0
for index in "${!QPKG_NAME[@]}"; do
if [[ ${QPKG_NAME[$index]} = "${1:?package name null}" ]]; then
echo "${QPKG_DESC[$index]}"
return 0
fi
done
return 1
}
QPKG.Note()
{
local -i index=0
for index in "${!QPKG_NAME[@]}"; do
if [[ ${QPKG_NAME[$index]} = "${1:?package name null}" ]]; then
echo "${QPKG_NOTE[$index]}"
return 0
fi
done
return 1
}
QPKG.MD5()
{
local -i index=0
for index in "${!QPKG_NAME[@]}"; do
if [[ ${QPKG_NAME[$index]} = "${1:?package name null}" ]] && [[ ${QPKG_ARCH[$index]} = all || ${QPKG_ARCH[$index]} = "$NAS_QPKG_ARCH" ]]; then
echo "${QPKG_MD5[$index]}"
return 0
fi
done
return 1
}
QPKG.MinRAM()
{
local -i index=0
for index in "${!QPKG_NAME[@]}"; do
if [[ ${QPKG_NAME[$index]} = "${1:?package name null}" ]] && [[ ${QPKG_MIN_RAM_KB[$index]} = none || $NAS_RAM_KB -ge ${QPKG_MIN_RAM_KB[$index]} ]]; then
echo "${QPKG_MIN_RAM_KB[$index]}"
return 0
fi
done
return 1
}
QPKG.GetStandalones()
{
local -i index=0
for index in "${!QPKG_NAME[@]}"; do
if [[ ${QPKG_NAME[$index]} = "${1:?package name null}" ]] && [[ ${QPKG_ARCH[$index]} = all || ${QPKG_ARCH[$index]} = "$NAS_QPKG_ARCH" ]]; then
if [[ ${QPKG_DEPENDS_ON[$index]} != none ]]; then
echo "${QPKG_DEPENDS_ON[$index]}"
return 0
fi
fi
done
return 1
}
QPKG.GetDependents()
{
local -i index=0
local -a acc=()
if QPKGs.ScStandalone.Exist "$1"; then
for index in "${!QPKG_NAME[@]}"; do
if [[ ${QPKG_DEPENDS_ON[$index]} == *"${1:?package name null}"* ]]; then
[[ ${acc[*]:-} != "${QPKG_NAME[$index]}" ]] && acc+=(${QPKG_NAME[$index]})
fi
done
fi
if [[ ${#acc[@]} -gt 0 ]]; then
echo "${acc[@]}"
return 0
fi
return 1
}
QPKG.IsInstalled()
{
$GREP_CMD -q "^\[${1:?package name null}\]" /etc/config/qpkg.conf
}
QPKG.IsNtInstalled()
{
! QPKG.IsInstalled "${1:?package name null}"
}
QPKG.IsEnabled()
{
[[ $($GETCFG_CMD "${1:?package name null}" Enable -u -f /etc/config/qpkg.conf) = TRUE ]]
}
QPKG.IsStarted()
{
QPKG.IsEnabled "${1:?package name null}"
}
QPKG.GetServiceStatus()
{
local -r PACKAGE_NAME=${1:?package name null}
[[ -e /var/run/$PACKAGE_NAME.last.operation ]] && echo "$(</var/run/"$PACKAGE_NAME".last.operation)"
}
MakePath()
{
if ! mkdir -p "${1:?path null}"; then
ShowAsError "unable to create ${2:?null} path $(FormatAsFileName "$1") $(FormatAsExitcode "$?")"
[[ $(type -t Self.SuggestIssue.Init) = function ]] && Self.SuggestIssue.Set
return 1
fi
return 0
}
RunAndLog()
{
DebugScriptFuncEn
local -r LOG_PATHFILE=$(/bin/mktemp /var/log/"${FUNCNAME[0]}"_XXXXXX)
local -i result_code=0
FormatAsCommand "${1:?null}" > "${2:?null}"
DebugAsProc "exec: '$1'"
if Self.Debug.ToScreen.IsSet; then
eval "$1 > >($TEE_CMD $LOG_PATHFILE) 2>&1"  
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
case $result_code in
0|"${4:-}")
[[ ${3:-} != log:failure-only ]] && AddFileToDebug "$2"
DebugAsDone 'exec complete'
;;
*)
AddFileToDebug "$2"
DebugAsError 'exec complete, but with errors'
esac
DebugScriptFuncEx $result_code
}
DeDupeWords()
{
tr ' ' '\n' <<< "${1:-}" | $SORT_CMD | /bin/uniq | tr '\n' ' ' | $SED_CMD 's|^[[:blank:]]*||;s|[[:blank:]]*$||'
}
FileMatchesMD5()
{
[[ $($MD5SUM_CMD "${1:?pathfile null}" | cut -f1 -d' ') = "${2:?comparison checksum null}" ]]
}
Pluralise()
{
[[ ${1:-0} -ne 1 ]] && echo s
}
Capitalise()
{
echo "$(tr 'a-z' 'A-Z' <<< "${1:0:1}")${1:1}"
}
Uppercase()
{
tr 'a-z' 'A-Z' <<< "$1"
}
Lowercase()
{
tr 'A-Z' 'a-z' <<< "$1"
}
FormatAsThous()
{
local rightside_group=''
local foutput=''
local remainder=$($SED_CMD 's/[^0-9]*//g' <<< "${1:-}")    
while [[ ${#remainder} -gt 0 ]]; do
rightside_group=${remainder:${#remainder}<3?0:-3}      
if [[ -z $foutput ]]; then
foutput=$rightside_group
else
foutput=$rightside_group,$foutput
fi
if [[ ${#rightside_group} -eq 3 ]]; then
remainder=${remainder%???}                         
else
break
fi
done
echo "$foutput"
return 0
}
FormatAsISOBytes()
{
$AWK_CMD 'BEGIN{ u[0]="B"; u[1]="kB"; u[2]="MB"; u[3]="GB"} { n = $1; i = 0; while(n > 1000) { i+=1; n= int((n/1000)+0.5) } print n u[i] } ' <<< "$1"
}
FormatAsTitle()
{
ColourTextBrightWhite sherpa
}
FormatAsAction()
{
ColourTextBrightYellow '[action]'
}
FormatAsPackages()
{
ColourTextBrightOrange '[packages]'
}
FormatAsGroups()
{
ColourTextBrightOrange '[package group]'
}
FormatAsOptions()
{
ColourTextBrightRed '[options]'
}
FormatAsPackName()
{
echo "'${1:?package name null}'"
}
FormatAsFileName()
{
echo "(${1:?filename null})"
}
FormatAsURL()
{
ColourTextUnderlinedCyan "${1:-}"
}
FormatAsExitcode()
{
echo "[${1:?exitcode null}]"
}
FormatAsLogFilename()
{
echo "= log file: '${1:?filename null}'"
}
FormatAsCommand()
{
echo "= command: '${1:?command null}'"
}
FormatAsResult()
{
if [[ ${1:-} -eq 0 ]]; then
echo "= result_code: $(FormatAsExitcode "${1:-}")"
else
echo "! result_code: $(FormatAsExitcode "${1:-}")"
fi
}
FormatAsResultAndStdout()
{
if [[ ${1:-0} -eq 0 ]]; then
echo "= result_code: $(FormatAsExitcode "${1:-}") ***** stdout/stderr begins below *****"
else
echo "! result_code: $(FormatAsExitcode "${1:-}") ***** stdout/stderr begins below *****"
fi
echo "${2:-}"
echo '= ***** stdout/stderr is complete *****'
}
DisplayLineSpaceIfNoneAlready()
{
if Self.LineSpace.IsNt && Self.Display.Clean.IsNt; then
echo
Self.LineSpace.Set
else
Self.LineSpace.UnSet
fi
}
readonly DEBUG_LOG_DATAWIDTH=100
readonly DEBUG_LOG_FIRST_COL_WIDTH=9
readonly DEBUG_LOG_SECOND_COL_WIDTH=17
DebugInfoMajSepr()
{
DebugInfo "$(eval printf '%0.s=' "{1..$DEBUG_LOG_DATAWIDTH}")" 
}
DebugInfoMinSepr()
{
DebugInfo "$(eval printf '%0.s-' "{1..$DEBUG_LOG_DATAWIDTH}")" 
}
DebugExtLogMinSepr()
{
DebugAsLog "$(eval printf '%0.s-' "{1..$DEBUG_LOG_DATAWIDTH}")"
}
DebugScript()
{
DebugDetectTabld SCRIPT "${1:-}" "${2:-}"
}
DebugHardwareOK()
{
DebugDetectTabld HARDWARE "${1:-}" "${2:-}"
}
DebugFirmwareOK()
{
DebugDetectTabld FIRMWARE "${1:-}" "${2:-}"
}
DebugFirmwareWarning()
{
DebugWarningTabld FIRMWARE "${1:-}" "${2:-}"
}
DebugUserspaceOK()
{
DebugDetectTabld USERSPACE "${1:-}" "${2:-}"
}
DebugUserspaceWarning()
{
DebugWarningTabld USERSPACE "${1:-}" "${2:-}"
}
DebugIPKInfo()
{
DebugInfoTabld IPK "${1:-}" "${2:-}"
}
DebugIPKWarning()
{
DebugWarningTabld IPK "${1:-}" "${2:-}"
}
DebugIPKError()
{
DebugErrorTabld IPK "${1:-}" "${2:-}"
}
DebugQPKG()
{
DebugDetectTabld QPKG "${1:-}" "${2:-}"
}
DebugQPKGInfo()
{
DebugInfoTabld QPKG "${1:-}" "${2:-}"
}
DebugQPKGWarning()
{
DebugWarningTabld QPKG "${1:-}" "${2:-}"
}
DebugQPKGError()
{
DebugErrorTabld QPKG "${1:-}" "${2:-}"
}
DebugDetectTabld()
{
if [[ -z ${3:-} ]]; then               
DebugAsDetect "$(printf "%${DEBUG_LOG_FIRST_COL_WIDTH}s: %${DEBUG_LOG_SECOND_COL_WIDTH}s\n" "${1:-}" "${2:-}")"
elif [[ ${3:-} = ' ' ]]; then          
DebugAsDetect "$(printf "%${DEBUG_LOG_FIRST_COL_WIDTH}s: %${DEBUG_LOG_SECOND_COL_WIDTH}s: none\n" "${1:-}" "${2:-}")"
elif [[ ${3: -1} = ' ' ]]; then    
DebugAsDetect "$(printf "%${DEBUG_LOG_FIRST_COL_WIDTH}s: %${DEBUG_LOG_SECOND_COL_WIDTH}s: %-s\n" "${1:-}" "${2:-}" "$($SED_CMD 's| *$||' <<< "${3:-}")")"
else
DebugAsDetect "$(printf "%${DEBUG_LOG_FIRST_COL_WIDTH}s: %${DEBUG_LOG_SECOND_COL_WIDTH}s: %-s\n" "${1:-}" "${2:-}" "${3:-}")"
fi
}
DebugInfoTabld()
{
if [[ -z ${3:-} ]]; then               
DebugAsInfo "$(printf "%${DEBUG_LOG_FIRST_COL_WIDTH}s: %${DEBUG_LOG_SECOND_COL_WIDTH}s\n" "${1:-}" "${2:-}")"
elif [[ ${3:-} = ' ' ]]; then          
DebugAsInfo "$(printf "%${DEBUG_LOG_FIRST_COL_WIDTH}s: %${DEBUG_LOG_SECOND_COL_WIDTH}s: none\n" "${1:-}" "${2:-}")"
elif [[ ${3: -1} = ' ' ]]; then    
DebugAsInfo "$(printf "%${DEBUG_LOG_FIRST_COL_WIDTH}s: %${DEBUG_LOG_SECOND_COL_WIDTH}s: %-s\n" "${1:-}" "${2:-}" "$($SED_CMD 's| *$||' <<< "${3:-}")")"
else
DebugAsInfo "$(printf "%${DEBUG_LOG_FIRST_COL_WIDTH}s: %${DEBUG_LOG_SECOND_COL_WIDTH}s: %-s\n" "${1:-}" "${2:-}" "${3:-}")"
fi
}
DebugWarningTabld()
{
if [[ -z ${3:-} ]]; then               
DebugAsWarn "$(printf "%${DEBUG_LOG_FIRST_COL_WIDTH}s: %${DEBUG_LOG_SECOND_COL_WIDTH}s\n" "${1:-}" "${2:-}")"
elif [[ ${3:-} = ' ' ]]; then          
DebugAsWarn "$(printf "%${DEBUG_LOG_FIRST_COL_WIDTH}s: %${DEBUG_LOG_SECOND_COL_WIDTH}s: none\n" "${1:-}" "${2:-}")"
elif [[ ${3: -1} = ' ' ]]; then    
DebugAsWarn "$(printf "%${DEBUG_LOG_FIRST_COL_WIDTH}s: %${DEBUG_LOG_SECOND_COL_WIDTH}s: %-s\n" "${1:-}" "${2:-}" "$($SED_CMD 's| *$||' <<< "${3:-}")")"
else
DebugAsWarn "$(printf "%${DEBUG_LOG_FIRST_COL_WIDTH}s: %${DEBUG_LOG_SECOND_COL_WIDTH}s: %-s\n" "${1:-}" "${2:-}" "${3:-}")"
fi
}
DebugErrorTabld()
{
if [[ -z ${3:-} ]]; then               
DebugAsError "$(printf "%${DEBUG_LOG_FIRST_COL_WIDTH}s: %${DEBUG_LOG_SECOND_COL_WIDTH}s\n" "${1:-}" "${2:-}")"
elif [[ ${3:-} = ' ' ]]; then          
DebugAsError "$(printf "%${DEBUG_LOG_FIRST_COL_WIDTH}s: %${DEBUG_LOG_SECOND_COL_WIDTH}s: none\n" "${1:-}" "${2:-}")"
elif [[ ${3: -1} = ' ' ]]; then    
DebugAsError "$(printf "%${DEBUG_LOG_FIRST_COL_WIDTH}s: %${DEBUG_LOG_SECOND_COL_WIDTH}s: %-s\n" "${1:-}" "${2:-}" "$($SED_CMD 's| *$||' <<< "${3:-}")")"
else
DebugAsError "$(printf "%${DEBUG_LOG_FIRST_COL_WIDTH}s: %${DEBUG_LOG_SECOND_COL_WIDTH}s: %-s\n" "${1:-}" "${2:-}" "${3:-}")"
fi
}
DebugVar()
{
local temp=${!1}
DebugAsVar "\$$1 : '$temp'"
}
DebugInfo()
{
if [[ ${2:-} = ' ' || ${2:-} = "'' " ]]; then  
DebugAsInfo "${1:-}: none"
elif [[ -n ${2:-} ]]; then
DebugAsInfo "${1:-}: ${2:-}"
else
DebugAsInfo "${1:-}"
fi
}
DebugScriptFuncEn()
{
local var_name=${FUNCNAME[1]}_STARTSECONDS
local var_safe_name=${var_name//[.-]/_}
eval "$var_safe_name=$(/bin/date +%s%N)"
DebugAsFuncEn
}
DebugScriptFuncEx()
{
local var_name=${FUNCNAME[1]}_STARTSECONDS
local var_safe_name=${var_name//[.-]/_}
DebugAsFuncEx "${1:-0}" "$(FormatAsDuration "$(CalcMilliDifference "${!var_safe_name}" "$($DATE_CMD +%s%N)")")"
return ${1:-0}
}
DebugForkFuncEn()
{
original_session_log_pathfile="$sess_active_pathfile"
sess_active_pathfile=$(/bin/mktemp /var/log/"${FUNCNAME[1]}"_XXXXXX)
local var_name=${FUNCNAME[1]}_STARTSECONDS
local var_safe_name=${var_name//[.-]/_}
eval "$var_safe_name=$(/bin/date +%s%N)"
DebugAsFuncEn
}
DebugForkFuncEx()
{
local var_name=${FUNCNAME[1]}_STARTSECONDS
local var_safe_name=${var_name//[.-]/_}
SendActionStatus Ex
DebugAsFuncEx "${1:-0}" "$(FormatAsDuration "$(CalcMilliDifference "${!var_safe_name}" "$($DATE_CMD +%s%N)")")"
$CAT_CMD "$sess_active_pathfile" >> "$original_session_log_pathfile" && rm "$sess_active_pathfile"
exit ${1:-0}
}
CalcMilliDifference()
{
echo "$((($2-$1)/1000000))"
}
FormatAsDuration()
{
if [[ ${1:-0} -lt 30000 ]]; then
echo "$(FormatAsThous "${1:-0}")ms"
else
FormatSecsToHoursMinutesSecs "$(($1/1000))"
fi
}
DebugAsFuncEn()
{
DebugThis "(>>) ${FUNCNAME[2]}"
}
DebugAsFuncEx()
{
DebugThis "(<<) ${FUNCNAME[2]}|${1:-0}|${2:-}"
}
DebugAsProc()
{
DebugThis "(--) ${1:-}"
}
DebugAsDone()
{
DebugThis "(==) ${1:-}"
}
DebugAsDetect()
{
DebugThis "(**) ${1:-}"
}
DebugAsInfo()
{
DebugThis "(II) ${1:-}"
}
DebugAsWarn()
{
DebugThis "(WW) ${1:-}"
}
DebugAsError()
{
DebugThis "(EE) ${1:-}"
}
DebugAsLog()
{
DebugThis "(LL) ${1:-}"
}
DebugAsVar()
{
DebugThis "(vv) ${1:-}"
}
DebugThis()
{
[[ $(type -t Self.Debug.ToScreen.Init) = function ]] && Self.Debug.ToScreen.IsSet && ShowAsDebug "${1:-}"
WriteToLog dbug "${1:-}"
}
AddFileToDebug()
{
local linebuff=''
local screen_debug=false
DebugAsLog 'adding external log to main log'
DebugExtLogMinSepr
if Self.Debug.ToScreen.IsSet; then     
screen_debug=true
Self.Debug.ToScreen.UnSet
fi
DebugAsLog "$(FormatAsLogFilename "${1:?filename null}")"
while read -r linebuff; do
DebugAsLog "$linebuff"
done < "${1:?filename null}"
[[ $screen_debug = true ]] && Self.Debug.ToScreen.Set
DebugExtLogMinSepr
}
ShowAsProcLong()
{
ShowAsProc "${1:-} (might take a while)" "${2:-}"
}
ShowAsProc()
{
local suffix=''
[[ -n ${2:-} ]] && suffix=": $2"
EraseThisLine
WriteToDisplayWait "$(ColourTextBrightYellow proc)" "${1:-}${suffix}"
WriteToLog proc "${1:-}${suffix}"
[[ $(type -t Self.Debug.ToScreen.Init) = function ]] && Self.Debug.ToScreen.IsSet && Display
} >&2
ShowAsDebug()
{
WriteToDisplayNew "$(ColourTextBlackOnCyan dbug)" "${1:-}"
}
ShowAsInfo()
{
EraseThisLine
WriteToDisplayNew "$(ColourTextBrightYellow note)" "${1:-}"
WriteToLog note "${1:-}"
} >&2
ShowAsQuiz()
{
WriteToDisplayWait "$(ColourTextBrightOrangeBlink quiz)" "${1:-}:"
WriteToLog quiz "${1:-}:"
}
ShowAsQuizDone()
{
WriteToDisplayNew "$(ColourTextBrightOrange quiz)" "${1:-}"
}
ShowAsDone()
{
EraseThisLine
WriteToDisplayNew "$(ColourTextBrightGreen 'done')" "${1:-}"
WriteToLog 'done' "$1"
}
ShowAsWarn()
{
EraseThisLine
WriteToDisplayNew "$(ColourTextBrightOrange warn)" "${1:-}"
WriteToLog warn "$1"
} >&2
ShowAsAbort()
{
WriteToDisplayNew "$(ColourTextBrightRed bort)" "${1:-}"
WriteToLog bort "$1"
Self.Error.Set
} >&2
ShowAsFail()
{
EraseThisLine
local capitalised="$(Capitalise "${1:-}")"
WriteToDisplayNew "$(ColourTextBrightRed fail)" "$capitalised"
WriteToLog fail "$capitalised"
} >&2
ShowAsError()
{
EraseThisLine
local capitalised="$(Capitalise "${1:-}")"
WriteToDisplayNew "$(ColourTextBrightRed derp)" "$capitalised"
WriteToLog derp "$capitalised"
Self.Error.Set
} >&2
ShowAsActionProgress()
{
if [[ -n $1 && $1 != All ]]; then
local tier=" $(Lowercase "$1")"
else
local tier=''
fi
local -r PACKAGE_TYPE=${2:?null}
declare -i -r OK_COUNT=${3:-0}
declare -i -r SKIP_COUNT=${4:-0}
declare -i -r FAIL_COUNT=${5:-0}
declare -i -r TOTAL_COUNT=${6:-0}
local -r ACTION_PRESENT=${7:?null}
local -r DURATION=${8:-}
local progress_msg=''
progress_msg="$(PercFrac "$OK_COUNT" "$SKIP_COUNT" "$FAIL_COUNT" "$TOTAL_COUNT")"
if [[ $DURATION != long ]]; then
ShowAsProc "$ACTION_PRESENT ${TOTAL_COUNT}${tier} ${PACKAGE_TYPE}$(Pluralise "$TOTAL_COUNT")" "$progress_msg"
else
ShowAsProcLong "$ACTION_PRESENT ${TOTAL_COUNT}${tier} ${PACKAGE_TYPE}$(Pluralise "$TOTAL_COUNT")" "$progress_msg"
fi
[[ $((OK_COUNT+SKIP_COUNT+FAIL_COUNT)) -ge $TOTAL_COUNT ]] && $SLEEP_CMD 1
return 0
}
PercFrac()
{
declare -i -r OK_COUNT=${1:-0}
declare -i -r SKIP_COUNT=${2:-0}
declare -i -r FAIL_COUNT=${3:-0}
declare -i -r TOTAL_COUNT=${4:-0}
local -i progress_count="$((OK_COUNT+SKIP_COUNT+FAIL_COUNT))"
local perc_msg=''
[[ $TOTAL_COUNT -gt 0 ]] || return         
if [[ $progress_count -gt $TOTAL_COUNT ]]; then
progress_count=$TOTAL_COUNT
perc_msg='100%'
else
perc_msg="$((200*(progress_count+1)/(TOTAL_COUNT+1)%2+100*(progress_count+1)/(TOTAL_COUNT+1)))%"
fi
echo "$perc_msg ($(ColourTextBrightWhite "$progress_count")/$(ColourTextBrightWhite "$TOTAL_COUNT"))"
return 0
} 2>/dev/null
ShowAsActionResult()
{
if [[ -n $1 && $1 != All ]]; then
local -r TIER=" $(Lowercase "$1")"
else
local -r TIER=''
fi
local -r PACKAGE_TYPE=${2:?null}
declare -i -r OK_COUNT=${3:-0}
declare -i -r TOTAL_COUNT=${4:-0}
local msg="${5:?null} "
if [[ $OK_COUNT -gt 0 ]]; then
msg+="${OK_COUNT}${TIER} ${PACKAGE_TYPE}$(Pluralise "$OK_COUNT")"
else
msg+="no${TIER} ${PACKAGE_TYPE}s"
fi
case $TOTAL_COUNT in
0)
DebugAsDone "no${TIER} ${PACKAGE_TYPE}s processed"
;;
*)
ShowAsDone "$msg"
esac
return 0
} >&2
ShowAsActionResultDetail()
{
local sk_msg=''
local er_msg=''
[[ $(QPKGs.AcSk${1}.Count) -gt 0 || $(QPKGs.AcSe${1}.Count) -gt 0 ]] && sk_msg="$(ColourTextBrightOrange 'skipped:') $(QPKGs.AcSk${1}.ListCSV) $(QPKGs.AcSe${1}.ListCSV)"
[[ $(QPKGs.AcEr${1}.Count) -gt 0 ]] && er_msg="$(ColourTextBrightRed 'failed:') $(QPKGs.AcEr${1}.ListCSV)"
if [[ -z $sk_msg && -z $er_msg ]]; then
return
elif [[ -n $sk_msg && -z $er_msg ]]; then
DisplayAsActionResultLastLine "$sk_msg"
elif [[ -z $sk_msg && -n $er_msg ]]; then
DisplayAsActionResultLastLine "$er_msg"
else
DisplayAsActionResultNtLastLine "$sk_msg"
DisplayAsActionResultLastLine "$er_msg"
fi
} >&2
ShowAsActionLogDetail()
{
case ${4:-} in
skipped|skipped-failed)
echo -ne "\t$(Lowercase "${3:-}") ${2:-}"
[[ -n ${6:-} ]] && echo -ne ";\n\t\tReason: ${6:-}"
;;
failed)
echo -ne "\tUnable to $(Lowercase "${3:-}") ${2:-}"
echo -ne " in $(FormatMilliSecsToMinutesSecs "$duration")"
if [[ -n ${6:-} ]]; then
if QPKG.IsCanLog "$2"; then
echo -ne ";\n\t\tFor more information, please check the service log: /etc/init.d/$($BASENAME_CMD "$(QPKG.ServicePathFile "$2")") log"
else
echo -ne "; ${6:-}"
fi
fi
;;
*)
echo -ne "\t$(Lowercase "${3:-}") ${2:-}"
echo -ne " in $(FormatMilliSecsToMinutesSecs "$duration")"
esac
echo   
}
WriteToDisplayWait()
{
local -i width=4
[[ $colourful = true ]] && width=10    
prev_msg=$(printf "%-${width}s: %s" "${1:-}" "${2:-}")
DisplayWait "$prev_msg"
return 0
}
WriteToDisplayNew()
{
local -i width=4
local -i length=0
local -i blanking_length=0
local msg=''
local strbuffer=''
[[ $colourful = true ]] && width=10    
msg=$(printf "%-${width}s: %s" "${1:-}" "${2:-}")
if [[ $msg != "${prev_msg:=''}" ]]; then
prev_length=$((${#prev_msg}+1))
length=$((${#msg}+1))
strbuffer=$(echo -en "\r$msg ")
if [[ $length -lt $prev_length ]]; then
blanking_length=$((length-prev_length))
strbuffer+=$(printf "%${blanking_length}s")
fi
Display "$strbuffer"
fi
return 0
}
WriteToLog()
{
[[ $(type -t Self.Debug.ToFile.Init) = function ]] && Self.Debug.ToFile.IsNt && return
[[ -n ${sess_active_pathfile:-} ]] && printf '%-4s: %s\n' "$(StripANSI "${1:-}")" "$(StripANSI "${2:-}")" >> "$sess_active_pathfile"
}
ColourTextBrightGreen()
{
if [[ $colourful = true ]]; then
echo -en '\033[1;32m'"$(ColourReset "${1:-}")"
else
echo -n "${1:-}"
fi
} 2>/dev/null
ColourTextBrightYellow()
{
if [[ $colourful = true ]]; then
echo -en '\033[1;33m'"$(ColourReset "${1:-}")"
else
echo -n "${1:-}"
fi
} 2>/dev/null
ColourTextBrightOrange()
{
if [[ $colourful = true ]]; then
echo -en '\033[1;38;5;214m'"$(ColourReset "${1:-}")"
else
echo -n "${1:-}"
fi
} 2>/dev/null
ColourTextBrightOrangeBlink()
{
if [[ $colourful = true ]]; then
echo -en '\033[1;5;38;5;214m'"$(ColourReset "${1:-}")"
else
echo -n "${1:-}"
fi
} 2>/dev/null
ColourTextBrightRed()
{
if [[ $colourful = true ]]; then
echo -en '\033[1;31m'"$(ColourReset "${1:-}")"
else
echo -n "${1:-}"
fi
} 2>/dev/null
ColourTextBrightRedBlink()
{
if [[ $colourful = true ]]; then
echo -en '\033[1;5;31m'"$(ColourReset "${1:-}")"
else
echo -n "${1:-}"
fi
} 2>/dev/null
ColourTextUnderlinedCyan()
{
if [[ $colourful = true ]]; then
echo -en '\033[4;36m'"$(ColourReset "${1:-}")"
else
echo -n "${1:-}"
fi
} 2>/dev/null
ColourTextBlackOnCyan()
{
if [[ $colourful = true ]]; then
echo -en '\033[30;46m'"$(ColourReset "${1:-}")"
else
echo -n "${1:-}"
fi
} 2>/dev/null
ColourTextBrightWhite()
{
if [[ $colourful = true ]]; then
echo -en '\033[1;97m'"$(ColourReset "${1:-}")"
else
echo -n "${1:-}"
fi
} 2>/dev/null
ColourReset()
{
echo -en "${1:-}"'\033[0m'
} 2>/dev/null
StripANSI()
{
if [[ -e $GNU_SED_CMD && -e $GNU_SED_CMD ]]; then  
$GNU_SED_CMD -r 's/\x1b\[[0-9;]*m//g' <<< "${1:-}"
else
echo "${1:-}"          
fi
} 2>/dev/null
UpdateColourisation()
{
if [[ -e /opt/bin/sed ]]; then
colourful=true
SendParentChangeEnv 'colourful=true'
else
colourful=false
SendParentChangeEnv 'colourful=false'
fi
}
HideCursor()
{
[[ -e $GNU_SETTERM_CMD ]] && $GNU_SETTERM_CMD --cursor off
}
ShowCursor()
{
[[ -e $GNU_SETTERM_CMD ]] && $GNU_SETTERM_CMD --cursor on
}
HideKeystrokes()
{
[[ -e $GNU_STTY_CMD && -t 0 ]] && $GNU_STTY_CMD -echo
}
ShowKeystrokes()
{
[[ -e $GNU_STTY_CMD && -t 0 ]] && $GNU_STTY_CMD 'echo'
}
FormatMilliSecsToMinutesSecs()
{
local seconds=$((${1:-0}/1000))
((m=(seconds%3600)/60))
((s=seconds%60))
[[ $s -eq 0 ]] && s=1
if [[ $m -eq 0 ]]; then
if [[ $s -eq 1 ]]; then
printf '%d second' "$s"
else
printf '%d seconds' "$s"
fi
else
printf '%dm:%02ds' "$m" "$s"
fi
} 2>/dev/null
FormatSecsToHoursMinutesSecs()
{
((h=${1:-0}/3600))
((m=(${1:-0}%3600)/60))
((s=${1:-0}%60))
printf '%01dh:%02dm:%02ds\n' "$h" "$m" "$s"
} 2>/dev/null
FormatLongMinutesSecs()
{
local m=${1%%:*}
local s=${1#*:}
m=${m##* }
s=${s##* }
printf '%01dm:%02ds\n' "$((10#$m))" "$((10#$s))"
} 2>/dev/null
Objects.Load()
{
DebugScriptFuncEn
if [[ ! -e $PWD/dont.refresh.objects ]]; then
if [[ ! -e $OBJECTS_PATHFILE ]] || ! IsThisFileRecent "$OBJECTS_PATHFILE"; then
ShowAsProc 'updating objects'
if $CURL_CMD${curl_insecure_arg:-} --silent --fail "$OBJECTS_ARCHIVE_URL" > "$OBJECTS_ARCHIVE_PATHFILE"; then
/bin/tar --extract --gzip --file="$OBJECTS_ARCHIVE_PATHFILE" --directory="$WORK_PATH"
fi
fi
fi
if [[ ! -e $OBJECTS_PATHFILE ]]; then
ShowAsAbort 'objects missing'
DebugScriptFuncEx 1; exit
fi
ShowAsProc 'loading objects'
. "$OBJECTS_PATHFILE"
readonly OBJECTS_VER
DebugScriptFuncEx
}
Packages.Load()
{
QPKGs.Loaded.IsSet && return
DebugScriptFuncEn
if [[ ! -e $PWD/dont.refresh.packages ]]; then
if [[ ! -e $PACKAGES_PATHFILE ]] || ! IsThisFileRecent "$PACKAGES_PATHFILE" 60; then
ShowAsProc 'updating package list'
if $CURL_CMD${curl_insecure_arg:-} --silent --fail "$PACKAGES_ARCHIVE_URL" > "$PACKAGES_ARCHIVE_PATHFILE"; then
/bin/tar --extract --gzip --file="$PACKAGES_ARCHIVE_PATHFILE" --directory="$WORK_PATH"
fi
fi
fi
if [[ ! -e $PACKAGES_PATHFILE ]]; then
ShowAsAbort 'package list missing'
DebugScriptFuncEx 1; exit
fi
ShowAsProc 'loading package list'
. "$PACKAGES_PATHFILE"
readonly PACKAGES_VER
readonly BASE_QPKG_CONFLICTS_WITH
readonly BASE_QPKG_WARNINGS
readonly ESSENTIAL_IPKS
readonly ESSENTIAL_PIPS
readonly MIN_PYTHON_VER
readonly MIN_PERL_VER
readonly QPKG_NAME
readonly QPKG_AUTHOR
readonly QPKG_APP_AUTHOR
readonly QPKG_ARCH
readonly QPKG_MIN_RAM_KB
readonly QPKG_VERSION
readonly QPKG_URL
readonly QPKG_MD5
readonly QPKG_DESC
readonly QPKG_NOTE
readonly QPKG_ABBRVS
readonly QPKG_CONFLICTS_WITH
readonly QPKG_DEPENDS_ON
readonly QPKG_REQUIRES_IPKS
readonly QPKG_CAN_BACKUP
readonly QPKG_CAN_RESTART_TO_UPDATE
readonly QPKG_CAN_CLEAN
readonly QPKG_CAN_LOG
QPKGs.Loaded.Set
DebugScript version "packages: ${PACKAGES_VER:-unknown}"
QPKGs.ScAll.Add "${QPKG_NAME[*]}"
QPKGs.StandaloneDependent.Build
DebugScriptFuncEx
}
RunOnSIGINT()
{
EraseThisLine
ShowAsAbort 'caught SIGINT'
KillActiveFork
CloseActionMsgPipe
exit
}
RunOnEXIT()
{
trap - INT
ShowKeystrokes
ShowCursor
ReleaseLockFile
}
Self.Init || exit
Self.LogEnv
Self.IsAnythingToDo
Self.Validate
Actions.Proc
Self.Results
Self.Error.IsNt
