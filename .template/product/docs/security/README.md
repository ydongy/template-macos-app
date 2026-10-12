# Security reviews

Every released version has one security review, `docs/security/<version>-review.md` (for example
`1.0.0-review.md`), written before the version bump is merged. A version without one is not released.

A review records, in short form:

- the version and commit reviewed, the date and the reviewer
- what changed since the previous version in code that touches credentials, the Keychain, networking, file access,
  code signing or the update path
- the result of `python3 scripts/scan_secrets.py` and of the dependency check (`Package.resolved`)
- findings, each with severity, decision (fixed, accepted with reason, deferred with issue) and where it was fixed
- what was NOT reviewed

Reports of vulnerabilities in the released app are handled through GitHub private vulnerability reporting of this
repository; fixes follow the same review and release path.
