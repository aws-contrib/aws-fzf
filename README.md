# aws-fzf

An interactive terminal UI for AWS that lets you quickly discover, inspect, and manage resources using fuzzy search.

![License](https://img.shields.io/github/license/aws-contrib/aws-fzf)
![Version](https://img.shields.io/github/v/release/aws-contrib/aws-fzf)

## Prerequisites

- [AWS CLI](https://docs.aws.amazon.com/cli/) (`aws`)
- [Fzf](https://github.com/junegunn/fzf) (`fzf`) — macOS: `brew install fzf`
- [Jq](https://github.com/jqlang/jq) (`jq`) — macOS: `brew install jq`
- [Gum](https://github.com/charmbracelet/gum) (`gum`) — macOS: `brew install gum`

## Installation

```bash
git clone https://github.com/aws-contrib/aws-fzf.git
```

Add the following to `~/.aws/cli/alias`:

```ini
[toplevel]
fzf = !/path/to/aws-fzf/aws-fzf
```

Replace `/path/to/aws-fzf` with the actual clone location.

## Usage

```bash
aws fzf secret list              # browse secrets
aws fzf param list               # browse parameters
aws fzf lambda list              # browse Lambda functions
aws fzf s3 bucket list           # browse S3 buckets
aws fzf ecs cluster list         # browse ECS clusters
aws fzf rds instance list        # browse RDS instances
aws fzf dsql cluster list        # browse DSQL clusters
aws fzf dynamodb table list      # browse DynamoDB tables
aws fzf logs group list          # browse CloudWatch log groups
aws fzf sso profile list         # browse and login to SSO profiles
```

In every view, press `alt-h` to toggle the keyboard shortcut reference.

## Documentation

| Topic                                                   |                                                  |
| ------------------------------------------------------- | ------------------------------------------------ |
| [Configuration](docs/README.md#configuration)           | Profiles, regions, environment variables         |
| [Keyboard Shortcuts](docs/README.md#keyboard-shortcuts) | Common and service-specific keybindings          |
| [S3](docs/README.md#s3)                                 | Browse buckets and objects                       |
| [Parameter Store](docs/README.md#ssm-parameter-store)   | Browse and copy parameter values                 |
| [Secrets Manager](docs/README.md#secrets-manager)       | Browse and copy secret values                    |
| [ECS](docs/README.md#ecs)                               | Browse clusters, services, and tasks             |
| [Lambda](docs/README.md#lambda)                         | Browse functions and tail logs                   |
| [CloudWatch Logs](docs/README.md#cloudwatch-logs)       | Browse log groups, streams, and tail logs        |
| [RDS](docs/README.md#rds)                               | Browse instances and clusters, connect with psql |
| [DSQL](docs/README.md#dsql)                             | Browse clusters and connect with psql            |
| [DynamoDB](docs/README.md#dynamodb)                     | Browse tables and explore items                  |
| [SSO](docs/README.md#sso)                               | Browse profiles, login, and open console         |
| [Troubleshooting](docs/README.md#troubleshooting)       | Common issues and solutions                      |

## License

[MIT](LICENSE) — Copyright (c) 2025 aws-contrib

<!-- markdownlint-disable-file MD013 -->
