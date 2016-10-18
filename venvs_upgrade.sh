# shellcheck disable=SC2148

# This function is needed because some of your virtualenvs might end up be broken after an upgrade of the Python version used in it, 
# especially with macOS Homebrew (see http://stackoverflow.com/a/25947333/3190077)
venvs_upgrade() {
	_venvs_checklist || return 1
	local warning="\
This solution will only work if you want to ugrade within the same python version,\
such as within Python 2.7 or within Python 3.5. Are you sure ? (y/n) \
"	
	_venvs_printf "$warning"
	while true; do
		_venvs_read -r reply
		# shellcheck disable=SC2154
		case "$reply" in
		    [yY][eE][sS]|[yY]) 
				# shellcheck disable=SC1001
		        for venv in $(\lsvirtualenv -b); do
					_venvs_upgrade_python "$venv"
				done;
				return
		        ;;
		    [nN][oO]|[nN])
				return
				;;
		    *)
		        _venvs_printf "Please answer yes or no\n"
		        ;;
		esac
	done
}

_venvs_upgrade_python() {
	local venv="$1"
	local venv_dir="${WORKON_HOME}/${venv}"
	_venvs_printf "\nUpgrading virtualenv ${venv}\n"
	_venvs_check_dir "$venv_dir" || return 1
	_venvs_remove_python_broken_symlinks "$venv" "$venv_dir" || return 1
	_venvs_revirtualize "$venv" "$venv_dir" || return 1
	
}

# each virtualenv should correspond to a unique directory inside the $WORKON_HOME folder
_venvs_check_dir() {
	local venv_dir="$1"
	if ! [ -d "$venv_dir" ]; then
		_venvs_print_error "No such directory ${venv_dir}"
		return 1
	fi
}

# 'find $V -type l -xtype l -delete' with GNU find would be easier but less portable (see http://stackoverflow.com/a/22099005/3190077)
_venvs_remove_python_broken_symlinks() {
	local venv="$1"
	local venv_dir="$2"
	local find_exec_command="for x; do [ -e \"\$x\" ] || \
(\\printf \"Removing broken symlink \"\$x\"\\\n\"; command rm \"\$x\"); done"
	if ! command find "$venv_dir" -type l -exec sh -c "$find_exec_command" _ {} +; then
		_venvs_print_error "Failed to remove python broken symlinks in virtualenv ${venv}"
		return 1
	fi
}

_venvs_revirtualize() {
	local venv="$1"
	local venv_dir="$2"
	local venv_python
	venv_python=$(command find "${venv_dir}/bin" -type f -exec command basename {} \; | (_venvs_grep "^python[2-3].[0-9]\+"))
	if [ -n "$venv_python" ]; then
		_venvs_printf "Python version used by virtualenv: ${venv_python}\n"  
		command virtualenv -p "$venv_python" "$venv_dir"
	else
		_venvs_print_error "Failed to \"revirtualise\" virtualenv ${venv}, unknown python version. You might need to upgrade this virtualenv manually."
		return 1
	fi
}
