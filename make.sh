#!/usr/bin/env bash

# standalone compiler for all sherpa archives

./check.sh || exit

echo -n 'building archives ... '

WORK_PATH=$PWD

MANAGEMENT_ACTIONS=(Check List Paste Status)

PACKAGE_SCOPES=(All Dependent HasDependents Installable Standalone SupportBackup SupportDebug SupportUpdateOnRestart Upgradable)
PACKAGE_STATES=(BackedUp Cleaned Downloaded Enabled Installed Missing Started)
PACKAGE_STATES_TEMPORARY=(Starting Stopping Restarting)
PACKAGE_ACTIONS=(Backup Clean Disable Download Enable Install Reassign Rebuild Reinstall Restart Restore Start Stop Uninstall Upgrade)
PACKAGE_RESULTS=(Ok Unknown)

MANAGER_FILE=sherpa.manager.sh
MANAGER_ARCHIVE_FILE=${MANAGER_FILE%.*}.tar.gz
MANAGER_ARCHIVE_PATHFILE=$WORK_PATH/$MANAGER_ARCHIVE_FILE

OBJECTS_FILE=objects
OBJECTS_ARCHIVE_FILE=$OBJECTS_FILE.tar.gz
OBJECTS_ARCHIVE_PATHFILE=$WORK_PATH/$OBJECTS_ARCHIVE_FILE
OBJECTS_PATHFILE=$WORK_PATH/$OBJECTS_FILE

PACKAGES_FILE=packages
PACKAGES_ARCHIVE_FILE=$PACKAGES_FILE.tar.gz
PACKAGES_ARCHIVE_PATHFILE=$WORK_PATH/$PACKAGES_ARCHIVE_FILE

AddFlagObj()
    {

    # $1 = object name to create
    # $2 = set flag state on init (optional) default is 'false'
    # $3 = set 'log boolean changes' on init (optional) default is 'true'

    local public_function_name=${1:?no object name supplied}
    local safe_function_name="$(tr 'A-Z' 'a-z' <<< "${public_function_name//[.-]/_}")"
    local state_default=${2:-false}
    local state_logmods=${3:-true}

    _placeholder_flag_=_ob_${safe_function_name}_fl_
    _placeholder_log_changes_flag_=_ob_${safe_function_name}_chfl_

echo $public_function_name'.Init()
{ '$_placeholder_flag_'='$state_default'
'$_placeholder_log_changes_flag_'='$state_logmods' ;}
'$public_function_name'.IsNt()
{ [[ $'$_placeholder_flag_' != '\'true\'' ]] ;}
'$public_function_name'.IsSet()
{ [[ $'$_placeholder_flag_' = '\'true\'' ]] ;}
'$public_function_name'.Set()
{ [[ $'$_placeholder_flag_' = '\'true\'' ]] && return
'$_placeholder_flag_'=true
[[ $'$_placeholder_log_changes_flag_' = '\'true\'' ]] && DebugVar '$_placeholder_flag_' ;}
'$public_function_name'.UnSet()
{ [[ $'$_placeholder_flag_' != '\'true\'' ]] && return
'$_placeholder_flag_'=false
[[ $'$_placeholder_log_changes_flag_' = '\'true\'' ]] && DebugVar '$_placeholder_flag_' ;}
'$public_function_name'.NoLogMods()
{ '$_placeholder_log_changes_flag_'=false ;}
'$public_function_name'.Init' >> "$OBJECTS_PATHFILE"

    return 0

    }

AddListObj()
    {

    # $1 = object name to create

    local public_function_name=${1:?no object name supplied}
    local safe_function_name="$(tr 'A-Z' 'a-z' <<< "${public_function_name//[.-]/_}")"

    _placeholder_size_=_ob_${safe_function_name}_sz_
    _placeholder_array_=_ob_${safe_function_name}_ar_
    _placeholder_array_index_=_ob_${safe_function_name}_arin_

echo $public_function_name'.Add()
{ local ar=(${1}) it='\'\''
[[ ${#ar[@]} -eq 0 ]] && return
for it in "${ar[@]:-}"; do
[[ " ${'$_placeholder_array_'[*]+"${'$_placeholder_array_'[@]}"} " != *"$it"* ]] && '$_placeholder_array_'+=("$it")
done ;}
'$public_function_name'.Array()
{ echo -n "${'$_placeholder_array_'[@]+"${'$_placeholder_array_'[@]}"}" ;}
'$public_function_name'.Count()
{ echo "${#'$_placeholder_array_'[@]}" ;}
'$public_function_name'.Exist()
{ [[ ${'$_placeholder_array_'[*]:-} == *"$1"* ]] ;}
'$public_function_name'.Init()
{ '$_placeholder_size_'=0
'$_placeholder_array_'=()
'$_placeholder_array_index_'=1 ;}
'$public_function_name'.IsAny()
{ [[ ${#'$_placeholder_array_'[@]} -gt 0 ]] ;}
'$public_function_name'.IsNone()
{ [[ ${#'$_placeholder_array_'[@]} -eq 0 ]] ;}
'$public_function_name'.List()
{ echo -n "${'$_placeholder_array_'[*]+"${'$_placeholder_array_'[@]}"}" ;}
'$public_function_name'.ListCSV()
{ echo -n "${'$_placeholder_array_'[*]+"${'$_placeholder_array_'[@]}"}" | tr '\' \'' '\',\'' ;}
'$public_function_name'.Remove()
{ local agar=(${1}) tmar=() ag='\'\'' it='\'\'' m=false
for it in "${'$_placeholder_array_'[@]+"${'$_placeholder_array_'[@]}"}"; do
m=false
for ag in "${agar[@]+"${agar[@]}"}"; do
if [[ $ag = "$it" ]]; then
m=true; break
fi
done
[[ $m = false ]] && tmar+=("$it")
done
'$_placeholder_array_'=("${tmar[@]+"${tmar[@]}"}")
[[ -z ${'$_placeholder_array_'[*]+"${'$_placeholder_array_'[@]}"} ]] && '$_placeholder_array_'=() ;}
'$public_function_name'.Size()
{ if [[ -n ${1:-} && ${1:-} = "=" ]]; then
'$_placeholder_size_'=$2
else
echo -n "$'$_placeholder_size_'"
fi ;}
'$public_function_name'.Init' >> "$OBJECTS_PATHFILE"

    return 0

    }

[[ -e $MANAGER_ARCHIVE_PATHFILE ]] && rm $MANAGER_ARCHIVE_PATHFILE
[[ -e $OBJECTS_ARCHIVE_PATHFILE ]] && rm $OBJECTS_ARCHIVE_PATHFILE
echo "OBJECTS_VER=$(date +%y%m%d)" > "$OBJECTS_PATHFILE"
echo "# do not edit this file - it should only be built with the 'make.sh' script" >> "$OBJECTS_PATHFILE"
[[ -e $PACKAGES_ARCHIVE_PATHFILE ]] && rm $PACKAGES_ARCHIVE_PATHFILE

# session flags
for element in Display.Clean ShowBackupLoc SuggestIssue Summary; do
    AddFlagObj Self.$element
done

AddFlagObj Self.LineSpace false false   # disable change logging for this object (low importance)
AddFlagObj Self.Boring false false      # disable change logging for this object (low importance)

AddFlagObj Self.Debug.ToArchive
AddFlagObj Self.Debug.ToScreen
AddFlagObj Self.Debug.ToFile true       # set initial value to 'true' so debug info is recorded early-on

for element in Loaded States.Built SkProc; do
    AddFlagObj QPKGs.$element
done

AddFlagObj IPKGs.Upgrade
AddFlagObj IPKGs.Install
AddFlagObj PIPs.Install

# user option flags
for element in Deps.Check Versions.View; do
    AddFlagObj Opts.$element
done

for element in Abbreviations Actions ActionsAll Backups Basic Options Packages Problems Repos Status Tips; do
    AddFlagObj Opts.Help.$element
done

for element in Last Tail; do
    AddFlagObj Opts.Log.$element.Paste
    AddFlagObj Opts.Log.$element.View
done

for scope in "${PACKAGE_SCOPES[@]}"; do
    AddFlagObj QPKGs.List.Sc${scope}
    AddFlagObj QPKGs.List.ScNt${scope}
done

for state in "${PACKAGE_STATES[@]}"; do
    AddFlagObj QPKGs.List.Is${state}
    AddFlagObj QPKGs.List.IsNt${state}
done

for state in "${PACKAGE_STATES_TEMPORARY[@]}"; do
    AddFlagObj QPKGs.List.Is${state}
done

for scope in "${PACKAGE_SCOPES[@]}"; do
    for action in "${PACKAGE_ACTIONS[@]}"; do
        AddFlagObj QPKGs.Ac${action}.Sc${scope}
        AddFlagObj QPKGs.Ac${action}.ScNt${scope}
    done
done

for state in "${PACKAGE_STATES[@]}"; do
    for action in "${PACKAGE_ACTIONS[@]}"; do
        AddFlagObj QPKGs.Ac${action}.Is${state}
        AddFlagObj QPKGs.Ac${action}.IsNt${state}
    done
done

for state in "${PACKAGE_STATES_TEMPORARY[@]}"; do
    for action in "${PACKAGE_ACTIONS[@]}"; do
        AddFlagObj QPKGs.Ac${action}.Is${state}
    done
done

# lists
AddListObj Args.Unknown

for action in "${MANAGEMENT_ACTIONS[@]}"; do
    AddListObj Self.AcTo${action}       # action to be tried
    AddListObj Self.AcOk${action}       # action was tried and succeeded
    AddListObj Self.AcEr${action}       # action was tried but failed
    AddListObj Self.AcSk${action}       # action was skipped
done

for action in "${PACKAGE_ACTIONS[@]}"; do
    AddListObj QPKGs.AcTo${action}      # action to be tried
    AddListObj QPKGs.AcOk${action}      # action was tried and succeeded
    AddListObj QPKGs.AcEr${action}      # action was tried but failed
    AddListObj QPKGs.AcSk${action}      # action was skipped
done

for action in Download Install Uninstall Upgrade; do    # only a subset of addon package actions are supported for-now
    AddListObj IPKGs.AcTo${action}
    AddListObj IPKGs.AcOk${action}
done

for scope in "${PACKAGE_SCOPES[@]}"; do
    AddListObj QPKGs.Sc${scope}
    AddListObj QPKGs.ScNt${scope}
done

for state in "${PACKAGE_STATES_TEMPORARY[@]}"; do
    AddListObj QPKGs.Is${state}
done

for state in "${PACKAGE_STATES[@]}" "${PACKAGE_RESULTS[@]}"; do
    AddListObj QPKGs.Is${state}
    AddListObj QPKGs.IsNt${state}
done

tar --create --gzip --numeric-owner --file="$MANAGER_ARCHIVE_PATHFILE" --directory="$WORK_PATH" "$MANAGER_FILE"
tar --create --gzip --numeric-owner --file="$OBJECTS_ARCHIVE_PATHFILE" --directory="$WORK_PATH" "$OBJECTS_FILE"
tar --create --gzip --numeric-owner --file="$PACKAGES_ARCHIVE_PATHFILE" --directory="$WORK_PATH" "$PACKAGES_FILE"

echo 'done!'

echo "these files have changed since the last commit:"
git diff --name-only
