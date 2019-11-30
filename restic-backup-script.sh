#!/bin/bash

#### Script Constant ####
SCRIPT_DIR_PATH=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )

#### Functions ####
# Function to check if some ip is accessible
function check_connection() {
  if [[ ! -z $1 ]]; then
    ping -t 10 -c 1 $1 &> /dev/null
    ping_result=$?
    if [[ $ping_result == "0" ]]; then
      echo 1
    else
      echo 0
    fi
  else
    echo 0
  fi
}

# Function to check if a file or a directory exist
function check_file_or_dir_exist() {
  if [[ ! -z $1 ]]; then

    if [[ -d $1 ]] || [[ -f $1 ]]; then
      echo 1
    else
      echo 0
    fi

  else
    echo 0
  fi
}

function check_program_in_path () {
    # Check if the command exists.
    command -v $1 > /dev/null
    # Fail if the command does not exist and the argument is not a path to an executable.
    if [ $? -ne 0 ] && [ ! -f $1 ] ; then
        echo "$1 is required but not found in \$PATH"
        echo "More informations on https://github.com/subnet-dev/restic-backup-script"
        exit 1
    fi
}


function set_max_cpu_usage() {
  export GOMAXPROCS=$(($(getconf _NPROCESSORS_ONLN)*$MAX_CPU_USAGE/100))
}

function update_script() {
  # Check if github.com is accessible and if auto update is enable
    if [[ ! $(cd $SCRIPT_DIR_PATH && git pull) ]]; then
      echo "$(date) --- Update the script ----"
      echo "$(date) Error on pull..."
      echo "If you have some trouble with this script you can reinitialize with these commands in terminal :"
      echo " /!\\ This manipulation replace the restic_var file /!\\ "
      echo "      cd $SCRIPT_DIR_PATH"
      echo "      git fetch --all"
      echo "      git reset --hard origin/master"
      echo ""
      echo "Then retry to run the script : $SCRIPT_DIR_PATH/restic-backup-script.sh"
      echo "$(date) --- Failed to update the script ----"
      exit
    else
      echo "$(date) --- Update the script ----"
      echo "$(date) Script is up to date"
      echo "$(date) --- End of update ----"
    fi
}

function update_script_if_auto_update_enable {
  # Update script
  if [[ ! $SCRIPT_AUTO_UPDATE == "true" ]]; then
    echo "Auto update disable"
  elif [[ ! $(check_connection github.com) == "1" ]]; then
    echo "Error : Github.com not accessible"
  else
    update_script
  fi
}

#### Code start ####

# Include restic authentification file if exist
if [[ $(check_file_or_dir_exist $SCRIPT_DIR_PATH/restic_var) == 1 ]]; then
  . $SCRIPT_DIR_PATH/restic_var
else
  curl https://raw.githubusercontent.com/subnet-dev/restic-backup-script/master/restic_var > $SCRIPT_DIR_PATH/restic_var 2> /dev/null
  echo "You must configure this file : $SCRIPT_DIR_PATH/restic_var"
  exit
fi

# Check if the repo path is resolvable.
RESTIC_REPOSITORY_TYPE=$(echo $RESTIC_REPOSITORY | cut -d : -f 1)
RESTIC_REPOSITORY_PROTOCOL=$(echo $RESTIC_REPOSITORY | cut -d : -f 2)
RESTIC_REPOSITORY_HOST=$(echo $RESTIC_REPOSITORY | cut -d : -f 3 | sed -e 's/\/.*\///g')

if [[ ! $(check_connection $RESTIC_REPOSITORY_HOST) == "1" ]]; then
  echo "Your restic repository on $RESTIC_REPOSITORY_HOST isn't accessible"
  echo "Please verify your restic_var configuration ($SCRIPT_DIR_PATH/restic_var)"
  echo "Exit"
  exit
fi

check_program_in_path restic


# Detect witch system it is
uname_output="$(uname -s)"
case "${uname_output}" in
    Linux*)     system=Linux;;
    Darwin*)    system=MacOS;;
    CYGWIN*)    system=Cygwin;;
    MINGW*)     system=MinGw;;
    *)          system="UNKNOWN:${uname_output}"
esac

if [[ $system != "Linux" ]] && [[ $system != "MacOS" ]]; then
  echo "Sorry, $system isn't supported :/ )"
  echo "Exit..."
  exit
fi

# Securing restic_var file
chmod 600 $SCRIPT_DIR_PATH/restic_var

### Get computer informations ###
case $system in
  MacOS )
    # Computer Informations
    Computer_Owner=$(dscl . list /Users | grep -v '_' | grep -vi "root\|nobody\|daemon\|guest" | sed 's/^/--tag /' | tr '\n' ' ')
    Computer_Name=$(scutil --get ComputerName | tr ' ' '_')
    Computer_Modele=" --tag $(system_profiler SPHardwareDataType | awk '/Model Identifier/ {print $3}' | sed 's/,/./')"
    Computer_OSVersion="--tag $(defaults read loginwindow SystemVersionStampAsString)"
    Computer_Serial="--tag $(system_profiler SPHardwareDataType | awk '/Serial/ {print $4}' | cut -d " " -f1 | head -1)"
    Mount_Path=~/Desktop/Restic
    ;;
  Linux )
    Computer_Owner=$(cat /etc/passwd | grep -vi "nologin" | grep -vi "sbin" | grep -vi "root\|nobody\|daemon\|guest" | cut -d : -f 1 | sed 's/^/--tag /' | tr '\n' ' ')
    Computer_Name=$(hostname | tr ' ' '_')
    Computer_Modele="--tag $(dmidecode | grep -A3 '^System Information' | grep "Product Name" | cut -d : -f 2 | sed 's/ //' | tr -s ' ' | tr ' ' '_' | tr -s ',' | tr ',' '.')"
    Computer_OSVersion="--tag $(cat /etc/os-release | grep PRETTY_NAME | cut -d = -f 2 | cut -d \" -f 2 | tr -s ' ' | tr ' ' '_')"
    Computer_Serial="--tag $(dmidecode -s system-serial-number)"
    Mount_Path=~/Restic
  ;;
esac

case $1 in
  backup )
    update_script_if_auto_update_enable
    echo "$(date) --- Start backup ----"
    # Set the max cpu usage
    set_max_cpu_usage
    restic_alleready_running=$(ps aux | grep backup | grep "restic backup"  | wc -l | tr -d '\040\011\012\015')
    if [[ $restic_alleready_running == "1" ]]; then
      restic backup $RESTIC_BACKUP_PATH --host $Computer_Name $Computer_Owner $Computer_Modele $Computer_OSVersion $Computer_Serial $RESTIC_EXCLUDE_PATH --exclude-if-present .restic_do_not_backup_this_dir
    else
      echo "! Backup alleready running ! "
    fi
    echo "$(date) --- Backup end ------"
    echo ""
    ;;

  fake-backup )
    echo "$(date) --- Start backup ----"
    echo "restic backup $RESTIC_BACKUP_PATH --host $Computer_Name $Computer_Owner $Computer_Modele $Computer_OSVersion $Computer_Serial $RESTIC_EXCLUDE_PATH" --exclude-if-present .restic_do_not_backup_this_dir
    echo "$(date) --- Backup end ------"
    ;;

  snapshots )

    #Check if a hostname is specified
    if [[ $2 != "" ]]; then
      Computer_Name=$2
    fi
    echo "$(date) --- Show Snapshots of $Computer_Name ----"
    restic snapshots --host $Computer_Name
    echo "$(date) --- Stop Show Snapshots ----"

    ;;

  snapshots-all )
    echo "$(date) --- Show All Snapshots ----"
    restic snapshots
    echo "$(date) --- Stop Show All Snapshots ----"
    ;;

  update )
    update_script
    ;;

  mount)
    if [[ ! -d $Mount_Path ]]; then
      echo "----- Follder don't exist ------------"
      mkdir -p $Mount_Path
      restic mount $Mount_Path
      sleep 2
      rm -rf $Mount_Path

    elif [[ -z "$(ls $Mount_Path)" ]]; then
      echo "----- Follder exist and void ---------"
      restic mount $Mount_Path
      sleep 2
      rm -rf $Mount_Path

    else
      echo "----- Follder exist and not void -----"
      umount $Mount_Path
    fi
    ;;

  forget)
    #Check if a hostname is specified
    if [[ $2 != "" ]]; then
      Computer_Name=$2
    fi
    echo "$(date) --- Forget snapshots of $Computer_Name ----"
    restic forget --group-by host --host $Computer_Name --keep-hourly 168 --keep-daily 90 --keep-monthly 24 --keep-tag FollToKeep
    echo "$(date) --- End of Snapshots forget ----"
    ;;

  fake-forget)
    #Check if a hostname is specified
    if [[ $2 != "" ]]; then
      Computer_Name=$2
    fi
    echo "$(date) --- Forget snapshots of $Computer_Name ----"
    restic forget --group-by host --host $Computer_Name --keep-hourly 168 --keep-daily 90 --keep-monthly 24 --keep-tag FollToKeep --dry-run
    echo "$(date) --- End of Snapshots forget ----"
    ;;

  forget-all)
    echo "$(date) --- Forget snapshots of all ----"
    restic forget --group-by host  --keep-hourly 168 --keep-daily 90 --keep-monthly 24 --keep-tag FollToKeep
    echo "$(date) --- End of Snapshots forget ----"
    ;;

  fake-forget-all)
    echo "$(date) --- Forget snapshots of all ----"
    restic forget --group-by host  --keep-hourly 168 --keep-daily 90 --keep-monthly 24 --keep-tag FollToKeep --dry-run
    echo "$(date) --- End of Snapshots forget ----"
    ;;

  unlock)
    #Unlock wenn restic is locked
    echo "$(date) --- Unlock restic ----"
    restic unlock
    echo "$(date) --- Unlock successfull ----"

      ;;

  help | * )

    echo ""
    echo ""
    echo "------------------------------------------------------------------------"
    echo "------------------------- Restic Backup Script -------------------------"
    echo "------------------------------------------------------------------------"
    echo "-------------------------------- Manual --------------------------------"
    echo "------------------------------------------------------------------------"
    echo "---                                                                  ---"
    echo "--- backup                    Run restic backup                      ---"
    echo "--- fake-backup               Echo the restic backup command         ---"
    echo "--- snapshots [Hostname]      Show snapshots of this computer        ---"
    echo "--- snapshots-all             Show snapshots of all computers        ---"
    echo "--- mount                     Mount restic backup on ~/Restic        ---"
    echo "--- update                    Updte the script from Github.com       ---"
    echo "--- forget [Hostname]         Forget snapshots of this computer      ---"
    echo "--- forget-all                Forget snapshots of all computer       ---"
    echo "--- fake-forget [Hostname]    Forget snapshots of this computer      ---"
    echo "--- fake-forget-all           Forget snapshots of all computer       ---"
    echo "--- unlock                    Unlock restic repository               ---"
    echo "--- help                      Print this page                        ---"
    echo "---                                                                  ---"
    echo "------------------------------------------------------------------------"
    echo "---------------------- ©Matéo Muller - subnet.dev ----------------------"
    echo "------------------------------------------------------------------------"
    echo "---------- https://github.com/subnet-dev/restic-backup-script ----------"
    echo "------------------------------------------------------------------------"
    echo ""
    echo ""
    ;;
esac
