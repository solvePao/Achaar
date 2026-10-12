# Xcode Cloud → TestFlight

Achaar's **TestFlight** workflow is configured in App Store Connect:

- Repository: `https://github.com/solvePao/Achaar.git`
- Automatic start: any file change pushed to the exact branch `testflight`.
- Newer pushes cancel older queued/running builds on the same branch.
- Project: `Achaar.xcodeproj`; shared scheme: `Achaar`.
- Action: iOS Archive, Release configuration from the shared scheme.
- Distribution preparation: App Store Connect, with cloud-managed signing.
- Post-action: TestFlight Internal Testing → **Achaar Internal**.
- Environment: latest released Xcode and compatible macOS; clean builds.
- Xcode Cloud assigns sequential build numbers, initially starting at **2** because build 1 was uploaded manually.

[Edit the workflow](https://appstoreconnect.apple.com/teams/cedbeb03-4c18-4914-9f6d-7cfe94b21117/xcode-cloud/products/7a00ec5e-4e7a-4aa2-bc8b-c30fbe9aeee9/workflows/6B8BF533-CCD2-46B6-A7F2-28038C81F212).

## Push a beta

Commit your changes on `main`, then move the beta branch forward:

```sh
git switch testflight
git merge --ff-only main
git push origin testflight
```

Each new push starts a cloud archive. Successful archives are uploaded and processed for TestFlight, then assigned to the internal group. The group starts with no testers; add eligible internal testers in App Store Connect when you want them to receive builds. External testing requires its own group and Apple's beta review; this workflow does not submit a public App Store release.

No signing private keys, API keys, Apple ID credentials, or Instagram sessions belong in this repository. The checked-in Xcode Cloud manifest contains only product identifiers. The workflow itself is stored by Apple, so editing local files alone does not change its actions or trigger rules.

`ITSAppUsesNonExemptEncryption = false` records the same export-compliance answer used for build 1: Achaar uses platform WebKit/HTTPS and does not implement custom encryption. Reassess this declaration if encryption functionality changes.

Authenticated Instagram UI tests are intentionally excluded from automatic archives. They need a signed-in device session and cannot reliably run in a fresh cloud environment. Device testing remains necessary before distributing a beta.

## Check a build

```sh
asc xcode-cloud build-runs --workflow-id 6B8BF533-CCD2-46B6-A7F2-28038C81F212
asc xcode-cloud status --run-id BUILD_RUN_ID
asc xcode-cloud doctor --run-id BUILD_RUN_ID
```

Use the Cloud build's Issues and Logs if signing, archiving, or TestFlight processing fails. When uploading outside Xcode Cloud, set its next build number above the highest uploaded build number to avoid collisions.
