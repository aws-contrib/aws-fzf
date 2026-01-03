# aws-fzf

Interactive fuzzy finder built with [fzf](https://github.com/junegunn/fzf) for
lightning-fast fuzzy searching of AWS resources and
[gum](https://github.com/charmbracelet/gum) for beautiful terminal UI.

## Installation

Install dependencies:

```bash
# macOS
brew install awscli fzf jq gum
```

Clone:

```bash
git clone https://github.com/aws-contrib/aws-fzf.git
```

Install AWS CLI alias:

```bash
make install
```

Verify installation:

```bash
aws fzf --help
```

## Quick Start

```bash
aws fzf param list               # Browse parameters
aws fzf secret list              # Browse secrets
aws fzf lambda list              # Browse Lambda functions
aws fzf s3 bucket list           # Browse S3 buckets
aws fzf ecs cluster list         # Browse ECS clusters
aws fzf logs group list          # Browse CloudWatch logs
```

## Documentation

See [docs/README.md](docs/README.md) for complete documentation including:

- Configuration (profiles, regions, environment variables), shortcuts
- Service Guides (`S3`, `SSM`, `Secrets Manager`, `ECS`, `Lambda`, `CloudWatch Logs`)

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

See [LICENSE](LICENSE) file for details.
