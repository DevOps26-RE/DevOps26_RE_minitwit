# Reflection Perspective
## Issues, resolutions and lessons learned
Initially each member ported part of the Python-to-Go rewrite alone, which left some tasks disconnected; 
Going forward, we addressed this by assigning the group member with the most pre-existing knowledgeable the peer-review role and we held weekly syncs.

## Maintenance
We experienced our biggest issue during the Compose-to-Swarm migration: 
the deployment automation had only ever worked against Compose, so the cutover broke live and took four successive fixes to stabilize [#36–#39]. 
The deeper cause was treating the migration itself as the first real test of the new automation. 
Lesson: major infrastructure changes need a deployment path proven on staging first and shared edge components like Traefik must be decoupled so they survive migrations.

## Network
We encountered several network configuration challenges, particularly after integrating Traefik, TLS, and the Swarm Overlay Network. 
Although we successfully restored communication to its expected state, we still lack a clear understanding of the root causes and how to prevent similar issues in the future.

## DevOps-style work compared to earlier projects
### CI/CD
In contrast to previous academic projects, we integrated a CI/CD pipeline that automatically ran static analysis, deployed to a staging environment and executed tests on every pull request. This shifted our integration process from a last-minute effort to a continuous, reliable workflow.
### Monitoring
Previously, application logs were rarely actively reviewed. Because this was our first experience managing a deployed project with simulated live traffic, we quickly realized the necessity of system observability. Initially, we manually checked droplet metrics via the DigitalOcean dashboard. Implementing an automated monitoring stack proved crucial: being able to see when a virtual machine approaches its memory limit allows us to proactively address issues rather than reacting to system failures after the fact.
### Deployment
By finalizing a one-click deployment pipeline, we abstracted the complexity of our infrastructure. This ensures that any team member can reliably deploy the project regardless of their familiarity with the underlying systems. Furthermore, this automation improves system security by encapsulating sensitive deployment credentials and processes, significantly reducing the risk of manual configuration errors.

## Use of Generative AI
We used generative AI all the time for several tasks, with mixed results:
- __Rapid prototyping and iterative refinement:__ We utilized generative AI to draft most of the initial codebase. Because this auto-generated code frequently led to failures, therefore we had to manually correct it.
- __Documentation:__ Generating documentation for new implementations, which we used in Thursday meetings to recap the week's work.
- __As a documentation search engine:__ Querying specific, hard-to-understand parts of technologies instead of reading official docs. This sometimes worked well but sometimes produced unnecessarily complex suggestions.
- __Boilerplate porting:__ Translating the routing layer from Python to Go.
- __Understanding our own codebase:__ Feeding the full codebase to AI to "interview" it about behaviour we found unclear: most usefully, the interactions between DigitalOcean's network, Docker's network and each VM's network.
