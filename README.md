# aws-fzf

Interactive fuzzy finder built with [fzf](https://github.com/junegunn/fzf) for
lightning-fast fuzzy searching of AWS resources and
[gum](https://github.com/charmbracelet/gum) for beautiful terminal UI.

## Features

- **Interactive Browsing**: Fuzzy search through AWS resources with keyboard shortcuts
- **Full AWS Integration**: Pass any AWS CLI flags (`--region`, `--profile`,
  `filters`, etc.)
- **Supported AWS Services**: `S3`, `SSM`, `Secret Manager`, `ECS`, `Lambda`,
  `CloudWatch`

## Installation

### Prerequisites

Install dependencies:

```bash
# macOS
brew install awscli fzf jq gum

# Linux
# See respective project documentation for installation
```

Clone the repository:

```bash
git clone https://github.com/aws-contrib/aws-fzf.git
cd aws-fzf
```

Configure AWS CLI alias:

Create or edit `~/.aws/cli/alias` file with the following content:

```ini
[toplevel]
fzf = !/path/to/github.com/aws-contrib/aws-fzf/aws-fzf
```

Replace `/path/to/github.com/aws-contrib/aws-fzf/aws-fzf` with the absolute
path to your cloned `aws-fzf` script.

Make sure that scripts is executable:

```bash
chmod +x aws-fzf
chmod +x scripts/*.sh
```

### Verify Installation

```bash
aws fzf --help
```

## Quick Start

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

## Usage

### AWS S3

Browse `S3` buckets and objects interactively:

```bash
# List buckets
aws fzf s3 bucket list
aws fzf s3 bucket list --region us-west-2

# List objects in a bucket
aws fzf s3 object list --bucket my-bucket

# With prefix filter (recommended for large buckets)
aws fzf s3 object list --bucket my-bucket --prefix logs/
aws fzf s3 object list --bucket my-bucket --prefix logs/2024/ --max-items 5000
```

**Keyboard Shortcuts (Buckets):**

- `ctrl-o` - Open bucket in AWS Console
- `alt-enter` - List objects in bucket

**Keyboard Shortcuts (Objects):**

- `enter` - View object metadata
- `ctrl-o` - Open object in AWS Console

### AWS Parameter Store

Browse `SSM` parameters interactively:

```bash
# List parameters
aws fzf param list

# With AWS CLI options
aws fzf param list --region us-west-2
aws fzf param list --max-results 100
aws fzf param list --profile production
```

**Keyboard Shortcuts:**

- `enter` - Show parameter metadata (without value)
- `ctrl-o` - Open parameter in AWS Console
- `ctrl-v` - Get parameter value (prompts confirmation `SecureString`)

**Security:** `SecureString` parameters require confirmation before decryption.

### AWS Secrets Manager

Browse secrets interactively:

```bash
# List secrets
aws fzf secret list

# With AWS CLI options
aws fzf secret list --region us-west-2
aws fzf secret list --profile production
aws fzf secret list --filters Key=name,Values=prod*
```

**Keyboard Shortcuts:**

- `enter` - Show secret metadata (without value)
- `ctrl-o` - Open secret in AWS Console
- `ctrl-v` - Get secret value (requires confirmation)

**Security:** All secret values require confirmation before retrieval.

### AWS Elastic Container Services

Browse `ECS` clusters, services, and tasks:

```bash
# List clusters
aws fzf ecs cluster list
aws fzf ecs cluster list --region us-west-2

# List services in a cluster
aws fzf ecs service list --cluster my-cluster

# List tasks in a cluster
aws fzf ecs task list --cluster my-cluster
aws fzf ecs task list --cluster my-cluster --desired-status RUNNING
```

**Keyboard Shortcuts (Clusters):**

- `ctrl-o` - Open cluster in AWS Console
- `alt-enter` - List services in cluster
- `ctrl-t` - List tasks in cluster

**Keyboard Shortcuts (Services):**

- `ctrl-o` - Open service in AWS Console
- `ctrl-t` - List tasks for service

**Keyboard Shortcuts (Tasks):**

- `enter` - View task details
- `ctrl-o` - Open task in AWS Console

### Lambda

Browse Lambda functions:

```bash
# List functions
aws fzf lambda list

# With AWS CLI options
aws fzf lambda list --region us-west-2
aws fzf lambda list --profile production
```

**Keyboard Shortcuts:**

- `enter` - Show function configuration
- `ctrl-o` - Open function in AWS Console

### AWS CloudWatch Logs

Browse `CloudWatch` log groups and streams:

```bash
# List log groups
aws fzf logs group list
aws fzf logs group list --region us-west-2
aws fzf logs group list --log-group-name-prefix /aws/lambda

# List streams in a log group
aws fzf logs stream list --log-group-name /aws/lambda/my-function
```

**Keyboard Shortcuts (Log Groups):**

- `ctrl-o` - Open log group in AWS Console
- `alt-enter` - List streams in log group

**Keyboard Shortcuts (Log Streams):**

- `enter` - View stream metadata
- `ctrl-o` - Open log stream in AWS Console
- `ctrl-t` - Tail logs (opens in AWS Console)

## Configuration

It uses your existing AWS CLI configuration:

```bash
# Default credentials and region
aws fzf s3 bucket list

# Use specific profile
aws fzf s3 bucket list --profile production

# Use specific region
aws fzf s3 bucket list --region eu-west-1

# Combine options
aws fzf secret list --profile prod --region us-west-2
```

## Advanced Usage

### Passing AWS CLI Flags

All AWS CLI flags are supported:

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

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

See [LICENSE](LICENSE) file for details.
