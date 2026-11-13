# Code signing policy

Free code signing provided by [SignPath.io](https://signpath.io/), certificate by [SignPath Foundation](https://signpath.org/).

Official Windows release artifacts (portable ZIP, EXE installer, MSIX helper) are built automatically from the source code in the [mesh repository](https://github.com/mesh/mesh) using GitHub Actions ([release workflow](.github/workflows/release.yml)) and signed through SignPath. Every signing request is manually approved by an approver listed below.

Only binaries built by mesh are signed. Third-party binaries that are packaged with the app are distributed as provided by their upstream projects and do not receive the mesh signing operation.

Signed Windows files show **SignPath Foundation** as the publisher because the certificate belongs to the foundation, not to the mesh project.

## Team roles

- Committers and reviewers: [@SaeedR](https://github.com/SaeedR)
- Approvers: [@SaeedR](https://github.com/SaeedR)

## Privacy

mesh's privacy policy is available at [mesh.org/privacy](https://mesh.org/privacy).

