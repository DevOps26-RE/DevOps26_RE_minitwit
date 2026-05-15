## Static Analysis and Quality

<!-- e.g. make lint, golangci-lint, test coverage, integration-test strategy; optional trends or screenshots (store images under report/images/). -->

To maintain code quality and reduce security risks, the project applies a multi-layered static analysis strategy covering all languages used in the system.

**Layer 1: Language-specific linters** are integrated into the CI/CD pipeline via GitHub Actions:

- `gofumpt`: automatically formats Go code and commits any style fixes
- `golangci-lint`: performs comprehensive Go static analysis including security checks
- `hadolint`: enforces Dockerfile best practices
- `htmlhint`: validates HTML structure
- `yamllint`: checks YAML syntax and indentation

Minor formatting issues are corrected automatically, while errors and security warnings cause the pipeline to fail with a clear message indicating the file and line number. These tools can also be run locally via `make lint`, ensuring developers receive the same feedback before pushing. Each tool is configurable: rules and thresholds can be adjusted to ignore specific warnings or tighten checks per project needs.

**Layer 2: SonarQube Cloud** performs deeper cross-language analysis, scanning for bugs, security vulnerabilities and code smells. It is tightly integrated with GitHub, providing real-time feedback on pull requests.

Together, these two layers act as a quality gate that all code must pass before deployment, reducing the risk of shipping defects or security issues and enforcing consistent coding standards throughout the project.
