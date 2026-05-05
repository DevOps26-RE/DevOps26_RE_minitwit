# Process' Perspective

This perspective should clarify how code or other artifacts come from idea into the running system and everything that happens on the way.
In particular, the following descriptions should be included:
- A complete description and illustration of stages and tools included in the CI/CD pipelines, including deployment and release of your systems.
- How do you monitor your systems and what precisely do you monitor?
- What do you log in your systems and how do you aggregate logs?
- Brief description of how you security hardened your systems.
- How do you handle availability and scaling in your systems?

<!-- Section bodies live under sections/*.md (one file per topic). @include lines are expanded when you run `make report` (report/main.template.md → report/main.md). -->

@include sections/cicd.md

@include sections/monitoring.md

@include sections/logging.md

@include sections/security.md

@include sections/availability.md
