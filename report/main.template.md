# ITU-MiniTwit — Final Report (Main Index)

<!-- Formal requirements checklist (verify against the full course brief before writing / exporting PDF):
  - Maximum ~2500 words for the final report; figures do not count toward the word limit.
  - Sources must be in a markup language (this repo uses Markdown) and version-controlled here.
  - Place all report images under report/images/ (e.g. report/images/demo.gif).
  - CI must build a single PDF from the report sources into report/build/, filename must match: MSc_group_[a-z].pdf (e.g. MSc_group_a.pdf).
  - Link and briefly describe constitutional artifacts: repos, issue trackers, monitoring/logging, etc. (see appendix after expansion).
-->

<!-- Edit this file (main.template.md). Run `make report` to expand @include lines into report/main.md for PDF/GitHub preview. -->

## Abstract

<!-- One short paragraph. You may draft this after the body is complete. -->

## Outline

| Perspective | Topics |
|-------------|--------|
| [System](#system-perspective) | Architecture, dependencies, static analysis and quality |
| [Process](#process-perspective) | CI/CD, monitoring, logging, security, availability and scaling |
| [Reflection](#reflection-perspective) | Issues and lessons, evolution/ops/maintenance, DevOps-style work |
| [Appendix](#appendix) | External artifact links |

<a id="system-perspective"></a>

@include systems/perspective.md

<a id="process-perspective"></a>

@include process/perspective.md

<a id="reflection-perspective"></a>

@include reflection/perspective.md

<a id="appendix"></a>

@include appendix/artifacts.md

## Figures and illustrations

<!-- Use relative paths from report/main.md after expansion, e.g. ![Demo](images/demo.gif) -->
