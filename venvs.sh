#!/usr/bin/env bash

printf_builtin() {
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
	printf_builtin "ERROR: Unsupported shell, please use bash or zsh" >&2
	return 1
fi

# deal with the case when 'venvs.sh' is a symlink to the 'real' script
if ! real_script="$(command readlink -f "$venvs_source_script" 2>/dev/null)"; then # macos readlink  doesn't behave the same way as gnu readlink
	real_script="$(command python -c 'import os,sys;print(os.path.realpath(sys.argv[1]))' "$venvs_source_script")"
fi
venvs_source_dir="$(command dirname "$real_script")"

. "${venvs_source_dir}/venvs_utils.sh" || return 1
. "${venvs_source_dir}/venvs_setup.sh" || return 1
. "${venvs_source_dir}/venvs_generate.sh" || return 1
. "${venvs_source_dir}/venvs_upgrade.sh" || return 1

unset -f printf_builtin
unset venvs_source_script real_dir venvs_source_dir

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
