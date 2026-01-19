#!/usr/bin/env python3
"""
aws_sso.py - Fast AWS SSO profile parser

Parses ~/.aws/config to extract SSO profiles and their metadata.
Much faster than calling 'aws configure get' multiple times per profile.
Outputs JSON for consumption by jq (consistent with other aws-fzf commands).

Note: For JSON config support, use bash to cat the JSON file directly.
This script only handles AWS config file parsing.
"""

import configparser
import json
import os
import sys


def parse_sso_profiles(config_file=None):
    """
    Parse AWS config file and extract SSO profiles.

    Args:
        config_file: Path to AWS config file (defaults to ~/.aws/config)

    Returns:
        List of dicts containing SSO profile information
    """
    if config_file is None:
        config_file = os.path.expanduser(os.environ.get('AWS_CONFIG_FILE', '~/.aws/config'))

    if not os.path.exists(config_file):
        print(f"ERROR: AWS config file not found: {config_file}", file=sys.stderr)
        sys.exit(1)

    # Parse the config file
    config = configparser.ConfigParser()
    try:
        config.read(config_file)
    except Exception as e:
        print(f"ERROR: Failed to parse config file: {e}", file=sys.stderr)
        sys.exit(1)

    sso_profiles = []

    # Iterate through all sections
    for section in config.sections():
        # Extract profile name
        # Sections are either "default" or "profile <name>"
        if section == 'default':
            profile_name = 'default'
        elif section.startswith('profile '):
            profile_name = section[8:]  # Remove "profile " prefix
        else:
            continue

        # Check if this is an SSO profile (has sso_start_url)
        if 'sso_start_url' not in config[section]:
            continue

        # Extract SSO metadata (using exact AWS config field names)
        sso_profile = {
            'profile': profile_name,
            'sso_account_id': config[section].get('sso_account_id', None),
            'sso_role_name': config[section].get('sso_role_name', None),
            'sso_region': config[section].get('sso_region', None),
            'sso_start_url': config[section].get('sso_start_url', None),
        }

        sso_profiles.append(sso_profile)

    return sso_profiles


def main():
    """Main entry point."""
    # Parse SSO profiles from AWS config
    profiles = parse_sso_profiles()

    if not profiles:
        # Output empty JSON array for consistent handling
        print(json.dumps({"profiles": []}))
        sys.exit(0)

    # Output JSON with snake_case field names (matching AWS config conventions)
    output = {"profiles": profiles}
    print(json.dumps(output, indent=2))


if __name__ == '__main__':
    main()
