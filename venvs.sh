#!/usr/bin/env bash

_printf_builtin() {
	# shellcheck disable=SC2039
	if [ -n "$ZSH_VERSION" ]; then
		builtin printf "$@" || return 1
	else
		command printf "$@" || return 1
	fi
}

# shellcheck disable=SC2128
if [ -n "$BASH_SOURCE" ]; then
	venvs_source_script="$BASH_SOURCE"
elif [ -n "$ZSH_VERSION" ]; then
	builtin setopt function_argzero
	venvs_source_script="$0"
else
	_printf_builtin "ERROR: Unsupported shell, please use bash or zsh" >&2
	return 1
fi
venvs_source_dir="$(command dirname "$venvs_source_script")"

. "${venvs_source_dir}/venvs_utils.sh" || return 1
. "${venvs_source_dir}/venvs_setup.sh" || return 1
. "${venvs_source_dir}/venvs_generate.sh" || return 1
. "${venvs_source_dir}/venvs_upgrade.sh" || return 1

unset -f _printf_builtin
unset venvs_source_script venvs_source_dir

venvs () {
	_venvs_checklist || return 1
	if [ "$1" = "--u" ] || [ "$1" = "-u" ] || [ "$1" = "--update" ]; then
		venvs_upgrade
	else
		venvs_setup || return 1
		local venvs_file="$1"
		venvs_generate "$venvs_file" || return 1
	fi
}
