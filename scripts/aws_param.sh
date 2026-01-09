#!/usr/bin/env bash

[ -z "$DEBUG" ] || set -x

set -eo pipefail

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
	# Call the _cmd script to fetch and format parameters
	# shellcheck disable=SC2086
	# shellcheck disable=SC2128
	param_list="$(
		gum spin --title "Loading AWS System Manager Parameters..." -- \
			"$_aws_param_source_dir/aws_param_cmd.sh" list "${describe_params_args[@]}"
	)"

	# Check if any parameters were found
	if [ -z "$param_list" ]; then
		gum log --level warn "No parameters found"
		return 1
	fi

	local aws_context
	aws_context=$(_get_aws_context)

	# Display in fzf with full keybindings
	echo "$param_list" | fzf "${_fzf_options[@]}" \
		--with-nth 1.. --accept-nth 1 \
		--footer "$_fzf_icon System Manager Parameters $_fzf_split $aws_context" \
		--bind "ctrl-r:reload($_aws_param_source_dir/aws_param_cmd.sh list ${describe_params_args[*]})" \
		--bind "enter:execute(aws ssm describe-parameters --filters 'Key=Name,Values={1}' | jq .)+abort" \
		--bind "ctrl-o:execute-silent($_aws_param_source_dir/aws_param_cmd.sh view-parameter {1})" \
		--bind "alt-a:execute-silent($_aws_param_source_dir/aws_param_cmd.sh copy-arn {1})" \
		--bind "alt-n:execute-silent($_aws_param_source_dir/aws_param_cmd.sh copy-name {1})" \
		--bind "alt-v:execute($_aws_param_source_dir/aws_param_cmd.sh copy-value {1})"
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
    All resources:
        ctrl-r      Reload the list
        enter       Show parameter metadata (without value)
        ctrl-o      Open parameter in AWS Console
        alt-v       Copy parameter value to clipboard (prompts for SecureString)
        alt-a       Copy parameter ARN to clipboard
        alt-n       Copy parameter name to clipboard

SECURITY:
    SecureString parameters require explicit confirmation before decryption.
    This prevents accidental exposure of encrypted sensitive values.
    Press alt-v only when you need to copy the actual decrypted value.

PERFORMANCE:
    The describe-parameters API paginates results automatically.
    Use --max-results to control page size (default: 50, max: 50).
    Use --parameter-filters to narrow results at the API level.
    For large parameter sets, filtering at the API level is more efficient.

EXAMPLES:
    # List all parameters
    aws fzf param list

    # List parameters in specific region
    aws fzf param list --region us-west-2

    # Control pagination
    aws fzf param list --max-results 100

    # Use with specific profile
    aws fzf param list --profile production

    # Filter parameters by path
    aws fzf param list --parameter-filters "Key=Name,Option=BeginsWith,Values=/prod/"

SEE ALSO:
    AWS CLI SSM Parameter Store: https://docs.aws.amazon.com/cli/latest/reference/ssm/
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
