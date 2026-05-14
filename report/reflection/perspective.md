# Reflection Perspective
## Major issues, resolutions, and lessons learned
Initially each member ported part of the Python-to-Go rewrite alone, which left some disconnected; we fixed this by moving our most knowledgeable member to a pure peer-review role and holding weekly syncs.

### Maintenance
Our biggest failure was the Compose-to-Swarm migration: the deploy automation had only ever worked against Compose, so the cutover broke live and took four successive fixes to stabilise [#36–#39]. The deeper cause was treating the migration itself as the first real test of the new automation. Lesson: major infrastructure changes need a deployment path proven on staging first, and shared edge components like Traefik must be decoupled so they survive migrations.

### DevOps-style work compared to earlier projects
Unlike earlier projects, a CI/CD pipeline ran analysis, staging deployment, and tests on every PR <!-- We might want to link to the actual PR in which this was implemented? -->, making integration continuous rather than last-minute.
Generative AI. Used for boilerplate route porting, documentation, and as a searchable interface to our own codebase; results were useful but occasionally over-complex.

### Use of Generative AI
We used generative AI for several tasks, with mixed results:

- __Documentation:__ Generating documentation for new implementations, which we used in Thursday meetings to recap the week's work.
- __As a documentation search engine:__ Querying specific, hard-to-understand parts of technologies instead of reading official docs. This sometimes worked well but sometimes produced unnecessarily complex suggestions.
- __Boilerplate porting:__ Translating the routing layer from Python to Go.
- __Understanding our own codebase:__ Feeding the full codebase to AI to "interview" it about behaviour we found unclear — most usefully, the interactions between DigitalOcean's network, Docker's network, and each VM's network.

<!-- around 286 words total -->
