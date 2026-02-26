#!/usr/bin/env bash

[ -z "$DEBUG" ] || set -x

set -eo pipefail

_aws_sso_source_dir=$(dirname "${BASH_SOURCE[0]}")
# shellcheck source=aws_core.sh
source "$_aws_sso_source_dir/aws_core.sh"

# _aws_sso_profile_list()
#
# Interactive fuzzy finder for SSO profiles
#
# DESCRIPTION:
#   Displays a list of AWS SSO profiles in an interactive fzf interface.
#   Users can login, logout, open SSO portal, and copy profile information.
#
# PARAMETERS:
#   None
#
# RETURNS:
#   0 - Success
#   1 - Failure (no profiles found or error)
#
_aws_sso_profile_list() {
    local profile_list
    local exit_code=0
    # Call the _cmd script to fetch and format SSO profiles
    profile_list="$(
        gum spin --title "Loading AWS SSO Profiles..." -- \
            "$_aws_sso_source_dir/aws_sso_cmd.sh" list
    )" || exit_code=$?

    if [ $exit_code -ne 0 ]; then
        gum log --level error "Failed to list SSO profiles (exit code: $exit_code)"
        gum log --level info "Check your AWS configuration"
        return 1
    fi

    # Check if any SSO profiles were found
    if [ -z "$profile_list" ]; then
        gum log --level warn "No SSO profiles found in ~/.aws/config"
        gum log --level info "SSO profiles must have 'sso_start_url' configured"
        return 1
    fi

    # Build fzf options with user-provided flags
    _aws_fzf_options "SSO_PROFILE"

    # Display in fzf with keybindings
    # Note: enter returns just the profile name (first column) for script usage
    echo "$profile_list" | fzf "${_fzf_options[@]}" \
        --with-nth 1.. --accept-nth 1 \
        --footer "$_fzf_icon SSO Profiles" \
        --preview "$_aws_sso_source_dir/aws_sso_cmd.sh preview" \
        --bind "ctrl-r:reload($_aws_sso_source_dir/aws_sso_cmd.sh list)" \
        --bind "ctrl-o:execute($_aws_sso_source_dir/aws_sso_cmd.sh open {1})+abort" \
        --bind "alt-enter:execute($_aws_sso_source_dir/aws_sso_cmd.sh login {1})+abort" \
        --bind "alt-n:execute-silent($_aws_sso_source_dir/aws_sso_cmd.sh copy-profile-name {1})" \
        --bind "alt-a:execute-silent($_aws_sso_source_dir/aws_sso_cmd.sh copy-account-id {1})" \
        --bind "alt-x:execute($_aws_sso_source_dir/aws_sso_cmd.sh logout {1})+reload($_aws_sso_source_dir/aws_sso_cmd.sh list)" \
        --bind "alt-h:toggle-preview" |
        awk '{print $1}'
}

# _aws_sso_help()
#
# Show SSO command help
#
_aws_sso_help() {
    cat <<'EOF'
aws fzf sso - Interactive SSO profile browser

USAGE:
    aws fzf sso profile list

DESCRIPTION:
    Browse and manage AWS SSO profiles from your ~/.aws/config file.
    Only profiles with 'sso_start_url' configured are displayed.

KEYBOARD SHORTCUTS:
    enter       Return selected profile name (default fzf behavior)
    alt-enter   Login to selected profile (opens browser for SSO, then exits fzf)
    ctrl-r      Reload the profile list
    ctrl-o      Open AWS console in browser and exit (bypasses account selection)
    alt-n       Copy profile name to clipboard
    alt-a       Copy account ID to clipboard
    alt-x       Logout from selected profile (then reload list)

PROFILE DISCOVERY:
    This command discovers SSO profiles by:
    1. Listing all profiles from AWS config
    2. Filtering profiles that have 'sso_start_url' configured
    3. Extracting profile metadata (account ID, role, region, SSO URL)

PROFILE FORMAT:
    Profiles are displayed with the following columns:
    - PROFILE: Profile name
    - ACCOUNT: AWS account ID
    - ROLE: SSO role name
    - REGION: AWS region
    - SSO_URL: SSO start URL

LOGIN BEHAVIOR:
    When you press alt-enter on a profile:
    1. AWS SSO login is initiated
    2. Your browser opens for authentication
    3. After successful login, fzf exits automatically

    When you press enter (without alt):
    - Returns the selected profile name to stdout
    - Useful for scripts and command substitution

LOGOUT BEHAVIOR:
    When you press alt-x on a profile:
    1. AWS SSO logout is executed
    2. Profile list reloads automatically
    3. fzf remains open

EXAMPLES:
    # Browse and select SSO profiles (returns profile name)
    aws fzf sso profile list

    # Use in scripts - select profile and export
    export AWS_PROFILE=$(aws fzf sso profile list)

    # Use with tmux popup to create new window with profile
    aws fzf --bind 'alt-enter:execute(tmux new-window -e AWS_PROFILE={1} -n {2}-{4})+abort' sso profile list

    # Use with tmux popup
    aws fzf --tmux sso profile list

    # Use with custom height
    aws fzf --height 50% sso profile list

CONFIGURATION:
    SSO profiles are read from ~/.aws/config. Any profile with
    'sso_start_url' configured is discovered automatically:

       [profile my-sso-profile]
       sso_start_url = https://my-org.awsapps.com/start
       sso_region = us-east-1
       sso_account_id = 123456789012
       sso_role_name = AdministratorAccess

ENVIRONMENT VARIABLES:
    AWS_CONFIG_FILE        Override AWS config file location
                           (default: ~/.aws/config)

SEE ALSO:
    AWS SSO Documentation: https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-sso.html
EOF
}

# aws_sso.sh - SSO profile browsing for aws fzf
#
# This file is sourced by the main aws fzf script and provides
# SSO profile listing with interactive functionality.
#
# Dependencies from main aws fzf:
#   - $_aws_fzf_source_dir (source directory path)
#   - aws CLI
#   - fzf
#   - gum
#

# _aws_sso_main()
#
# Handle SSO subcommands
#
# DESCRIPTION:
#   Routes SSO subcommands to appropriate handlers. Supports
#   profile list for interactive SSO profile browsing.
#
# PARAMETERS:
#   $1 - Resource type (profile)
#   $2 - Action (list)
#   $@ - Additional arguments
#
# RETURNS:
#   0 - Success
#   1 - Unknown subcommand or error
#
_aws_sso_main() {
    local resource="${1:-}"
    local action="${2:-}"

    case $resource in
    profile)
        case $action in
        list)
            shift 2
            _aws_sso_profile_list "$@"
            ;;
        --help | -h | help | "")
            _aws_sso_help
            ;;
        *)
            gum log --level error "Unknown SSO profile action '$action'"
            gum log --level info "Supported: list"
            gum log --level info "Run 'aws fzf sso --help' for usage"
            return 1
            ;;
        esac
        ;;
    --help | -h | help | "")
        _aws_sso_help
        ;;
    *)
        gum log --level error "Unknown SSO resource '$resource'"
        gum log --level info "Supported: profile"
        gum log --level info "Run 'aws fzf sso --help' for usage"
        return 1
        ;;
    esac
}

# ------------------------------------------------------------------------------
# Direct Execution Support
# ------------------------------------------------------------------------------
# When run directly (not sourced), pass all arguments to _aws_sso_main.
# This enables tmux integration and scripted usage.
# ------------------------------------------------------------------------------
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    _aws_sso_main "$@"
fi
