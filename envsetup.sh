if [[ "$BASH_SOURCE" = "$0" ]]; then
    printerr "envsetup.sh must be sourced, not executed"
    printerr "   source envsetup.sh"
    exit 1
fi

NORMAL=$(tput sgr0)
RED=$(tput setaf 1)
BLUE=$(tput setaf 4)
AMBER=$(tput setaf 3)
GREEN=$(tput setaf 2)

function printerr {
    echo "${RED}$1${NORMAL}" 1>&2
}

function printsuccess {
    echo "${GREEN}$1${NORMAL}"
}

function printwarning {
    echo "${AMBER}$1${NORMAL}"
}

function printmsg {
    echo "${BLUE}$1${NORMAL}"
}

function printmsg_inline {
    echo -n "${BLUE}$1 ...${NORMAL} "
}

function press_any_key {
    read -n 1 -s -r -p "Press any key to continue"
}

function is_linux {
    [[ "${OSTYPE}" == "linux-gnu" ]] && return 0 || return 1
}

function is_mac {
    [[ "${OSTYPE}" == "darwin"* ]] && return 0 || return 1
}

function is_cygwin {
    [[ "${OSTYPE}" == "cygwin" ]] && return 0 || return 1
}

function ensure_ostype {
    is_linux && return 0
    is_mac && return 0
    is_cygwin && echo "Windows currently unsupported" && return 1
    return 1
}

function ensure_python_version {
    pyver=$(${ADAPT_PYTHON_PATH} --version)
    if [[ "${pyver}" != *"3.10"* && "${pyver}" != *"3.11"* && "${pyver}" != *"3.12"* ]]; then
        printerr "You must have Python 3.10, 3.11 or 3.12, installed to continue"
        return 1
    fi

    printmsg "Using ${pyver}"
}

function ensure_virtualenv_installed {
    virtualenv --version > /dev/null 2>&1

    if [[ $? -ne 0 ]]; then
        printerr "virtualenv not found"
        printwarning "Installing virtualenv. You may need to enter your password for sudo access."
        (is_linux && sudo apt-get install -y virtualenv) || (is_mac && brew install pyenv-virtualenv)
        if [[ $? -ne 0 ]]; then
            printerr "unable to install virtualenv, please install manually"
            return 1
        fi
    fi
}

function ensure_virtualenv_created {
    # get the version of python we are running
    output=$(${ADAPT_PYTHON_PATH} --version)
    py_version=${output##* }
    env_path=${THIS_DIR}/venv-${py_version}/

    if ! [[ -d ${env_path} ]]; then
        printmsg_inline "Creating new virtualenv: ${env_path}"
        virtualenv -p "${ADAPT_PYTHON_PATH}" "${env_path}"
        printsuccess "DONE"
    fi

    source "${env_path}/bin/activate"
    ensure_pip_uptodate || return 1
    ensure_necessary_packages_installed || return 1
    printsuccess "DONE"
    printsuccess "Activated virtualenv: ${env_path}"
}

function ensure_pip_uptodate {
    printmsg "Ensuring pip is up-to-date"
    pip install --upgrade pip
}

function ensure_necessary_packages_installed {
    printmsg "Ensuring all necessary packages are installed"
    pip install "Flask==2.0.1" "Flask-SQLAlchemy==2.5.1" "Flask-Login==0.5.0" "Flask-WTF==0.15.1" "Pillow==8.3.1" "werkzeug==2.0.1" "mysqlclient==2.1.0" "flask-mysqldb==1.0.1"
}

THIS_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"

ENVSETTINGS_PATH="${THIS_DIR}/.envsettings"

if [[ -f ${ENVSETTINGS_PATH} ]]; then
    source "${ENVSETTINGS_PATH}"
fi

QUICK=0
BRANCH=""
PARAMS=""
NO_CONCURRENCY=0
PRODUCT_NAME="mozart"

function print_usage() {
  echo "Usage: envsetup.sh [-hqbpd] [--quick] [--branch BRANCH_NAME] [--python PYTHON_PATH] [--product PRODUCT_NAME] [--help]"
  echo ""
  echo "optional arguments:"
  echo "-h, --help                  show this help message and exit"
  echo "-q, --quick                 skip updating the virtual environment"
  echo "-b, --branch BRANCH_NAME    specify the branch to checkout on all product repositories"
  echo "                            default: mainline"
  echo "-p, --python PYTHON_PATH    path to the python executable you want to use for your virtual environment"
  echo "                            defaults to first found on PATH in order of: 3.8, 3.9, 3.10, 3.11"
  echo "-d, --product PRODUCT_NAME  name of the product you are developing."
  echo "                            choices: mozart, dhal, host_controller, db_api, adapt_installer"
  echo "                            default: mozart"
}

while [[ "$#" -gt 0 ]]; do
    case "$1" in
        -q|--quick)
            QUICK=1
            shift
            ;;
        -b|--branch)
            BRANCH="$2"
            shift
            ;;
        -p|--python)
            ADAPT_PYTHON_PATH="$2"
            shift
            ;;
        -d|--product)
            PRODUCT_NAME="$2"
            shift
            ;;
        --no-concurrency)
            NO_CONCURRENCY=1
            shift
            ;;
        -h|--help)
            print_usage
            return
            ;;
        *)
            PARAMS="$PARAMS $1"
            shift
            ;;
    esac
done

if [[ ${NO_CONCURRENCY} -eq 1 ]]; then
  export WORKSPACE_PY="${THIS_DIR}/workspace.py --no-concurrency"
else
  export WORKSPACE_PY="${THIS_DIR}/workspace.py"
fi

# if we are in a virtual environment, deactivate it first
if [[ -n "${VIRTUAL_ENV}" ]]; then
    printmsg "Deactivating current virtual environment"
    deactivate
fi

# automatically find a supported version of python. 3.8, then 3.9, then 3.10, then 3.11
if [[ -z ${ADAPT_PYTHON_PATH} ]]; then
  ADAPT_PYTHON_PATH=$(which python3.10)
  if [[ $? -ne 0 ]]; then
    ADAPT_PYTHON_PATH=$(which python3.11)
    if [[ $? -ne 0 ]]; then
      ADAPT_PYTHON_PATH=$(which python3.12)
    fi
  fi
fi

# if we still did not find a supported version, error out
if [[ -z ${ADAPT_PYTHON_PATH} ]]; then
  echo "Could not find a supported verion of Python: 3.10, 3.11, or 3.1=12"
  return 1
fi

export ADAPT_PYTHON_PATH=${ADAPT_PYTHON_PATH}
echo "export ADAPT_PYTHON_PATH=${ADAPT_PYTHON_PATH}" > "${ENVSETTINGS_PATH}"

# WORKAROUND FOR ERROR ON MAC OS
export OBJC_DISABLE_INITIALIZE_FORK_SAFETY=YES

ensure_ostype || return 1
ensure_python_version || return 1
ensure_virtualenv_installed || return 1
ensure_virtualenv_created || return 1

#if [ -d "${THIS_DIR}/.repo" ]; then
#  printwarning "Repo is already initialized. To sync all packages with the manifest, run: repo sync"
#else
#  printmsg "Fetching all packages for ${PRODUCT_NAME}"
#  python "${WORKSPACE_PY}" fetch --product "${PRODUCT_NAME}" || return 1
#  printsuccess "Package sync complete"
#fi

if [[ -n ${EXTENSION_PACKAGES} ]]; then
    for package in $EXTENSION_PACKAGES
        do
            python "${WORKSPACE_PY}" fetch_ext --name "${package}" || return 1
        done
fi

# before we potentially call develop on the workspace, we need to be sure we are on the correct branch
if [[ "${BRANCH}" != "" ]]; then
  printmsg "Checking out the specified branch on all repos: ${BRANCH}"
  python "${WORKSPACE_PY}" branch "${BRANCH}"
fi

if [[ ${QUICK} -eq 0 ]]; then
    python "${WORKSPACE_PY}" develop || return 1
fi
python "${WORKSPACE_PY}" git_config || return 1

alias workspace="${WORKSPACE_PY}"
alias syncenv="${WORKSPACE_PY} develop"
alias idhal="ipython -i ${THIS_DIR}/mozart_local_testing.py"
alias precr_generator="python ${THIS_DIR}/precr_generator.py"

if ! [[ -f ${THIS_DIR}/envsetup.sh ]]; then
    cat >${THIS_DIR}/envsetup.sh <<EOL
    cd ${THIS_DIR}/src/MozartDevTools
    source envsetup.sh
    cd ${THIS_DIR}
EOL
fi

function envreset() {
    rm ${THIS_DIR}/.envsettings
    rm -rf ${env_path}
}

function envhelp() {
    echo "${GREEN}Additional Shell Commands:${NORMAL}"
    echo "   ${BLUE}workspace${NORMAL} - Utility to provide information about your current workspace and perform actions on it"
    echo "   ${BLUE}syncenv${NORMAL}  - Ensures all your packages are up-to-date in your workspace (shortcut for workspace develop)"
    echo "   ${BLUE}envreset${NORMAL} - Tear down the setup of your environment. Deletes your virtual environment and cached settings"
    echo "   ${BLUE}find_missing_init_files${NORMAL} - Search project repos for missing __init__.py files"
    echo "   ${BLUE}idhal${NORMAL} - Open ipython terminal to directly test DHAL functions"
    echo "   ${BLUE}precr_generator${NORMAL} - Build tar files of local changes for use with testing changes remotely before CR merge"
}

alias find_missing_init_files=${THIS_DIR}/find_missing_init_files.py

echo

export ENV_HELP=`envhelp`
echo "${ENV_HELP}"
echo
