# Environment variables
. "/home/wjjunyor/.nix-profile/etc/profile.d/hm-session-vars.sh"

# Only source this once
if [[ -z "$__HM_ZSH_SESS_VARS_SOURCED" ]]; then
export __HM_ZSH_SESS_VARS_SOURCED=1

fi

# export ZDOTDIR=$HOME/.config/home-manager/dotfiles/.zsh

ZSH="/nix/store/z4d9mzj5kgc948d17m46lcjqk6rni7qa-oh-my-zsh-2024-10-01/share/oh-my-zsh";
ZSH_CACHE_DIR="/home/wjjunyor/.cache/oh-my-zsh";

