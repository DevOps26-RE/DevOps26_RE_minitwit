## Static Analysis and Quality

<!-- e.g. make lint, golangci-lint, test coverage, integration-test strategy; optional trends or screenshots (store images under report/images/). -->

We enforce code quality through a two-layered static analysis pipeline in GitHub Actions.

**Layer 1: Language-specific linters**
These tools run on every pull request to catch syntax issues and enforce formatting:
- `gofumpt`: automatically formats Go code and commits style fixes
- `golangci-lint`: performs comprehensive Go static analysis and security checks
- `hadolint`: enforces Dockerfile best practices
- `htmlhint`: validates HTML structure
- `yamllint`: checks YAML syntax and indentation

Formatting issues are corrected automatically where possible. Errors or security warnings fail the pipeline with file and line number indicators. Developers can run `make lint` locally to receive the same feedback before pushing.

**Layer 2: SonarQube Cloud**
SonarQube performs deeper cross-language analysis to scan for bugs, security vulnerabilities and code smells. It is integrated with GitHub to provide real-time inline feedback on pull requests.
Our current SonarQube rating is as follows: Security Rating is an E with 18 unsolved issues; Security Hotspot is an E with 9 unsolved issues; Reliability is an A with 1 unsolved issue; and Maintainability is an A with 29 unsolved issues.