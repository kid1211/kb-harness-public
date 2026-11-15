# Claude Code harness, public part

Skills, shared libraries and Quint tooling from a private Claude Code harness. A sync script
copies a chosen list of paths here, as a PR into `nightly`. `main` and `nightly` take a change
only by a PR whose checks passed, merged by squash.

The checks on each PR and push scan for PII, secrets and a private list of names, and run the
unit tests of the scans. A PR from a fork cannot pass the name scan, since it gets no secret.

Some files name paths of the private harness that are not in this repo. Those links do not resolve here.
