ASDF_PYAPP_MY_NAME=asdf-pyapp

# 0: (default) Copy venvs with explicit python version, symlink otherwise.
# 1: Prefer copies.
ASDF_PYAPP_VENV_COPY_MODE=${ASDF_PYAPP_VENV_COPY_MODE:-0}

ASDF_PYAPP_RESOLVED_PYTHON_PATH=

if [[ ${ASDF_PYAPP_DEBUG:-} -eq 1 ]]; then
  # In debug mode, dunp everything to a log file
  # got a little help from https://askubuntu.com/a/1345538/985855

  ASDF_PYAPP_DEBUG_LOG_PATH="/tmp/${ASDF_PYAPP_MY_NAME}-debug.log"
  mkdir -p "$(dirname "$ASDF_PYAPP_DEBUG_LOG_PATH")"

  printf "\n\n-------- %s ----------\n\n" "$(date)" >>"$ASDF_PYAPP_DEBUG_LOG_PATH"

  exec > >(tee -ia "$ASDF_PYAPP_DEBUG_LOG_PATH")
  exec 2> >(tee -ia "$ASDF_PYAPP_DEBUG_LOG_PATH" >&2)

  exec 19>>"$ASDF_PYAPP_DEBUG_LOG_PATH"
  export BASH_XTRACEFD=19
  set -x
fi

fail() {
  echo >&2 -e "${ASDF_PYAPP_MY_NAME}: [ERROR] $*"
  exit 1
}

log() {
  if [[ ${ASDF_PYAPP_DEBUG:-} -eq 1 ]]; then
    echo >&2 -e "${ASDF_PYAPP_MY_NAME}: $*"
  fi
}

get_python_version() {
  local python_path="$1"
  local regex='Python (.+)'

  python_version_raw=$("$python_path" --version)

  if [[ $python_version_raw =~ $regex ]]; then
    echo -n "${BASH_REMATCH[1]}"
  else
    fail "Unable to determine python version"
  fi
}

get_python_pip_versions() {
  local python_path="$1"

  local pip_version_raw
  pip_version_raw=$("${python_path}" -m pip --version)
  local regex='pip (.+) from.*\(python (.+)\)'

  if [[ $pip_version_raw =~ $regex ]]; then
    echo -n "${BASH_REMATCH[1]}"
    #ASDF_PYAPP_PYTHON_VERSION="${BASH_REMATCH[2]}" # probably not longer needed
  else
    fail "Unable to determine pip version"
  fi
}

resolve_python_path() {
  # if ASDF_PYAPP_DEFAULT_PYTHON_PATH is set, use it, else:
  # 1. try $(asdf which python)
  # 2. try $(which python3)

  if [ -n "${ASDF_PYAPP_DEFAULT_PYTHON_PATH+x}" ]; then
    ASDF_PYAPP_RESOLVED_PYTHON_PATH="$ASDF_PYAPP_DEFAULT_PYTHON_PATH"
    return
  fi

  # cd to $HOME to avoid picking up a local python from .tool-versions
  # pipx is best when install with a global python
  pushd "$HOME" >/dev/null || fail "Failed to pushd \$HOME"

  # run direnv in $HOME to escape any direnv we might already be in
  if type -P direnv &>/dev/null; then
    eval "$(DIRENV_LOG_FORMAT= direnv export bash)"
  fi

  local pythons=()

  local asdf_python
  if asdf_python=$(asdf which python3 2>/dev/null); then
    pythons+=("$asdf_python")
  else
    local global_python
    global_python=$(which python3)
    pythons+=("$global_python")
  fi

  for p in "${pythons[@]}"; do
    local python_version
    log "Testing '$p' ..."
    python_version=$(get_python_version "$p")
    if [[ $python_version =~ ^([0-9]+)\.([0-9]+)\. ]]; then
      local python_version_major=${BASH_REMATCH[1]}
      local python_version_minor=${BASH_REMATCH[2]}
      if [ "$python_version_major" -ge 3 ] && [ "$python_version_minor" -ge 6 ]; then
        ASDF_PYAPP_RESOLVED_PYTHON_PATH="$p"
        break
      fi
    else
      continue
    fi
  done

  popd >/dev/null || fail "Failed to popd"

  if [ -z "$ASDF_PYAPP_RESOLVED_PYTHON_PATH" ]; then
    fail "Failed to find python3 >= 3.6"
  else
    log "Using python3 at '$ASDF_PYAPP_RESOLVED_PYTHON_PATH'"
  fi
}

get_package_versions() {
  local package=$1
  curl -Ls "https://pypi.org/pypi/${package}/json" |
    python3 -c '
import sys,json

raw_response = sys.stdin

try:
    data = json.load(raw_response)
except json.JSONDecodeError:
    sys.stderr.write("Error: failed to parse PyPI response:\n")
    sys.stderr.write(raw_response + "\n")
    sys.exit(1)

# handle "Not Found"
if data.get("message") == "Not Found":
    sys.stderr.write(f"Error: package not found on PyPI\n")
    sys.exit(1)

versions=data["releases"].keys()
sorted_versions=sorted(versions, key=lambda v: [x for x in v.split(".")])
print(*sorted_versions, sep="\n")
'
  # Same as:
  #     curl ... | jq -r '.releases | keys_unsorted | sort_by(split(".")) | .[]'
  # typically I would use here jq, but it means introducing yet another dependency.
  # Here when we are certain Python is provided, we can use it instead of jq.
}

sort_versions() {
  sed 'h; s/[+-]/./g; s/.p\([[:digit:]]\)/.z\1/; s/$/.z/; G; s/\n/ /' |
    LC_ALL=C sort -t. -k 1,1 -k 2,2n -k 3,3n -k 4,4n -k 5,5n | awk '{print $2}'
}

install_version() {
  local package="$1"
  local install_type="$2"
  local full_version="$3"
  local install_path="$4"

  local venv_args=()
  local pip_args=("--disable-pip-version-check")

  local versions=(${full_version//\@/ })
  local app_version=${versions[0]}
  if [ "${#versions[@]}" -gt 1 ]; then

    if ! asdf plugin list | grep python; then
      fail "Cannot install $1 $3 - asdf python plugin is not installed!"
    fi

    python_version=${versions[1]}
    asdf install python "$python_version"
    ASDF_PYAPP_RESOLVED_PYTHON_PATH=$(ASDF_PYTHON_VERSION="$python_version" asdf which python3)
  fi

  # check for venv copies
  if [ "${#versions[@]}" -gt 1 ] || [ "$ASDF_PYAPP_VENV_COPY_MODE" == "1" ]; then
    # special check for macOS
    # TODO: write a test for this somehow
    if [ "$ASDF_PYAPP_RESOLVED_PYTHON_PATH" == "/usr/bin/python3" ] && [[ "$OSTYPE" == "darwin"* ]]; then
      log "Copying /usr/bin/python3 on macOS does not work, symlinking"
    else
      venv_args+=("--copies")
    fi
  fi

  if [ "${install_type}" != "version" ]; then
    fail "supports release installs only"
  fi

  mkdir -p "${install_path}"

  # Make a venv for the app
  local venv_path="$install_path"/venv
  "$ASDF_PYAPP_RESOLVED_PYTHON_PATH" -m venv ${venv_args[@]+"${venv_args[@]}"} "$venv_path"
  # setuptools might be upgraded by itself https://stackoverflow.com/a/71239956/4468
  "$venv_path"/bin/python3 -m pip install ${pip_args[@]+"${pip_args[@]}"} --upgrade setuptools
  "$venv_path"/bin/python3 -m pip install ${pip_args[@]+"${pip_args[@]}"} --upgrade pip wheel

  # Install the App
  "$venv_path"/bin/python3 -m pip install "$package"=="$app_version"

  # Set up a venv for the linker helper
  local link_apps_venv="$install_path"/tmp/link_apps
  mkdir -p "$(dirname "$link_apps_venv")"
  "$ASDF_PYAPP_RESOLVED_PYTHON_PATH" -m venv "$link_apps_venv"
  "$link_apps_venv"/bin/python3 -m pip install "${pip_args[@]}" -r "$plugin_dir"/lib/helpers/link_apps/requirements.txt

  # Link Apps
  "$link_apps_venv"/bin/python3 "$plugin_dir"/lib/helpers/link_apps/link_apps.py "$venv_path" "$package" "$install_path"/bin
}

resolve_python_path
