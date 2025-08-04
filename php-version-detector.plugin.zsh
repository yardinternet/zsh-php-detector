debug() {
  # Comment out this line to disable logging completely
  echo "[php-version-detector] $@" >&2
}

# Cache installed versions in a global var (so we only run brew once)
if [[ -z "${_PHP_VERSIONS_CACHE:-}" ]]; then
  _PHP_VERSIONS_CACHE=$(brew list --versions | grep -oE 'php@[0-9]+\.[0-9]+' | sed 's/php@//' | sort -V | uniq)
fi

get_installed_php_versions() {
  echo "$_PHP_VERSIONS_CACHE"
}

detect_php_version() {
  local composer_file="composer.json"
  [[ -f "$composer_file" ]] || return 1

  local constraint=$(jq -r '
    .require.php // .config.platform.php // empty
  ' "$composer_file" 2>/dev/null)

  [[ -z "$constraint" || "$constraint" == "null" ]] && return 1

  local major_minor=$(echo "$constraint" | grep -oE '[0-9]+\.[0-9]+')
  [[ -z "$major_minor" ]] && return 1

  local installed_versions=($(get_installed_php_versions))
  for v in "${installed_versions[@]}"; do
    if [[ "$v" == "$major_minor" ]]; then
      echo "$v"
      return 0
    fi
  done

  return 1
}

switch_php_version() {
  local required_version="$1"
  [[ -z "$required_version" ]] && return 1

  local formula="php@${required_version}"

  if brew list --versions "$formula" >/dev/null 2>&1; then
    local current_php=$(ls -l "$(brew --prefix)/bin/php" 2>/dev/null | awk -F/ '{print $(NF-3)}')

    if [[ "$current_php" == "$formula" ]]; then
        # Already correct version, do nothing
        return 0
    fi

    debug "switching to $formula ..."
    [[ -n "$current_php" ]] && brew unlink "$current_php" >/dev/null 2>&1
    brew link --overwrite --force "$formula" >/dev/null 2>&1
  else
    debug "required PHP version $formula not installed."
    debug "Install it via: brew install $formula" >&2
  fi
}

php_auto_switch() {
  local php_version=$(detect_php_version)
  [[ -n "$php_version" ]] && switch_php_version "$php_version"
}

autoload -U add-zsh-hook
add-zsh-hook chpwd php_auto_switch
php_auto_switch
