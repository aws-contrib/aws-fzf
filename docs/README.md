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
  - [RDS](#rds)
  - [DSQL](#dsql)
  - [DynamoDB](#dynamodb)
- [Troubleshooting](#troubleshooting)

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

# Browse RDS instances
aws fzf rds instance list

# Browse RDS Aurora clusters
aws fzf rds cluster list
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

---

## Keyboard Shortcuts

Complete reference of keyboard shortcuts across all services.

### Common Keybindings

These keybindings are available across all services:

| Key      | Action                                        |
| -------- | --------------------------------------------- |
| `enter`  | View resource details (full JSON or metadata) |
| `ctrl-o` | Open resource in AWS Console                  |
| `alt-a`  | Copy resource ARN to clipboard                |
| `alt-n`  | Copy resource name/identifier to clipboard    |

Additional service-specific keybindings are documented below.

### S3

#### Buckets

| Key         | Action                        |
| ----------- | ----------------------------- |
| `ctrl-o`    | Open bucket in AWS Console    |
| `alt-enter` | List objects                  |
| `alt-a`     | Copy bucket ARN to clipboard  |
| `alt-n`     | Copy bucket name to clipboard |

#### Objects

| Key      | Action                       |
| -------- | ---------------------------- |
| `enter`  | View object metadata         |
| `ctrl-o` | Open object in AWS Console   |
| `alt-a`  | Copy object ARN to clipboard |
| `alt-n`  | Copy object key to clipboard |

### SSM Parameter Store

| Key      | Action                                  |
| -------- | --------------------------------------- |
| `enter`  | Show parameter metadata (without value) |
| `ctrl-o` | Open parameter in AWS Console           |
| `alt-v`  | Copy parameter value to clipboard       |
| `alt-a`  | Copy parameter ARN to clipboard         |
| `alt-n`  | Copy parameter name to clipboard        |

### Secrets Manager

| Key      | Action                               |
| -------- | ------------------------------------ |
| `enter`  | Show secret metadata (without value) |
| `ctrl-o` | Open secret in AWS Console           |
| `alt-v`  | Copy secret value to clipboard       |
| `alt-a`  | Copy secret ARN to clipboard         |
| `alt-n`  | Copy secret name to clipboard        |

### ECS

#### Clusters

| Key         | Action                         |
| ----------- | ------------------------------ |
| `ctrl-o`    | Open cluster in AWS Console    |
| `alt-enter` | List services in cluster       |
| `alt-a`     | Copy cluster ARN to clipboard  |
| `alt-n`     | Copy cluster name to clipboard |

#### Services

| Key         | Action                         |
| ----------- | ------------------------------ |
| `ctrl-o`    | Open service in AWS Console    |
| `alt-enter` | List tasks for service         |
| `alt-a`     | Copy service ARN to clipboard  |
| `alt-n`     | Copy service name to clipboard |

#### Tasks

| Key      | Action                     |
| -------- | -------------------------- |
| `enter`  | View task details          |
| `ctrl-o` | Open task in AWS Console   |
| `alt-a`  | Copy task ARN to clipboard |

### Lambda

| Key      | Action                          |
| -------- | ------------------------------- |
| `enter`  | Show function configuration     |
| `ctrl-o` | Open function in AWS Console    |
| `alt-t`  | Tail function logs in real-time |
| `alt-a`  | Copy function ARN to clipboard  |
| `alt-n`  | Copy function name to clipboard |

### CloudWatch Logs

#### Log Groups

| Key         | Action                           |
| ----------- | -------------------------------- |
| `ctrl-o`    | Open log group in AWS Console    |
| `alt-t`     | Tail all streams in log group    |
| `alt-enter` | List streams in log group        |
| `alt-a`     | Copy log group ARN to clipboard  |
| `alt-n`     | Copy log group name to clipboard |

#### Log Streams

| Key      | Action                            |
| -------- | --------------------------------- |
| `enter`  | View stream metadata              |
| `ctrl-o` | Open log stream in AWS Console    |
| `alt-t`  | Tail logs from this stream        |
| `alt-a`  | Copy log stream ARN to clipboard  |
| `alt-n`  | Copy log stream name to clipboard |

### RDS

#### DB Instances

| Key      | Action                                                 |
| -------- | ------------------------------------------------------ |
| `enter`  | View instance details (full JSON)                      |
| `ctrl-o` | Open instance in AWS Console                           |
| `alt-c`  | Connect with psql (PostgreSQL only, IAM auth required) |
| `alt-a`  | Copy instance ARN to clipboard                         |
| `alt-n`  | Copy instance identifier to clipboard                  |

#### DB Clusters (Aurora)

| Key      | Action                                                 |
| -------- | ------------------------------------------------------ |
| `enter`  | View cluster details (full JSON)                       |
| `ctrl-o` | Open cluster in AWS Console                            |
| `alt-c`  | Connect with psql (PostgreSQL only, IAM auth required) |
| `alt-a`  | Copy cluster ARN to clipboard                          |
| `alt-n`  | Copy cluster identifier to clipboard                   |

### DSQL

#### Clusters

| Key      | Action                               |
| -------- | ------------------------------------ |
| `enter`  | View cluster details (full JSON)     |
| `ctrl-o` | Open cluster in AWS Console          |
| `alt-c`  | Connect with psql (IAM auth)         |
| `alt-a`  | Copy cluster ARN to clipboard        |
| `alt-n`  | Copy cluster identifier to clipboard |

### DynamoDB

#### Tables

| Key         | Action                               |
| ----------- | ------------------------------------ |
| `enter`     | View table details (full JSON)       |
| `ctrl-o`    | Open table in AWS Console (overview) |
| `alt-enter` | Open items explorer in AWS Console   |
| `alt-a`     | Copy table ARN to clipboard          |
| `alt-n`     | Copy table name to clipboard         |

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
- `alt-a` - Copy bucket ARN to clipboard
- `alt-n` - Copy bucket name to clipboard

**Objects:**

- `enter` - View object metadata
- `ctrl-o` - Open object in AWS Console
- `alt-a` - Copy object ARN to clipboard
- `alt-n` - Copy object key to clipboard

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
- `alt-v` - Copy parameter value to clipboard
- `alt-a` - Copy parameter ARN to clipboard
- `alt-n` - Copy parameter name to clipboard

#### Tips

- Use `--max-results` to control pagination for large parameter sets
- Press `alt-v` only when you need to copy the actual value to clipboard
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
- `alt-v` - Copy secret value to clipboard
- `alt-a` - Copy secret ARN to clipboard
- `alt-n` - Copy secret name to clipboard

#### Tips

- Use `--filters` to narrow down secrets by name or other attributes
- Press `alt-v` only when you need to copy the actual secret value to clipboard
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
- `alt-a` - Copy cluster ARN to clipboard
- `alt-n` - Copy cluster name to clipboard

**Services:**

- `ctrl-o` - Open service in AWS Console
- `alt-enter` - List tasks for service
- `alt-a` - Copy service ARN to clipboard
- `alt-n` - Copy service name to clipboard

**Tasks:**

- `enter` - View task details
- `ctrl-o` - Open task in AWS Console
- `alt-a` - Copy task ARN to clipboard

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
- `alt-t` - Tail function logs in real-time
- `alt-a` - Copy function ARN to clipboard
- `alt-n` - Copy function name to clipboard

#### Tips

- Press `enter` to view function details including runtime, memory, timeout, and environment variables
- Use `ctrl-o` to open in AWS Console for more detailed configuration or to view logs
- Press `alt-t` to tail CloudWatch logs for this function in real-time
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
- `alt-a` - Copy log group ARN to clipboard
- `alt-n` - Copy log group name to clipboard

**Log Streams:**

- `enter` - View stream metadata
- `ctrl-o` - Open log stream in AWS Console
- `alt-t` - Tail logs from this stream
- `alt-a` - Copy log stream ARN to clipboard
- `alt-n` - Copy log stream name to clipboard






#### Tips

- Use `--log-group-name-prefix` to filter log groups (e.g., `/aws/lambda` for all Lambda function logs)
- Press `alt-enter` on a log group to drill down into streams
- Press `alt-t` to tail logs in real-time


---

### RDS

Browse RDS database instances and Aurora clusters interactively.

#### Usage

**List DB Instances**

```bash
# List all RDS instances
aws fzf rds instance list

# With specific region
aws fzf rds instance list --region us-west-2

# With specific profile
aws fzf rds instance list --profile production
```

**List DB Clusters (Aurora)**

```bash
# List all Aurora clusters
aws fzf rds cluster list

# With specific region
aws fzf rds cluster list --region us-west-2

# With specific profile
aws fzf rds cluster list --profile production
```

#### Keyboard Shortcuts

**DB Instances:**

- `enter` - View instance details (full JSON)
- `ctrl-o` - Open instance in AWS Console
- `alt-c` - Connect with psql (PostgreSQL only, IAM auth required)
- `alt-a` - Copy instance ARN to clipboard
- `alt-n` - Copy instance identifier to clipboard

**DB Clusters:**

- `enter` - View cluster details (full JSON)
- `ctrl-o` - Open cluster in AWS Console
- `alt-c` - Connect with psql (PostgreSQL only, IAM auth required)
- `alt-a` - Copy cluster ARN to clipboard
- `alt-n` - Copy cluster identifier to clipboard

#### Instance Information

When listing instances, you'll see:

- **ID** - Database instance identifier
- **ENGINE** - Database engine (postgres, mysql, mariadb, oracle, sqlserver, aurora)
- **STATUS** - Current status (available, creating, deleting, etc.)
- **CLASS** - Instance class (db.t3.micro, db.m5.large, etc.)

#### Cluster Information

When listing clusters, you'll see:

- **ID** - Database cluster identifier
- **ENGINE** - Aurora engine (aurora, aurora-mysql, aurora-postgresql)
- **STATUS** - Current status (available, creating, etc.)
- **MEMBERS** - Number of instances in the cluster

#### Tips

- Press `enter` to view full database configuration including endpoints, ports, storage, and security settings
- Use `ctrl-o` to open in AWS Console for detailed configuration or to view metrics
- Use `--region` to list databases in different AWS regions
- RDS instances and Aurora clusters are shown separately - use the appropriate command for your database type

#### Connecting to Databases

Press `alt-c` to connect to a PostgreSQL database using IAM authentication:

**Requirements:**

- PostgreSQL database engine (postgres or aurora-postgresql)
- IAM database authentication enabled on the instance/cluster
- `psql` client installed (`brew install postgresql`)
- Proper IAM permissions to generate auth tokens

**IAM Permissions Required:**

```json
{
  "Effect": "Allow",
  "Action": "rds-db:connect",
  "Resource": "arn:aws:rds-db:region:account:dbuser:resource-id/username"
}
```

**Enable IAM Authentication:**

- For existing instances: Modify instance and enable IAM authentication
- For new instances: Enable during creation
- Creates temporary 15-minute auth tokens

**Connection Flow:**

1. Press `alt-c` on a database
2. Tool fetches instance details
3. Generates IAM auth token (valid for 15 minutes)
4. Launches psql with connection parameters
5. Connected to postgres database as master user

---

### DSQL

Browse Amazon Aurora DSQL clusters interactively.

#### Usage

**List Clusters**

```bash
# List all DSQL clusters
aws fzf dsql cluster list

# With specific region
aws fzf dsql cluster list --region us-west-2

# With specific profile
aws fzf dsql cluster list --profile production
```

#### Keyboard Shortcuts

- `enter` - Show cluster details (full JSON)
- `ctrl-o` - Open cluster in AWS Console
- `alt-c` - Connect to cluster with psql
- `alt-a` - Copy cluster ARN to clipboard
- `alt-n` - Copy cluster identifier to clipboard

#### Connecting to Clusters

Press `alt-c` to connect to a DSQL cluster using IAM authentication:

**Requirements:**

- `psql` client installed (`brew install postgresql`)
- Proper IAM permissions to generate DSQL auth tokens

**IAM Permissions Required:**

```json
{
  "Effect": "Allow",
  "Action": "dsql:DbConnect",
  "Resource": "arn:aws:dsql:region:account:cluster/cluster-id"
}
```

**Connection Flow:**

1. Press `alt-c` on a cluster
2. Tool fetches cluster endpoint
3. Generates IAM auth token (valid for 1 hour)
4. Launches psql with connection parameters
5. Connected as `admin` user to `postgres` database

**Tips:**

- DSQL is always PostgreSQL-compatible
- IAM authentication is always enabled
- Default username is `admin`
- Auth tokens are valid for 1 hour (vs 15 minutes for RDS)
- No need to enable IAM auth - it's built-in

---

### DynamoDB

Browse Amazon DynamoDB tables interactively.

#### Usage

**List Tables**

```bash
# List all DynamoDB tables
aws fzf dynamodb table list

# With specific region
aws fzf dynamodb table list --region us-west-2

# With specific profile
aws fzf dynamodb table list --profile production
```

#### Keyboard Shortcuts

- `enter` - Show table details (full JSON including schema, provisioned throughput, indexes)
- `ctrl-o` - Open table overview in AWS Console (shows schema, indexes, metrics)
- `alt-enter` - Open items explorer in AWS Console (browse and query table data)
- `alt-a` - Copy table ARN to clipboard
- `alt-n` - Copy table name to clipboard

#### Table Information

When viewing table details with `enter`, you'll see:

- **Table name and ARN**
- **Key schema** (partition key and sort key)
- **Attribute definitions**
- **Table status** (ACTIVE, CREATING, UPDATING, DELETING)
- **Item count** and **table size**
- **Provisioned throughput** (read/write capacity units)
- **Global secondary indexes** (GSIs)
- **Local secondary indexes** (LSIs)
- **Stream settings** (if enabled)
- **Encryption settings**
- **Tags**

#### Tips

- Tables are listed by name only for fast performance
- Press `enter` to see full table details on demand
- Press `ctrl-o` to view table configuration (indexes, capacity, streams)
- Press `alt-enter` to browse/query table items in AWS Console
- Use `--region` to list tables in different AWS regions
- DynamoDB tables are region-specific (unlike global services)
- DynamoDB is a managed NoSQL service - no client connection like psql

---

## Troubleshooting

Common issues and solutions for aws-fzf.

### AWS Credentials Issues

**Problem:** "Unable to locate credentials" or permission denied errors

**Solutions:**

```bash
# Verify AWS CLI configuration
aws configure list

# Check current identity
aws sts get-caller-identity

# Verify specific profile
aws sts get-caller-identity --profile production

# List available profiles
cat ~/.aws/credentials | grep '\[' | tr -d '[]'
```

**Common Fixes:**

- Run `aws configure` to set up default credentials
- Use `--profile <name>` to specify the correct profile
- Ensure AWS_PROFILE environment variable matches your intent
- Check IAM permissions for your user/role

---

### No Resources Found

**Problem:** "No resources found" when listing services

**Solutions:**

```bash
# Verify you're in the correct region
aws fzf <service> <resource> list --region us-east-1

# List all regions for a service
aws ec2 describe-regions --query 'Regions[].RegionName' --output table

# Check if resources exist
aws <service> list-<resources> --region <region>
```

**Common Causes:**

- Resources exist in a different region
- Using wrong AWS profile
- Resources don't exist in your account
- Insufficient IAM permissions to list resources

---

### Database Connection Issues

**Problem:** Cannot connect to RDS/DSQL databases using alt-c

**RDS/Aurora Requirements:**

1. **PostgreSQL engine only** - IAM auth only works with postgres/aurora-postgresql
2. **IAM authentication enabled** - Must be enabled on the instance/cluster
3. **IAM permissions** - Your user/role needs `rds-db:connect` permission
4. **psql client installed** - `brew install postgresql` (macOS)

**DSQL Requirements:**

1. **IAM permissions** - Your user/role needs `dsql:DbConnect` permission
2. **psql client installed** - `brew install postgresql` (macOS)

**Verification Steps:**

```bash
# Check if psql is installed
which psql

# Verify IAM auth is enabled (RDS)
aws rds describe-db-instances --db-instance-identifier <name> \
  --query 'DBInstances[0].IAMDatabaseAuthenticationEnabled'

# Test IAM token generation (RDS)
aws rds generate-db-auth-token \
  --hostname <endpoint> \
  --port 5432 \
  --username <username> \
  --region <region>

# Test IAM token generation (DSQL)
aws dsql generate-db-connect-admin-auth-token \
  --hostname <endpoint> \
  --region <region>
```

**Enable IAM Authentication:**

1. Go to RDS Console
2. Select your database instance/cluster
3. Click "Modify"
4. Under "Database authentication", enable "Password and IAM database authentication"
5. Click "Continue" and apply changes

**Required IAM Policy (RDS):**

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "rds-db:connect",
      "Resource": "arn:aws:rds-db:REGION:ACCOUNT:dbuser:RESOURCE-ID/USERNAME"
    }
  ]
}
```

**Required IAM Policy (DSQL):**

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "dsql:DbConnect",
      "Resource": "arn:aws:dsql:REGION:ACCOUNT:cluster/CLUSTER-ID"
    }
  ]
}
```

---

### Clipboard Not Working

**Problem:** alt-a or alt-n keybindings don't copy to clipboard

**Solutions:**

**macOS:**

```bash
# pbcopy should be available by default
which pbcopy
```

**Linux (X11):**

```bash
# Install xclip
sudo apt-get install xclip  # Ubuntu/Debian
sudo yum install xclip      # RHEL/CentOS

# OR install xsel
sudo apt-get install xsel   # Ubuntu/Debian
```

**Linux (Wayland):**

```bash
# Install wl-clipboard
sudo apt-get install wl-clipboard  # Ubuntu/Debian
```

**Verification:**

```bash
# Test clipboard
echo "test" | pbcopy && pbpaste  # macOS
echo "test" | xclip -selection clipboard && xclip -selection clipboard -o  # Linux X11
echo "test" | wl-copy && wl-paste  # Linux Wayland
```

---

### Performance Issues

**Problem:** Slow listing or timeouts

**S3 Objects:**

```bash
# Use --prefix to filter at API level
aws fzf s3 object list --bucket my-bucket --prefix logs/2024/

# Limit results
aws fzf s3 object list --bucket my-bucket --max-items 1000
```

**Parameters/Secrets:**

```bash
# Use filters to narrow results
aws fzf secret list --filters Key=name,Values=prod*
aws fzf param list --parameter-filters "Key=Name,Option=BeginsWith,Values=/prod/"
```

**ECS:**

```bash
# Filter tasks by status
aws fzf ecs task list --cluster my-cluster --desired-status RUNNING
```

**DynamoDB:**

```bash
# Query specific region only
aws fzf dynamodb table list --region us-east-1
```

---

### fzf Not Found or Not Working

**Problem:** "fzf: command not found" or fzf doesn't display correctly

**Installation:**

```bash
# macOS
brew install fzf

# Ubuntu/Debian
sudo apt-get install fzf

# Or install from source
git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf
~/.fzf/install
```

**Verification:**

```bash
# Test fzf
echo -e "option1\noption2\noption3" | fzf
```

---

### Log Tailing Issues

**Problem:** alt-t doesn't tail logs or lnav not working

**Install lnav (optional but recommended):**

```bash
# macOS
brew install lnav

# Ubuntu/Debian
sudo apt-get install lnav
```





---

### Permission Errors

**Problem:** "Access Denied" or "UnauthorizedOperation" errors

**Required IAM Permissions by Service:**

**S3:**

- `s3:ListAllMyBuckets`
- `s3:ListBucket`
- `s3:GetObject` (for metadata)

**Secrets Manager:**

- `secretsmanager:ListSecrets`
- `secretsmanager:DescribeSecret`
- `secretsmanager:GetSecretValue` (for alt-v)

**Parameter Store:**

- `ssm:DescribeParameters`
- `ssm:GetParameter` (for alt-v)
- `kms:Decrypt` (for SecureString)

**Lambda:**

- `lambda:ListFunctions`
- `lambda:GetFunction`

**CloudWatch Logs:**

- `logs:DescribeLogGroups`
- `logs:DescribeLogStreams`
- `logs:GetLogEvents`
- `logs:FilterLogEvents`
- `logs:TailLogs`

**ECS:**

- `ecs:ListClusters`
- `ecs:DescribeClusters`
- `ecs:ListServices`
- `ecs:DescribeServices`
- `ecs:ListTasks`
- `ecs:DescribeTasks`

**RDS:**

- `rds:DescribeDBInstances`
- `rds:DescribeDBClusters`
- `rds-db:connect` (for IAM auth)

**DSQL:**

- `dsql:ListClusters`
- `dsql:GetCluster`
- `dsql:DbConnect` (for IAM auth)

**DynamoDB:**

- `dynamodb:ListTables`
- `dynamodb:DescribeTable`

**Debugging Permissions:**

```bash
# Simulate IAM policy
aws iam simulate-principal-policy \
  --policy-source-arn <your-user-arn> \
  --action-names <service>:<action> \
  --resource-arns <resource-arn>

# Check attached policies
aws iam list-attached-user-policies --user-name <username>
aws iam list-user-policies --user-name <username>
```

---

### Getting Help

If you encounter issues not covered here:

1. **Check AWS CLI:** Verify the underlying AWS CLI command works:

   ```bash
   aws <service> <operation> [options]
   ```

2. **Enable debug mode:** Add `set -x` to the top of any script to see what commands are being executed

3. **Check logs:** Look for error messages in the terminal output

4. **Verify dependencies:**

   ```bash
   which aws    # AWS CLI
   which fzf    # fuzzy finder
   which jq     # JSON processor
   which gum    # TUI library
   ```

5. **Report issues:** https://github.com/aws-contrib/aws-fzf/issues
