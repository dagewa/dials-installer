# Activate DIALS for the current shell:  . setpaths.sh
#
# Only dialsbin goes on PATH -- it holds a forwarder for every DIALS, xia2, dui2,
# dxtbx and cctbx command.  The forwarders set up the rest of the environment
# for the programs they launch, so nothing else from the bundled conda
# environment needs to be exposed here.
#
# The location is resolved relative to this file rather than baked in at
# install time, so the installation directory can be moved.  Must be sourced
# (from bash or zsh), not executed.

if [ -n "${BASH_VERSION:-}" ]; then
    _dials_self="${BASH_SOURCE[0]}"
elif [ -n "${ZSH_VERSION:-}" ]; then
    _dials_self="${(%):-%x}"
else
    echo "setpaths.sh: source this from bash or zsh" >&2
    _dials_self=""
fi

if [ -n "${_dials_self}" ]; then
    _dials_prefix=$(cd -- "$(dirname -- "${_dials_self}")" && pwd)
    PATH="${_dials_prefix}/dialsbin:${PATH}"
    export PATH
    unset _dials_prefix
fi
unset _dials_self
