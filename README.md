# aws-fzf

An interactive terminal UI for AWS that lets you quickly discover, inspect, and manage resources using fuzzy search.

![License](https://img.shields.io/github/license/aws-contrib/aws-fzf)
![Version](https://img.shields.io/github/v/release/aws-contrib/aws-fzf)

## Prerequisites

- [AWS CLI](https://docs.aws.amazon.com/cli/) (`aws`) — macOS: `brew install awscli`
- [Bash](https://www.gnu.org/software/bash/) 4.4+ (`bash`) — macOS: `brew install bash`
- [Fzf](https://github.com/junegunn/fzf) (`fzf >= 0.58.0`) — macOS: `brew install fzf`
- [Jq](https://github.com/jqlang/jq) (`jq`) — macOS: `brew install jq`
- [Gum](https://github.com/charmbracelet/gum) (`gum`) — macOS: `brew install gum`

## Installation

```bash
git clone https://github.com/aws-contrib/aws-fzf.git
```

Add the following to `~/.aws/cli/alias` (create the file if it doesn't exist):

```ini
[toplevel]
fzf = !/path/to/aws-fzf/aws-fzf
```

Replace `/path/to/aws-fzf` with the absolute path to your cloned repository.

## Usage

```bash
aws fzf secret list              # browse Secrets Manager secrets
aws fzf param list               # browse SSM Parameter Store
aws fzf lambda list              # browse Lambda functions
aws fzf logs group list          # browse CloudWatch log groups
aws fzf ecs cluster list         # browse ECS clusters
aws fzf s3 bucket list           # browse S3 buckets
aws fzf rds instance list        # browse RDS instances
aws fzf rds cluster list         # browse Aurora clusters
aws fzf dsql cluster list        # browse Aurora DSQL clusters
aws fzf dynamodb table list      # browse DynamoDB tables
aws fzf sso profile list         # browse and login to SSO profiles
```

In every view, press `alt-h` to toggle the keyboard shortcut reference.

## Secrets Manager

```bash
aws fzf secret list
aws fzf secret list --region eu-west-1
aws fzf secret list --filters Key=name,Values=prod*
```

| Key | Action |
|-----|--------|
| `enter` | Show secret metadata |
| `ctrl-o` | Open in AWS Console |
| `alt-v` | Copy secret value to clipboard |
| `alt-a` | Copy ARN to clipboard |
| `alt-n` | Copy name to clipboard |
| `alt-h` | Toggle help |

## Parameter Store

```bash
aws fzf param list
aws fzf param list --region eu-west-1
aws fzf param list --max-results 100
```

| Key | Action |
|-----|--------|
| `enter` | Show parameter metadata |
| `ctrl-o` | Open in AWS Console |
| `alt-v` | Copy parameter value to clipboard |
| `alt-a` | Copy ARN to clipboard |
| `alt-n` | Copy name to clipboard |
| `alt-h` | Toggle help |

## Lambda

```bash
aws fzf lambda list
aws fzf lambda list --region us-west-2
```

| Key | Action |
|-----|--------|
| `enter` | Show function configuration |
| `ctrl-o` | Open in AWS Console |
| `alt-t` | Tail function logs in real-time |
| `alt-a` | Copy ARN to clipboard |
| `alt-n` | Copy name to clipboard |
| `alt-h` | Toggle help |

## CloudWatch Logs

```bash
aws fzf logs group list
aws fzf logs group list --log-group-name-prefix /aws/lambda
aws fzf logs stream list --log-group-name /aws/lambda/my-function
```

**Log Groups**

| Key | Action |
|-----|--------|
| `ctrl-o` | Open in AWS Console |
| `alt-t` | Tail all streams in group |
| `alt-l` | Read historical logs |
| `alt-enter` | List streams in group |
| `alt-a` | Copy ARN to clipboard |
| `alt-n` | Copy name to clipboard |
| `alt-h` | Toggle help |

**Log Streams**

| Key | Action |
|-----|--------|
| `enter` | View stream metadata |
| `ctrl-o` | Open in AWS Console |
| `alt-t` | Tail logs from stream |
| `alt-l` | Read historical logs from stream |
| `alt-a` | Copy ARN to clipboard |
| `alt-n` | Copy name to clipboard |

## ECS

```bash
aws fzf ecs cluster list
aws fzf ecs service list --cluster my-cluster
aws fzf ecs task list --cluster my-cluster --desired-status RUNNING
```

**Clusters**

| Key | Action |
|-----|--------|
| `ctrl-o` | Open in AWS Console |
| `alt-enter` | List services in cluster |
| `alt-a` | Copy ARN to clipboard |
| `alt-n` | Copy name to clipboard |
| `alt-h` | Toggle help |

**Services**

| Key | Action |
|-----|--------|
| `ctrl-o` | Open in AWS Console |
| `alt-enter` | List tasks for service |
| `alt-a` | Copy ARN to clipboard |
| `alt-n` | Copy name to clipboard |

**Tasks**

| Key | Action |
|-----|--------|
| `enter` | View task details |
| `ctrl-o` | Open in AWS Console |
| `alt-a` | Copy ARN to clipboard |

## S3

```bash
aws fzf s3 bucket list
aws fzf s3 object list --bucket my-bucket
aws fzf s3 object list --bucket my-bucket --prefix logs/2024/ --max-items 5000
```

**Buckets**

| Key | Action |
|-----|--------|
| `ctrl-o` | Open in AWS Console |
| `alt-enter` | List objects in bucket |
| `alt-a` | Copy ARN to clipboard |
| `alt-n` | Copy name to clipboard |
| `alt-h` | Toggle help |

**Objects**

| Key | Action |
|-----|--------|
| `enter` | View object metadata |
| `ctrl-o` | Open in AWS Console |
| `alt-a` | Copy ARN to clipboard |
| `alt-n` | Copy key to clipboard |

## RDS

```bash
aws fzf rds instance list
aws fzf rds cluster list
aws fzf rds instance list --region us-west-2
```

**DB Instances**

| Key | Action |
|-----|--------|
| `enter` | View instance details |
| `ctrl-o` | Open in AWS Console |
| `alt-c` | Connect with psql (IAM auth, PostgreSQL only) |
| `alt-a` | Copy ARN to clipboard |
| `alt-n` | Copy identifier to clipboard |
| `alt-h` | Toggle help |

**DB Clusters (Aurora)**

| Key | Action |
|-----|--------|
| `enter` | View cluster details |
| `ctrl-o` | Open in AWS Console |
| `alt-c` | Connect with psql (IAM auth, PostgreSQL only) |
| `alt-a` | Copy ARN to clipboard |
| `alt-n` | Copy identifier to clipboard |

> `alt-c` requires IAM database authentication enabled on the instance and `psql` installed.
> A temporary 15-minute auth token is generated automatically.

## Aurora DSQL

```bash
aws fzf dsql cluster list
aws fzf dsql cluster list --region us-east-1
```

| Key | Action |
|-----|--------|
| `enter` | View cluster details |
| `ctrl-o` | Open in AWS Console |
| `alt-c` | Connect with psql (IAM auth) |
| `alt-a` | Copy ARN to clipboard |
| `alt-n` | Copy identifier to clipboard |
| `alt-h` | Toggle help |

> `alt-c` requires `psql` installed. A 1-hour auth token is generated automatically.
> IAM authentication is always enabled on DSQL — no extra setup required.

## DynamoDB

```bash
aws fzf dynamodb table list
aws fzf dynamodb table list --region us-east-1
```

| Key | Action |
|-----|--------|
| `enter` | View table details (schema, indexes, throughput) |
| `ctrl-o` | Open table overview in AWS Console |
| `alt-enter` | Open item explorer in AWS Console |
| `alt-a` | Copy ARN to clipboard |
| `alt-n` | Copy name to clipboard |
| `alt-h` | Toggle help |

## SSO

```bash
aws fzf sso profile list
```

SSO profiles are discovered automatically from any profile in `~/.aws/config`
that has `sso_start_url` set.

| Key | Action |
|-----|--------|
| `enter` | Return profile name to stdout |
| `alt-enter` | Login (opens browser for SSO authentication) |
| `ctrl-r` | Reload profile list |
| `ctrl-o` | Open AWS Console |
| `alt-n` | Copy profile name to clipboard |
| `alt-a` | Copy account ID to clipboard |
| `alt-x` | Logout from profile |
| `alt-h` | Toggle help |

```bash
# Use the selected profile in a downstream command
AWS_PROFILE=$(aws fzf sso profile list) aws s3 ls
```

## Configuration

### AWS profile and region

All AWS CLI flags are passed through to the underlying commands:

```bash
aws fzf secret list --profile production --region us-west-2
```

### Custom fzf options

Per-command variables take precedence over the global one.

| Variable | Scope |
|----------|-------|
| `FZF_AWS_FLAGS` | Applied to all views |
| `FZF_AWS_SECRET_OPTS` | Secrets Manager |
| `FZF_AWS_PARAM_OPTS` | Parameter Store |
| `FZF_AWS_LAMBDA_OPTS` | Lambda |
| `FZF_AWS_S3_BUCKET_OPTS` | S3 buckets |
| `FZF_AWS_S3_OBJECT_OPTS` | S3 objects |
| `FZF_AWS_ECS_CLUSTER_OPTS` | ECS clusters |
| `FZF_AWS_ECS_SERVICE_OPTS` | ECS services |
| `FZF_AWS_ECS_TASK_OPTS` | ECS tasks |
| `FZF_AWS_LOGS_GROUP_OPTS` | CloudWatch log groups |
| `FZF_AWS_LOGS_STREAM_OPTS` | CloudWatch log streams |
| `FZF_AWS_RDS_INSTANCE_OPTS` | RDS instances |
| `FZF_AWS_RDS_CLUSTER_OPTS` | RDS clusters |
| `FZF_AWS_DSQL_CLUSTER_OPTS` | DSQL clusters |
| `FZF_AWS_DYNAMODB_TABLE_OPTS` | DynamoDB tables |
| `FZF_AWS_SSO_PROFILE_OPTS` | SSO profiles |

```bash
export FZF_AWS_SECRET_OPTS="--height 50% --border rounded"
export FZF_AWS_S3_BUCKET_OPTS="--height 90%"
```

### Service-specific variables

| Variable | Description | Default |
|----------|-------------|---------|
| `FZF_AWS_LOG_HISTORY` | Duration to look back for log reads | `1h` |
| `FZF_AWS_LOG_LIMIT` | Max log events returned | `10000` |
| `FZF_AWS_LOG_MAX_ITEMS` | Max log streams to list | `1000` |
| `FZF_AWS_S3_MAX_ITEMS` | Max S3 objects to list per bucket | `1000` |
| `FZF_AWS_DSQL_TOKEN_TTL` | DSQL auth token TTL in seconds | `3600` |

### Debug mode

```bash
DEBUG=1 aws fzf secret list
```

## License

[MIT](LICENSE) — Copyright (c) 2025 aws-contrib

<!-- markdownlint-disable-file MD013 -->
