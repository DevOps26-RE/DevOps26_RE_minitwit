# Reflection Perspective

Describe the biggest issues, how you solved them, and which are major lessons learned with regards to:
- evolution and refactoring
- operation, and
- maintenance
of your ITU-MiniTwit systems. Link back to respective commit messages, issues, tickets, etc. to illustrate these.

Also reflect and describe what was the "DevOps" style of your work. For example, what did you do differently to previous development projects and how did it work?

Use of Generative AI

ITU's rules on the use of generative AI apply for this report too. They are described here and in detail here. Please follow them. For your report that means that you have to state which generative AI tools have been used for which task(s) in your projects. Additionally, describe how generative AI tools have been used and briefly reflect and discuss how they supported or hindered your work process.


<!-- Cover: major issues and how you solved them; lessons on evolution/refactoring, operation, and maintenance. Link to commits, issues, tickets. Reflect on your DevOps-style work vs previous projects. -->

## Major issues, resolutions, and lessons learned

Early on, each member ported part of the application from Python to Go independently. This left some members disconnected from the project, with progress carried by a few individuals. We restructured at a meeting: the member with the deepest understanding of the stack moved to a pure peer-review role, which forced knowledge-sharing, and we redistributed tasks and held weekly Thursday syncs to keep everyone involved. [link: meeting notes / issue]

### Evolution and refactoring

<!-- Link: relevant commits / PRs / issues. -->

### Operation

<!-- Link: on-call, incidents, alerts (if any). -->

### Maintenance

Our one-click deployment script drifted out of sync with the live stack, because we only updated it when a redeploy was actually needed. This came to a head when we tried to migrate from Docker Compose to Docker Swarm: we attempted the switch manually, it failed, and the outdated deployment script meant we could neither restore the previous state nor cleanly redeploy. The result was a multi-week downtime while we re-synced CI/CD, the deployment script, and the live stack. [link: incident issue / commits]
A compounding factor was that our Traefik instance was embedded in the Compose stack, so it could not stay up while we stood up new infrastructure. The risky workaround, of rerouting requests at the OS level before they reached Traefik, ultimately caused the crash.
Lessons learned: Major infrastructure changes should go through a tested one-click deployment script rather than manual steps, and shared components like Traefik should be decoupled from the application stack so they can persist across migrations.
<!-- Link: technical debt, documentation, dependency upgrades, etc. -->

## DevOps-style work compared to earlier projects

We built a CI/CD chain that triggers a GitHub Actions runner on each pull request. The runner performs stack analysis, deploys the changes to a staging server, and runs tests against the deployed application. This made peer review accessible and gave us confidence that new implementations actually worked before merging — a clear contrast with earlier projects, where integration and testing happened late and manually. [link: workflow file / PR]
<!-- e.g. automation, small batches, IaC, observability-first practices. -->

## Use of Generative AI

We used generative AI for several tasks, with mixed results:

- __Documentation:__ Generating documentation for new implementations, which we used in Thursday meetings to recap the week's work.
- __As a documentation search engine:__ Querying specific, hard-to-understand parts of technologies instead of reading official docs. This sometimes worked well but sometimes produced unnecessarily complex suggestions.
- __Boilerplate porting:__ Translating the routing layer from Python to Go.
- __Understanding our own codebase:__ Feeding the full codebase to AI to "interview" it about behaviour we found unclear — most usefully, the interactions between DigitalOcean's network, Docker's network, and each VM's network.


<!-- e.g. how we use ai. -->
