#### Script Constant ####
SCRIPT_DIR_PATH=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )

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

# Function to check if command is installed
function check_if_installed() {
  if [[ ! -z $1 ]]; then

    if [[ $(command -v $1) ]]; then
      echo 1
    else
      echo 0
    fi

  else
    echo 0
  fi
}

#### Code start ####

# Include restic authentification file if exist
if [[ $(check_file_or_dir_exist $SCRIPT_DIR_PATH/restic_var) == 1 ]]; then
  . $SCRIPT_DIR_PATH/restic_var
fi

# Check if github.com is accessible and if auto update is enable
if [[ $SCRIPT_AUTO_UPDATE == "true" ]] && [[ $(check_connection github.com) == "1" ]]; then
  echo "Script update"
  git -C $SCRIPT_DIR_PATH pull
  echo ""
else
  echo "Auto update disable or no access to github.com"
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

# Check if restic is installed
if [[ ! $(check_if_installed restic) == "1" ]]; then
  echo "Restic isn't installed or isn't in the \$PATH"
  echo "Installation documentation : https://restic.readthedocs.io/en/stable/020_installation.html"
  exit
fi

# Detect witch system it is
uname_output="$(uname -s)"
case "${uname_output}" in
    Linux*)     system=Linux;;
    Darwin*)    system=MacOS;;
    CYGWIN*)    system=Cygwin;;
    MINGW*)     system=MinGw;;
    *)          system="UNKNOWN:${uname_output}"
esac
