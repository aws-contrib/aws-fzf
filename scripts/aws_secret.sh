#!/usr/bin/env bash

[ -z "$DEBUG" ] || set -x

set -eo pipefail

_aws_secret_source_dir=$(dirname "${BASH_SOURCE[0]}")
# shellcheck source=aws_core.sh
source "$_aws_secret_source_dir/aws_core.sh"

# _aws_secret_list()
#
# Interactive fuzzy finder for secrets
#
# DESCRIPTION:
#   Displays a list of secrets in an interactive fzf interface.
#   Users can view details, get values, or open the AWS Console.
#
# PARAMETERS:
#   $@ - Optional flags to pass to AWS CLI (--region, --profile, etc.)
#
# RETURNS:
#   0 - Success
#   1 - Failure
#
_aws_secret_list() {
	local list_secrets_args=("$@")

	local secrets_list
	# Define jq formatting
	local secrets_list_jq='(["NAME", "DESCRIPTION", "MODIFIED"] | @tsv),
	                       (.SecretList[] | [.Name, ((.Description // "N/A") | if length > 50 then .[0:47] + "..." else . end), (.LastChangedDate[0:19] | gsub("T"; " "))] | @tsv)'

	# Fetch secrets
	# shellcheck disable=SC2086
	# shellcheck disable=SC2128
	secrets_list="$(
		gum spin --title "Loading AWS Secret Manager Secrets..." -- \
			aws secretsmanager list-secrets "${list_secrets_args[@]}" --output json |
			jq -r "$secrets_list_jq" | column -t -s $'\t'
	)"

	# Check if any secrets were found
	if [ -z "$secrets_list" ]; then
		gum log --level warn "No secrets found"
		return 1
	fi

	local aws_context
	aws_context=$(_get_aws_context)

	# Display in fzf with full keybindings
	echo "$secrets_list" | fzf "${_fzf_options[@]}" \
		--with-nth 1.. --accept-nth 1 \
		--footer "$_fzf_icon Secret Manager Secrets $_fzf_split $aws_context" \
		--bind "enter:execute(aws secretsmanager describe-secret --secret-id {1} | jq .)+abort" \
		--bind "ctrl-o:execute-silent($_aws_secret_source_dir/aws_secret_cmd.sh view-secret {1})" \
		--bind "alt-a:execute-silent($_aws_secret_source_dir/aws_secret_cmd.sh copy-arn {1})" \
		--bind "alt-n:execute-silent($_aws_secret_source_dir/aws_secret_cmd.sh copy-name {1})" \
		--bind "alt-v:execute($_aws_secret_source_dir/aws_secret_cmd.sh copy-value {1})"
}

# _aws_secret_help()
#
# Show secrets command help
#
_aws_secret_help() {
	cat <<'EOF'
aws fzf secret - Interactive Secrets Manager browser

USAGE:
    aws fzf secret list [options]

OPTIONS:
    All AWS CLI options are passed through:
    --region <region>           AWS region
    --profile <profile>         AWS profile
    --max-results <number>      Maximum secrets to fetch
    --filters <filters>         Secret filters

KEYBOARD SHORTCUTS:
    All resources:
        enter       Show secret metadata (without value)
        ctrl-o      Open secret in AWS Console
        alt-v       Copy secret value to clipboard
        alt-a       Copy secret ARN to clipboard
        alt-n       Copy secret name to clipboard

PERFORMANCE:
    The list-secrets API paginates results automatically.
    Use --max-results to control page size (default: 100, max: 100).
    Use --filters to narrow results at the API level for better performance.

EXAMPLES:
    # List all secrets
    aws fzf secret list

    # List secrets in specific region
    aws fzf secret list --region us-west-2

    # List secrets with specific profile
    aws fzf secret list --profile production

    # Filter secrets by name pattern
    aws fzf secret list --filters Key=name,Values=prod*

    # Combine filters and region
    aws fzf secret list --region us-east-1 --filters Key=name,Values=database*

SEE ALSO:
    AWS CLI Secrets Manager: https://docs.aws.amazon.com/cli/latest/reference/secretsmanager/
EOF
}

# aws_secret.sh - Secrets Manager browsing for aws fzf
#
# This file is sourced by the main aws fzf script and provides
# Secrets Manager listing with interactive functionality.
#
# Dependencies from main aws fzf:
#   - $_aws_fzf_source_dir (source directory path)
#   - aws CLI
#   - fzf
#   - jq
#   - gum
#   - Utility functions from utils/ (clipboard, console_url)

# _aws_secret_main()
#
# Handle secrets subcommands
#
# DESCRIPTION:
#   Routes secrets subcommands to appropriate handlers. Supports
#   list-secrets for interactive secrets browsing.
#
# PARAMETERS:
#   $1 - Subcommand (list-secrets)
#   $@ - Additional arguments passed to AWS CLI
#
# RETURNS:
#   0 - Success
#   1 - Unknown subcommand or error
#
_aws_secret_main() {
	local subcommand="$1"
	shift

	case $subcommand in
	list)
		_aws_secret_list "$@"
		;;
	--help | -h | help | "")
		_aws_secret_help
		;;
	*)
		gum log --level error "Unknown secret subcommand '$subcommand'"
		gum log --level info "Supported: list"
		gum log --level info "Run 'aws fzf secret --help' for usage"
		return 1
		;;
	esac
}

# ------------------------------------------------------------------------------
# Direct Execution Support
# ------------------------------------------------------------------------------
# When run directly (not sourced), pass all arguments to _aws_secret_main.
# This enables tmux integration and scripted usage.
# ------------------------------------------------------------------------------
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
	_aws_secret_main "$@"
fi
