#!/usr/bin/env bash

_venvs_force_buitlin() {
	local cmd="$1"
	shift
	if [ -n "$ZSH_VERSION" ]; then
		builtin "$cmd" "$@" || return 1
	else
		command "$cmd" "$@" || return 1
	fi
}

_venvs_printf () {
	_venvs_force_buitlin printf "$@"
}

_venvs_print_error () {
	local error="$1"
    _venvs_printf "ERROR: %s\n" "$error" >&2
}

_venvs_grep () {
	GREP_OPTIONS="" command grep "$@"
}

_venvs_cd() {
	_venvs_force_buitlin cd "$@"
}

_venvs_pwd() {
	_venvs_force_buitlin pwd "$@"
}

_venvs_read() {
	_venvs_force_buitlin read "$@"
}

# verify that the passed resources is in path and exists
# this is orginally the virtualenvwrapper's function "virtualenvwrapper_verify_resource"
# https://bitbucket.org/virtualenvwrapper/virtualenvwrapper/src/3ca89a29ab6c12fa6974f4f31d1520aaed921808/virtualenvwrapper.sh?fileviewer=file-view-default#virtualenvwrapper.sh-319:333
_venvs_is_resource() {
	local exe="$1"
	local exe_path
	exe_path="$(command which "$exe" | (_venvs_grep -v "not found"))"
	if [ -z "$exe_path" ]; then
		_venvs_print_error "Could not find ${exe} in your path"
		return 1
	fi
	if [ ! -e "$exe_path" ]; then
    	_venvs_print_error "Found ${exe} in path as ${exe_path} but that does not exist"
    	return 1
	fi
}

_venvs_is_function() {
	local fct="$1"
	if ! type -a "$fct" 2>/dev/null | _venvs_grep -Ex "${fct} is a[ shell]* function[ from ]*\S*" >/dev/null; then
		_venvs_print_error "${fct} is not a function"
		return 1
	fi
}

_venvs_is_variable() {
	variable_name="$1"
	variable="$2"
	source_script="$3"
	if [ -z "$variable" ]; then
		_venvs_print_error "Variable ${variable_name} is unset, you need to have the script ${source_script} sourced before"
		return 1
	fi
}

_venvs_is_directory() {
	local directory_variable_name="$1"
	local directory_variable="$2"
	_venvs_is_variable  "$directory_variable_name" "$directory_variable" "virtualenvwrapper.sh" || return 1
	if ! [ -d "${directory_variable}/" ]; then
		_venvs_print_error "Directory assigned to variable ${directory_variable_name} does not exist"
		return 1
	fi
}

_venvs_is_deactivated() {
	command python -c 'import sys; sys.real_prefix' 2>/dev/null || return 0
	_venvs_print_error "Cannot run this command within a virtualenv, please run 'deactivate'"
	return 1
}

_venvs_is_supported_shell() {
	if ! [ -n "$BASH_VERSION" ] &&  ! [ -n "$ZSH_VERSION" ]; then
		_venvs_print_error "Unsupported shell, please use bash or zsh"
		return 1
	fi
}

_venvs_checklist() {
	_venvs_is_supported_shell &&
	_venvs_is_deactivated &&
	_venvs_is_resource virtualenv &&
	_venvs_is_resource virtualenvwrapper.sh &&
	_venvs_is_function mkvirtualenv && 
	_venvs_is_function lsvirtualenv &&
	_venvs_is_function rmvirtualenv &&
	_venvs_is_directory WORKON_HOME "$WORKON_HOME" &&
	_venvs_is_directory VIRTUALENVWRAPPER_HOOK_DIR "$VIRTUALENVWRAPPER_HOOK_DIR"
}
