# shellcheck disable=SC2148

venvs_generate() {
	_venvs_checklist || return 1
	local venvs="$1"
	local venvs_filename venvs_dirname requirements_file
	venvs_filename="$(command basename "$venvs")"
	venvs_dirname="$(_venvs_cd "$(command dirname "$venvs")" && _venvs_pwd)"
	_venvs_has_venvs_file "$venvs" "$venvs_dirname" || return 1
	_venvs_printf "Found virtualenvs ${venvs_filename} requirement file within ${venvs_dirname}\n"
    # shellcheck disable=SC2016
	_venvs_grep -Ev "^\s*(#|$)" "$venvs"	\
		|	command awk -F'#' '{print $1}'	\
		|	while _venvs_read -r venv venv_options; do
				_venvs_is_not_installed "$venv" || continue
				requirements_file="$(_venvs_build_requirements_filename "$venv")"
				if _venvs_is_root "$venv"; then
					_venvs_generate_as_root "$venv" "$venv_options" "$requirements_file"
				else
					_venvs_generate "$venv" "$venv_options" "$requirements_file"
				fi
			done
}

_venvs_has_requirement_file() {
	local requirements_file="$1"
	local requirements_file_dirname
	requirements_file_dirname="$(command dirname "$requirements_file")"
	if [ -r "$requirements_file" ] && [ -f "$requirements_file" ]; then
		_venvs_printf "Found requirement file ${requirements_file} within ${requirements_file_dirname}\n"
	else
		_venvs_printf "Could not find requirements file ${requirements_file} within ${requirements_file_dirname}\n"
		return 1
	fi
}

# here is the reason why ksh93 is not supported here: this shell doesn't play well with virtualenv's 'deactivate' function
# it appears that on some platforms ksh93 has this mysterious bug that doesn't allow a function to unset itself (with 'unset -f') without wreaking some havoc
# and it turns out that virtualenv's 'deactivate' function unsets itself, which has been observed on some terminals to cause
# either a 'Memory fault' error or the current shell to exit after a call to this function
# http://stackoverflow.com/questions/37536668/create-a-ksh-function-that-unsets-itself
_venvs_deactivate() {
	type deactivate >/dev/null 2>&1 && deactivate

}

_venvs_leave() {
	local old_dir="$1"
	_venvs_deactivate && [ -n "$old_dir" ] && _venvs_cd "$old_dir"
}

_venvs_delete_virtualenv() {
	local venv="$1"
	local old_dir="$2"
	_venvs_leave "$old_dir"
	if _venvs_is_root "$venv"; then
		[ -n "$venv" ] && command sudo command rm "${venv}/bin/activate" # this is enough to allow venv to be "reinstalled" on a later try
	else
		# shellcheck disable=SC1012
		\rmvirtualenv "$venv"
	fi
}

_venvs_install_python_packages() {
	local venv="$1"
	local old_dir="$2"
	local requirements_file="$3"
	if [ -n "$requirements_file" ]; then
		if ! command pip install -r "$requirements_file"; then
			_venvs_print_error "Failed to install some of the requirements packages"
			_venvs_delete_virtualenv "$venv" "$old_dir"
			return 1
		fi
	else
		_venvs_printf "So trying to install a package with the same name as virtualenv ${venv}\n" 
		if ! command pip install "$venv"; then
			_venvs_print_error "Failed to install ${venv} package"
			_venvs_delete_virtualenv "$venv" "$old_dir"
			return 1
		fi
	fi
	_venvs_leave "$old_dir"
}

_venvs_install_python_packages_as_root() {
	local venv="$1"
	local requirements_file="$2"
	if [ -n "$requirements_file" ]; then
		if ! command sudo command pip --no-cache-dir install -r "$requirements_file"; then
			_venvs_print_error "Failed to install some of the requirements packages"
			_venvs_delete_virtualenv "$venv"
			return 1
		fi
	else
		_venvs_printf "So trying to install a package with the same name as virtualenv ${venv}\n" 
		if ! command sudo command pip --no-cache-dir install "$venv"; then
			_venvs_print_error "Failed to install ${venv} package"
			_venvs_delete_virtualenv "$venv"
			return 1
		fi
	fi
	_venvs_leave "$old_dir"
}

# create an "ad-hoc virtualenv", which means a virtualenv whose name matches a single package that can be installed via pip
# if you don't want those kind of virtualenvs, a requirements file of the form 'requirements_{your_venvs_name}.txt' is required.
# otherwise an error will be thrown, as the virtualenv name will likely not match an existing PyPI package.
_venvs_generate() {
	local venv="$1"
	local venv_options="$2"
	local requirements_file="$3"
	local virtualenv_command="PIP_REQUIRE_VIRTUALENV="" \mkvirtualenv ${venv_options} ${venv}"
	local old_dir
	old_dir="$(_venvs_pwd -P)" # save current directory so that we can come back to it in case some 'mkvirtualenev' option changes it

	_venvs_printf "\nCreating virtualenv ${venv}\n"
	if eval "$virtualenv_command"; then
		if [ -z "$(command pip freeze 2>/dev/null)" ]; then
			if _venvs_has_requirement_file "$requirements_file"; then
				_venvs_install_python_packages "$venv" "$old_dir" "$requirements_file" || return 1
			else
				_venvs_install_python_packages "$venv" "$old_dir" || return 1
			fi
		fi
	else
		_venvs_print_error "Failed to create virtualenv ${venv}"
		return 1
	fi
}

_venvs_generate_as_root() {
	local venv="$1"
	local venv_options="$2"
	local requirements_file="$3"
	local virtualenv_command="virtualenv ${venv_options} ${venv}"

	_venvs_printf "\nCreating virtualenv ${venv}\n"
	if command sudo command mkdir -p "$venv" && eval "sudo ${virtualenv_command}" && . "${venv}/bin/activate"; then
		if [ -z "$(command "${venv}/bin/pip" freeze 2>/dev/null)" ]; then
			if _venvs_has_requirement_file "$requirements_file"; then
				_venvs_install_python_packages_as_root "$venv" "$requirements_file" || return 1
			else
				_venvs_install_python_packages_as_root "$venv" || return 1
			fi
		fi
	else
		_venvs_print_error "Failed to create virtualenv ${venv}"
		return 1
	fi
}

_venvs_has_venvs_file() {
	local venvs="$1"
	local venvs_dirname="$2"
	local error_msg
	if [ -z "$venvs" ]; then
		error_msg="argument is missing."
	elif ! [ -f "$venvs" ] || ! [ -r "$venvs" ]; then
		error_msg="${venvs} was not found."
	elif ! [ -s "$venvs" ]; then
		error_msg="${venvs} is empty."
	fi
	if [ -n "$error_msg" ]; then
		local prefix="Could not generate virtualenvs because venvs requirement file"
		local help_msg="\
This file should list the names of all virtualenvs you want to install, \
one name for each line (excluding comments and blank lines)\
"
		_venvs_print_error "${prefix} ${error_msg} ${help_msg}"
		return 1
	fi
}

_venvs_is_root() {
	local venv="$1"
	[ "${venv:0:1}" = "/" ]
}

_venvs_is_not_installed() {
	local venv="$1"
	local venv_already_installed_txt="Virtualenv ${venv} is already installed"
	# shellcheck disable=SC1001
	if _venvs_is_root "$venv"; then
		if command find "$venv/bin" -name activate -type f >/dev/null 2>&1; then
			_venvs_printf "${venv_already_installed_txt}\n"
			return 1
		fi
	elif \lsvirtualenv -b | (_venvs_grep -Fqx "$venv" 2>/dev/null); then
		_venvs_printf "${venv_already_installed_txt}\n"
		return 1
	fi
}

_venvs_build_requirements_filename() {
	local venv="$1"
	if _venvs_is_root "$venv"; then
		local venv_short_name
		venv_short_name="$(command basename "$venv")"
		local requirements_file="${venvs_dirname}/requirements_${venv_short_name}.txt"
	else
		local requirements_file="${venvs_dirname}/requirements_${venv}.txt"
	fi
	_venvs_printf "$requirements_file"
}
