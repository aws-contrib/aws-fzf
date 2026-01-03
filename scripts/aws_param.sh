#!/bin/bash
set -o pipefail

_aws_param_source_dir=$(dirname "${BASH_SOURCE[0]}")
# shellcheck source=aws_core.sh
source "$_aws_param_source_dir/aws_core.sh"

# _aws_param_list()
#
# Interactive fuzzy finder for parameters
#
# DESCRIPTION:
#   Displays a list of parameters in an interactive fzf interface.
#   Users can view details, get values, or open the AWS Console.
#
# PARAMETERS:
#   $@ - Optional flags to pass to AWS CLI (--region, --profile, etc.)
#
# RETURNS:
#   0 - Success
#   1 - Failure
#
_aws_param_list() {
	local describe_params_args=("$@")

	local param_list
	# Define jq formatting
	local param_list_jq='(["NAME", "TYPE", "VERSION", "MODIFIED"] | @tsv),
	                     (.Parameters[] | [.Name, .Type, .Version, (.LastModifiedDate[0:19] | gsub("T"; " "))] | @tsv)'

	# Fetch parameters
	# shellcheck disable=SC2086
	# shellcheck disable=SC2128
	param_list="$(
		gum spin --title "Loading AWS Parameters..." -- \
			aws ssm describe-parameters $describe_params_args --output json |
			jq -r "$param_list_jq" | column -t -s $'\t'
	)"

	# Check if any parameters were found
	if [ -z "$param_list" ]; then
		gum log --level warn "No parameters found"
		return 1
	fi

	# Display in fzf with full keybindings
	echo "$param_list" | fzf "${_fzf_options[@]}" \
		--with-nth 1.. --accept-nth 1 \
		--footer "  Parameters" \
		--bind "enter:execute(aws ssm describe-parameters --filters 'Key=Name,Values={1}' | jq .)+abort" \
		--bind "ctrl-o:execute-silent($_aws_param_source_dir/aws_param_cmd.sh view-parameter {1})" \
		--bind "ctrl-v:execute($_aws_param_source_dir/aws_param_cmd.sh get-value {1})+abort"
}

# _aws_param_help()
#
# Show params command help
#
_aws_param_help() {
	cat <<'EOF'
aws fzf param - Interactive Parameter Store browser

USAGE:
    aws fzf param list [options]

OPTIONS:
    All AWS CLI options are passed through:
    --region <region>           AWS region
    --profile <profile>         AWS profile
    --max-results <number>      Maximum parameters to fetch
    --filters <filters>         Parameter filters

KEYBOARD SHORTCUTS:
    enter       Show parameter metadata (without value)
    ctrl-o      Open parameter in AWS Console
    ctrl-v      Get parameter value (prompts for SecureString)

SECURITY:
    SecureString parameters require confirmation before decryption

EXAMPLES:
    aws fzf param list
    aws fzf param list --region us-west-2
    aws fzf param list --max-results 100
EOF
}

# aws_param.sh - Parameter Store browsing for aws fzf
#
# This file is sourced by the main aws fzf script and provides
# Parameter Store listing with interactive functionality.
#
# Dependencies from main aws fzf:
#   - $_aws_fzf_source_dir (source directory path)
#   - aws CLI
#   - fzf
#   - jq
#   - gum
#   - Utility functions from utils/ (clipboard, console_url)

# _aws_param_main()
#
# Handle params subcommands
#
# DESCRIPTION:
#   Routes param subcommands to appropriate handlers. Supports
#   list for interactive parameter browsing.
#
# PARAMETERS:
#   $1 - Subcommand (list)
#   $@ - Additional arguments passed to AWS CLI
#
# RETURNS:
#   0 - Success
#   1 - Unknown subcommand or error
#
_aws_param_main() {
	local subcommand="$1"
	shift

	case $subcommand in
	list)
		_aws_param_list "$@"
		;;
	--help | -h | help | "")
		_aws_param_help
		;;
	*)
		gum log --level error "Unknown param subcommand '$subcommand'"
		gum log --level info "Supported: list"
		gum log --level info "Run 'aws fzf param --help' for usage"
		return 1
		;;
	esac
}

# ------------------------------------------------------------------------------
# Direct Execution Support
# ------------------------------------------------------------------------------
# When run directly (not sourced), pass all arguments to _aws_param_main.
# This enables tmux integration and scripted usage.
# ------------------------------------------------------------------------------
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
	_aws_param_main "$@"
fi
