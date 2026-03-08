# aws-fzf.plugin.zsh — zsh plugin entry point
#
# Adds the aws-fzf binary to PATH so the AWS CLI alias can resolve it.
# Compatible with zinit, oh-my-zsh, antigen, zplug, and manual sourcing.

export PATH="${0:A:h}:$PATH"
