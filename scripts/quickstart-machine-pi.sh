#!/bin/bash
set -e
function local_read_args() {
  while (( "$#" )); do
  opt="$1"
  case $opt in
    -h|-\?|--\?--help)
      PRINT_USAGE=1
      QUICKSTART_ARGS="$SCRIPT $1"
      break
    ;;
    -b|--branch)
      BRANCH="$2"
      QUICKSTART_ARGS+=" $1 $2"
      shift
    ;;
    -o|--override)
      QUICKSTART_ARGS=" $SCRIPT"
    ;;
    --skip-setup)
      SKIP_SETUP=true
    ;;
    *)
      QUICKSTART_ARGS+=" $1"
      #echo $1
    ;;
  esac
  shift
  done

  if [[ -z $BRANCH ]]; then
    echo "Usage: $0 -b/--branch <branch> [--skip-setup]"
    exit 1
  fi
}

BRANCH="master"
PRINT_USAGE=0
SKIP_SETUP=false
#ASSET_MODEL="-amrmd predix-ui-seed/server/sample-data/predix-asset/asset-model-metadata.json predix-ui-seed/server/sample-data/predix-asset/asset-model.json"
SCRIPT="-script build-basic-app.sh -script-readargs build-basic-app-readargs.sh"
QUICKSTART_ARGS="-ba -uaa -asset -ts -wd -nsts -mc $SCRIPT"
IZON_SH="https://github.build.ge.com/raw/adoption/izon/1.0.0/izon.sh"
VERSION_JSON="version.json"
PREDIX_SCRIPTS=predix-scripts
VERSION_JSON="version.json"
APP_NAME="Edge Starter: Predix Machine for Raspberry Pi"
TOOLS="Cloud Foundry CLI, Git, Maven, Node.js"
TOOLS_SWITCHES="--cf --git --maven --nodejs"

local_read_args $@
VERSION_JSON_URL=https://github.build.ge.com/raw/adoption/predix-machine-template-adapter-simulator/$BRANCH/version.json


function check_internet() {
  set +e
  echo ""
  echo "Checking internet connection..."
  curl "http://google.com" > /dev/null 2>&1
  if [ $? -ne 0 ]; then
    echo "Unable to connect to internet, make sure you are connected to a network and check your proxy settings if behind a corporate proxy"
    echo "If you are behind a corporate proxy, set the 'http_proxy' and 'https_proxy' environment variables."
    exit 1
  fi
  echo "OK"
  echo ""
  set -e
}

function init() {
  currentDir=$(pwd)
  if [[ $currentDir == *"scripts" ]]; then
    echo 'Please launch the script from the root dir of the project'
    exit 1
  fi

  check_internet
  #if needed, get the version.json that resolves dependent repos from another github repo
  if [ ! -f "$VERSION_JSON" ]; then
    curl -s -O $VERSION_JSON_URL
  fi
  #get the script that reads version.json
  eval "$(curl -s -L $IZON_SH)"
  #get the url and branch of the requested repo from the version.json
  __readDependency "local-setup" LOCAL_SETUP_URL LOCAL_SETUP_BRANCH
  #get the predix-scripts url and branch from the version.json
  __readDependency $PREDIX_SCRIPTS PREDIX_SCRIPTS_URL PREDIX_SCRIPTS_BRANCH
  if [ ! -d "$PREDIX_SCRIPTS" ]; then
    echo "Cloning predix script repo ..."
    git clone --depth 1 --branch $PREDIX_SCRIPTS_BRANCH $PREDIX_SCRIPTS_URL
  else
  	echo "Predix scripts repo found reusing it..."
  	cd predix-scripts
    git pull
    cd ..
  fi
  source $PREDIX_SCRIPTS/bash/scripts/local-setup-funcs.sh
}

if [[ $PRINT_USAGE == 1 ]]; then
  init
  __print_out_standard_usage
else
  if $SKIP_SETUP; then
    init
  else
    init
    __standard_mac_initialization
  fi
fi

SKIP_ALL_DONE=1
echo "quickstart_args=$QUICKSTART_ARGS"
source $PREDIX_SCRIPTS/bash/quickstart.sh $QUICKSTART_ARGS



#post quickstart customizations
cd $rootDir/..
echo "MACHINE_VERSION : $MACHINE_VERSION"
echo "PREDIX_MACHINE_HOME : $PREDIX_MACHINE_HOME"

__print_center "Build and setup the Predix Machine Adapter" "#"

__echo_run cp "config/com.ge.predix.solsvc.workshop.adapter.config.config" "$PREDIX_MACHINE_HOME/configuration/machine"
__echo_run cp "config/com.ge.predix.workshop.nodeconfig.json" "$PREDIX_MACHINE_HOME/configuration/machine"
__echo_run cp "config/com.ge.dspmicro.hoover.spillway-0.config" "$PREDIX_MACHINE_HOME/configuration/machine"
if [[ -f config/setvars.sh ]]; then
	__echo_run cp "config/setvars.sh" "$PREDIX_MACHINE_HOME/machine/bin/predix/setvars.sh"
fi

#Replace the :TAE tag with instance prepender
configFile="$PREDIX_MACHINE_HOME/configuration/machine/com.ge.predix.workshop.nodeconfig.json"
__find_and_replace ":TAE" ":$(echo $INSTANCE_PREPENDER | tr 'a-z' 'A-Z')" "$configFile" "$quickstartLogDir"
echo "MAVEN_SETTINGS_FILE : $MAVEN_SETTINGS_FILE"

./predix-scripts/bash/scripts/buildMavenBundle.sh "$PREDIX_MACHINE_HOME"

PREDIX_SERVICES_SUMMARY_FILE="predix-scripts/log/predix-services-summary.txt"

echo "" >> "$PREDIX_SERVICES_SUMMARY_FILE"
echo "Edge Device Specific Configuration" >> "$PREDIX_SERVICES_SUMMARY_FILE"
echo "What did we do:"  >> "$PREDIX_SERVICES_SUMMARY_FILE"
echo "We setup some configuration files in the Predix Machine container to read from a DataNode for our sensors"  >> "$PREDIX_SERVICES_SUMMARY_FILE"
echo "We installed some Intel API jar files that represent the Intel mraa and upm API" >> "$PREDIX_SERVICES_SUMMARY_FILE"
echo "We built and deployed the Machine Adapter bundle which reads from the Intel API" >> "$PREDIX_SERVICES_SUMMARY_FILE"
echo "" >> "$PREDIX_SERVICES_SUMMARY_FILE"
echo "The Predix Machine is in 2 places.  1. where this script prepared the Predix Machine.  2. Where this script copied the compressed version to." >> "$SUMMARY_TEXTFILE"
echo "You can go to location 2, back up any older copies of Predix Machine (if desired) and tar -xvzf Predix Machine and launch it there. " >> "$SUMMARY_TEXTFILE"
echo "Or you can now start Machine at location 1 as follows" >> "$SUMMARY_TEXTFILE"
echo "cd $PREDIX_MACHINE_HOME/machine/bin/predix" >> "$SUMMARY_TEXTFILE"
echo "./start_container.sh clean" >> "$SUMMARY_TEXTFILE"

allDone

__append_new_line_log "Successfully completed $APP_NAME installation!" "$quickstartLogDir"