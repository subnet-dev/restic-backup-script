# Include restic authentification var
. restic_var
#### Script Constant ####
SCRIPT_FILE_PATH=$0
SCRIPT_DIR_PATH=$(dirname $SCRIPT_FILE_PATH)

#### Functions ####
# Function to check if some ip is accessible
function check_connection() {
  if [[ ! -z $1 ]]; then
    ping -t 2 -c 1 $1 &> /dev/null
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


