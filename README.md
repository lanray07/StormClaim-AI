# StormClaim AI

StormClaim AI is a SwiftUI iOS app for storm damage documentation workflows. It helps users create property cases, organize evidence photos, run cautious mock AI damage scans, approve findings, generate claim-support documentation, and export professional PDF reports.

The app is documentation support only. It does not provide insurance advice, legal advice, certified roof inspections, structural engineering advice, or claim approval decisions. AI-assisted findings must be reviewed by qualified professionals.

## Stack

- SwiftUI
- MVVM
- SwiftData
- StoreKit 2 subscription scaffolding
- PhotosPicker and camera support
- Native PDF generation
- Mock AI enabled by default

## Open In Xcode

Open `StormClaimAI.xcodeproj` and run the `StormClaimAI` scheme on an iOS 17+ simulator or device.

The current development environment does not include Apple's `xcodebuild` tooling, so simulator validation should be run on macOS with Xcode installed.

## GitHub Xcode Builds

This repository includes GitHub Actions workflows:

- `iOS Xcode Build`: runs an unsigned iOS Simulator build on every push and pull request.
- `iOS App Store Archive`: manual workflow for signed archive and App Store Connect upload after the required GitHub secrets are added.
- `Upload App Store Assets`: manual workflow for App Store metadata and screenshot upload via Fastlane.

Required secrets for App Store archive/upload:

- `APPLE_TEAM_ID`
- `BUILD_CERTIFICATE_BASE64`
- `P12_PASSWORD`
- `BUILD_PROVISION_PROFILE_BASE64`
- `APP_STORE_CONNECT_API_KEY_ID`
- `APP_STORE_CONNECT_API_ISSUER_ID`
- `APP_STORE_CONNECT_API_KEY_BASE64`

The generated App Store screenshots and listing copy are in `AppStoreAssets/` and mirrored into `fastlane/` for upload.
