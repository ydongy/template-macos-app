# Template roadmap

## Baseline

Version 1.0 is the first release: a menu bar panel with the Example screen in four states, a footer with update check and quit, in-app updates, nine languages, and a release pipeline that signs, notarizes and publishes. It is waiting for the first real screen, the Developer ID certificate, the Sparkle key pair and the first release rehearsal.

## Next

- v1.1: A Settings window with the language choice, a switch for the daily update check and an About screen that credits Sparkle.

## Needed before the first release

The Developer ID certificate and notarization profile, the Sparkle key pair (the public key goes into `SPARKLE_PUBLIC_KEY` in `project.yml`, the private key stays in the keychain with an offline backup), the website with its legal pages, the downloads bucket, and the `release` environment with its secrets ([releasing.md](releasing.md)).

## Later

- Notifications when an item needs attention.
- Open at login.
- Paid plans, which add a Licensing flow to `docs/spec.md` and rewrite the matching sections of `LICENSE`.
- Windows, Linux and the App Store are not planned.
