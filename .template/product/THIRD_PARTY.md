<!-- template: app/THIRD_PARTY.md v1 -->
# Third-party software

| Name | Version | License | Shipped in the app | Notice | Credited in About |
|---|---|---|---|---|---|
| Sparkle | 2.10.0 | MIT | yes | `Template/Resources/ThirdPartyLicenses/Sparkle-LICENSE.txt` | no |

## Notes

- **Sparkle** provides in-app updates. The version equals `Package.resolved`
  (`Template.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`). MIT requires keeping the
  copyright and license notice with distributions: the text ships in `Resources/ThirdPartyLicenses`. Template has
  no About screen yet, so nothing credits Sparkle in the app; the screen that adds About must name Sparkle
  (MIT License) there.
