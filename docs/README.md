# aws-fzf Documentation

Complete guide for using aws-fzf, an interactive fuzzy finder for AWS resources.

## Table of Contents

- [Getting Started](#getting-started)
- [Configuration](#configuration)
- [Keyboard Shortcuts](#keyboard-shortcuts)
- [Services](#services)
  - [S3](#s3)
  - [SSM Parameter Store](#ssm-parameter-store)
  - [Secrets Manager](#secrets-manager)
  - [ECS](#ecs)
  - [Lambda](#lambda)
  - [CloudWatch Logs](#cloudwatch-logs)

---

## Getting Started

### Prerequisites

Install dependencies:

```bash
# macOS
brew install awscli fzf jq gum

# Linux
# See respective project documentation for installation
```

### Installation

Clone the repository:

```bash
git clone https://github.com/aws-contrib/aws-fzf.git
cd aws-fzf
```

Configure AWS CLI alias by creating or editing `~/.aws/cli/alias` file:

```ini
[toplevel]
fzf = !/path/to/github.com/aws-contrib/aws-fzf/aws-fzf
```

Replace `/path/to/github.com/aws-contrib/aws-fzf/aws-fzf` with the absolute path to your cloned `aws-fzf` script.

Make sure scripts are executable:

```bash
chmod +x aws-fzf
chmod +x scripts/*.sh
```

### Verify Installation

```bash
aws fzf --help
```

### Quick Start

```bash
# Browse S3 buckets
aws fzf s3 bucket list

# Browse parameters
aws fzf param list

# Browse secrets
aws fzf secret list

# Browse ECS clusters
aws fzf ecs cluster list

# Browse Lambda functions
aws fzf lambda list

# Browse CloudWatch log groups
aws fzf logs group list
```

---

## Configuration

aws-fzf uses your existing AWS CLI configuration.

### Using Default Credentials

```bash
# Default credentials and region
aws fzf s3 bucket list
```

### Using Specific Profile

```bash
# Use specific profile
aws fzf s3 bucket list --profile production

# Combine with region
aws fzf secret list --profile prod --region us-west-2
```

### Using Specific Region

```bash
# Use specific region
aws fzf s3 bucket list --region eu-west-1

# Works with any service
aws fzf logs group list --region us-west-2
```

### Passing AWS CLI Flags

All AWS CLI flags are supported and passed through to the underlying AWS commands:

```bash
# Parameters with pagination
aws fzf param list --max-results 50

# Secrets with filters
aws fzf secret list \
  --filters Key=name,Values=prod* \
  --max-results 100

# ECS with status filter
aws fzf ecs task list \
  --cluster my-cluster \
  --desired-status RUNNING

# S3 objects with prefix filter
aws fzf s3 object list \
  --bucket my-bucket \
  --prefix logs/2024/ \
  --max-items 5000
```

### Environment Variables

#### CloudWatch Logs Paging

Control how tail logs are displayed:

```bash
# Use lnav for interactive log viewing
export AWS_FZF_LOG_PAGER=lnav
aws fzf logs group list  # alt-t will pipe through lnav
```

---

## Keyboard Shortcuts

Complete reference of keyboard shortcuts across all services.

### S3

#### Buckets
| Key | Action |
|-----|--------|
| `ctrl-o` | Open bucket in AWS Console |
| `alt-enter` | List objects in bucket |

#### Objects
| Key | Action |
|-----|--------|
| `enter` | View object metadata |
| `ctrl-o` | Open object in AWS Console |

### SSM Parameter Store

| Key | Action |
|-----|--------|
| `enter` | Show parameter metadata (without value) |
| `ctrl-o` | Open parameter in AWS Console |
| `ctrl-v` | Get parameter value (prompts confirmation for SecureString) |

### Secrets Manager

| Key | Action |
|-----|--------|
| `enter` | Show secret metadata (without value) |
| `ctrl-o` | Open secret in AWS Console |
| `ctrl-v` | Get secret value (requires confirmation) |

### ECS

#### Clusters
| Key | Action |
|-----|--------|
| `ctrl-o` | Open cluster in AWS Console |
| `alt-enter` | List services in cluster |
| `ctrl-t` | List tasks in cluster |

#### Services
| Key | Action |
|-----|--------|
| `ctrl-o` | Open service in AWS Console |
| `ctrl-t` | List tasks for service |

#### Tasks
| Key | Action |
|-----|--------|
| `enter` | View task details |
| `ctrl-o` | Open task in AWS Console |

### Lambda

| Key | Action |
|-----|--------|
| `enter` | Show function configuration |
| `ctrl-o` | Open function in AWS Console |

### CloudWatch Logs

#### Log Groups
| Key | Action |
|-----|--------|
| `ctrl-o` | Open log group in AWS Console |
| `alt-t` | Tail all streams in log group |
| `alt-enter` | List streams in log group |

#### Log Streams
| Key | Action |
|-----|--------|
| `enter` | View stream metadata |
| `ctrl-o` | Open log stream in AWS Console |
| `alt-t` | Tail logs from this stream |

---

## Services

### S3

Browse S3 buckets and objects interactively.

#### Usage

**List Buckets**

```bash
# List all buckets
aws fzf s3 bucket list

# With specific region
aws fzf s3 bucket list --region us-west-2
```

**List Objects**

```bash
# List objects in a bucket
aws fzf s3 object list --bucket my-bucket

# With prefix filter (recommended for large buckets)
aws fzf s3 object list --bucket my-bucket --prefix logs/

# With prefix and pagination
aws fzf s3 object list --bucket my-bucket --prefix logs/2024/ --max-items 5000
```

#### Keyboard Shortcuts

**Buckets:**
- `ctrl-o` - Open bucket in AWS Console
- `alt-enter` - List objects in bucket

**Objects:**
- `enter` - View object metadata
- `ctrl-o` - Open object in AWS Console

#### Tips

- Use `--prefix` for large buckets to narrow results
- Use `--max-items` to control pagination
- Press `alt-enter` on a bucket to drill down into objects

---

### SSM Parameter Store

Browse SSM parameters interactively.

#### Usage

```bash
# List parameters
aws fzf param list

# With specific region
aws fzf param list --region us-west-2

# With pagination
aws fzf param list --max-results 100

# With specific profile
aws fzf param list --profile production
```

#### Keyboard Shortcuts

- `enter` - Show parameter metadata (without value)
- `ctrl-o` - Open parameter in AWS Console
- `ctrl-v` - Get parameter value (prompts confirmation for SecureString)

#### Security

`SecureString` parameters require confirmation before decryption. This prevents accidental exposure of sensitive values.

#### Tips

- Use `--max-results` to control pagination for large parameter sets
- Press `ctrl-v` only when you need to see the actual value
- Use `--profile` to switch between different AWS accounts

---

### Secrets Manager

Browse secrets interactively.

#### Usage

```bash
# List secrets
aws fzf secret list

# With specific region
aws fzf secret list --region us-west-2

# With specific profile
aws fzf secret list --profile production

# With filters
aws fzf secret list --filters Key=name,Values=prod*
```

#### Keyboard Shortcuts

- `enter` - Show secret metadata (without value)
- `ctrl-o` - Open secret in AWS Console
- `ctrl-v` - Get secret value (requires confirmation)

#### Security

All secret values require confirmation before retrieval. This prevents accidental exposure of sensitive information.

#### Tips

- Use `--filters` to narrow down secrets by name or other attributes
- Press `ctrl-v` only when you need to see the actual secret value
- Use `--profile` to switch between different AWS accounts

---

### ECS

Browse ECS clusters, services, and tasks interactively.

#### Usage

**List Clusters**

```bash
# List all clusters
aws fzf ecs cluster list

# With specific region
aws fzf ecs cluster list --region us-west-2
```

**List Services**

```bash
# List services in a cluster
aws fzf ecs service list --cluster my-cluster
```

**List Tasks**

```bash
# List all tasks in a cluster
aws fzf ecs task list --cluster my-cluster

# Filter by status
aws fzf ecs task list --cluster my-cluster --desired-status RUNNING
```

#### Keyboard Shortcuts

**Clusters:**
- `ctrl-o` - Open cluster in AWS Console
- `alt-enter` - List services in cluster
- `ctrl-t` - List tasks in cluster

**Services:**
- `ctrl-o` - Open service in AWS Console
- `ctrl-t` - List tasks for service

**Tasks:**
- `enter` - View task details
- `ctrl-o` - Open task in AWS Console

#### Tips

- Use `alt-enter` on a cluster to drill down into services
- Use `ctrl-t` to quickly view tasks
- Filter tasks by `--desired-status` to see only running or stopped tasks

---

### Lambda

Browse Lambda functions interactively.

#### Usage

```bash
# List functions
aws fzf lambda list

# With specific region
aws fzf lambda list --region us-west-2

# With specific profile
aws fzf lambda list --profile production
```

#### Keyboard Shortcuts

- `enter` - Show function configuration
- `ctrl-o` - Open function in AWS Console

#### Tips

- Press `enter` to view function details including runtime, memory, timeout, and environment variables
- Use `ctrl-o` to open in AWS Console for more detailed configuration or to view logs
- Use `--region` to list functions in different AWS regions

---

### CloudWatch Logs

Browse CloudWatch log groups and streams interactively.

#### Usage

**List Log Groups**

```bash
# List all log groups
aws fzf logs group list

# With specific region
aws fzf logs group list --region us-west-2

# With prefix filter
aws fzf logs group list --log-group-name-prefix /aws/lambda
```

**List Log Streams**

```bash
# List streams in a log group
aws fzf logs stream list --log-group-name /aws/lambda/my-function
```

#### Keyboard Shortcuts

**Log Groups:**
- `ctrl-o` - Open log group in AWS Console
- `alt-t` - Tail all streams in log group
- `alt-enter` - List streams in log group

**Log Streams:**
- `enter` - View stream metadata
- `ctrl-o` - Open log stream in AWS Console
- `alt-t` - Tail logs from this stream

#### Log Tailing

Tail logs in real-time using `alt-t`:

```bash
# Set lnav as your log pager (optional)
export AWS_FZF_LOG_PAGER=lnav

# Then press alt-t on any log group or stream to tail logs
```

If `AWS_FZF_LOG_PAGER` is set to `lnav`, logs will be piped through lnav for interactive viewing. Otherwise, logs are displayed directly in the terminal.

#### Tips

- Use `--log-group-name-prefix` to filter log groups (e.g., `/aws/lambda` for all Lambda function logs)
- Press `alt-enter` on a log group to drill down into streams
- Press `alt-t` to tail logs in real-time
- Use `lnav` as a pager for better log viewing experience (install with `brew install lnav`)
