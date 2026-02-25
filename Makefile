.PHONY: check
.SILENT: check
check:
	@echo "Checking dependencies..."
	@command -v jq >/dev/null 2>&1 || { echo "Error: jq not found."; exit 1; }
	@command -v fzf >/dev/null 2>&1 || { echo "Error: fzf not found."; exit 1; }
	@command -v gum >/dev/null 2>&1 || { echo "Error: gum not found."; exit 1; }
	@command -v aws >/dev/null 2>&1 || { echo "Error: aws CLI not found."; exit 1; }

.PHONY: install
.SILENT: install
install: check
	@echo "Preparing AWS CLI configuration directory..."
	mkdir -p "$(HOME)/.aws/cli"

	@if [ -f "$(HOME)/.aws/cli/alias" ]; then \
		echo "Backing up existing alias file to ~/.aws/cli/alias.bak..."; \
		cp "$(HOME)/.aws/cli/alias" "$(HOME)/.aws/cli/alias.bak"; \
	fi

	@echo "Installing AWS CLI alias file..."
	sed "s|\$${FZF_AWS_DIR}|$$PWD|g" "$(CURDIR)/templates/alias.tmpl" > "$(HOME)/.aws/cli/alias"
