#!/usr/bin/env bash

venvs_setup() {
	_venvs_checklist || return 1
	local postactivate="${VIRTUALENVWRAPPER_HOOK_DIR}/postactivate"
	_venvs_add_line_to_hook_script "$postactivate" "unalias python pip 2>/dev/null" || return 1

	local postdeactivate="${VIRTUALENVWRAPPER_HOOK_DIR}/postdeactivate"
	local python_alias pip_alias
	python_alias=$(alias | _venvs_grep "python=")
	pip_alias=$(alias | _venvs_grep "pip=")
	for alias in "$python_alias" "$pip_alias"; do
		if [ -n "$alias" ]; then # alias command outputs 'alias ' as prefix in bash while it doesn't in zsh
			_venvs_add_line_to_hook_script "$postdeactivate" "alias ${alias#'alias '}" || return 1
		fi
	done
}

_venvs_add_line_to_hook_script() {
	local script="$1"
	local line="$2"

	if [ -r "$script" ] && [ -f "$script" ]; then
		if ! (_venvs_grep -Fqx "$line" "$script" 2>/dev/null); then
			_venvs_printf "Add the following line to ${script} : "
			_venvs_printf "${line}\n" | tee -a "$script"
			_venvs_printf "\n"
		fi
	else
		_venvs_print_error "No such file ${script}"
		return 1
	fi
}
