.PHONY: all lint fmt-go lint-go lint-docker lint-html lint-yaml install-tools

# Default target: runs all linting and formatting tasks
all: lint

# Combined entry point for all static analysis tools
lint: fmt-go lint-go lint-docker lint-html lint-yaml
	@echo "🎉 All static analysis and linting checks passed successfully!"

# 1. Go Code Formatting (directly modifies and formats .go files)
fmt-go:
	@echo "==> 🔍 Running gofumpt formatter..."
	gofumpt -l -w .

# 2. Go Linter (comprehensive analysis for bugs and style issues)
lint-go:
	@echo "==> 🔍 Running golangci-lint..."
	golangci-lint run ./... --timeout=5m

# 3. Dockerfile Linter (checks for best practices using hadolint via Docker)
lint-docker:
	@echo "==> 🔍 Running hadolint..."
	docker run --rm -i hadolint/hadolint hadolint --ignore DL3006 - < docker/Dockerfile-app
	docker run --rm -i hadolint/hadolint hadolint --ignore DL3006 - < docker/Dockerfile-test
	docker run --rm -i hadolint/hadolint hadolint --ignore DL3006 - < prometheus/Dockerfile-prometheus

# 4. HTML Linter (validates tags and structure)
lint-html:
	@echo "==> 🔍 Running htmlhint..."
	npx htmlhint "**/*.html" --config .htmlhintrc --format=compact

# 5. YAML Linter (validates indentation and syntax)
lint-yaml:
	@echo "==> 🔍 Running yamllint..."
	yamllint -c .yamllint .

# Helper: Install missing local tools (except golangci-lint and docker)
install-tools:
	@echo "==> 📦 Installing local inspection tools..."
	go install mvdan.cc/gofumpt@latest
	npm install
	pip install yamllint
	@echo "✅ npm, pip, and go tools installation completed!"
	@echo "⚠️ If golangci-lint is not installed, please refer to: https://golangci-lint.run/usage/install/"