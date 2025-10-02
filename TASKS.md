# Task Breakdown for TestFlight Automation Readiness

This plan decomposes the outstanding work identified during the publication and code review into actionable tasks. Each task lists its dependencies and success criteria so multiple agents can work in parallel while keeping the pipeline aligned with the end goal: automated TestFlight distribution via GitHub Actions.

## 1. Ship-ready Xcode project & schemes
- [ ] **Create distributable Xcode project**  
  **Goal:** Generate an `.xcodeproj` or `.xcworkspace` that contains the existing SwiftUI app target and shares an `iAPSAdvisor` scheme.  
  **Key steps:**  
  • Convert the Swift package into a project via `swift package generate-xcodeproj` or by manually creating a project in Xcode and committing it.  
  • Ensure the scheme is marked as *shared* and the app target builds for iOS 15+.  
  • Verify `xcodebuild -scheme iAPSAdvisor -sdk iphonesimulator` succeeds locally.  
  **Dependencies:** None.  
  **Acceptance criteria:** The repository contains a committed project/workspace file and CI can discover the shared scheme.

- [ ] **Align bundle & version metadata**  
  **Goal:** Keep the project settings in sync with `Info.plist` so automated builds have consistent identifiers.  
  **Key steps:**  
  • Set the bundle identifier to the shipping value (e.g., `com.<team>.iAPSAdvisor`).  
  • Configure deployment target, version (`CFBundleShortVersionString`), and build number (`CFBundleVersion`) in Xcode build settings.  
  • Document or script build-number increments (e.g., via Fastlane or an Xcode run script).  
  **Dependencies:** Distributable project is committed.  
  **Acceptance criteria:** `xcodebuild -showBuildSettings` reflects the intended identifiers and the values propagate into the compiled app.

## 2. Signing assets & secrets
- [ ] **Provision Apple Developer assets**  
  **Goal:** Ensure App Store Connect and provisioning resources exist for CI uploads.  
  **Key steps:**  
  • Create or confirm the App ID and bundle identifier that matches the project.  
  • Generate a distribution certificate (`.p12`), provisioning profile, and an App Store Connect API key dedicated to CI.  
  **Dependencies:** Bundle identifier finalized.  
  **Acceptance criteria:** Required files exist locally and are ready to be converted into GitHub secrets.

- [ ] **Populate GitHub secrets & document rotation**  
  **Goal:** Store signing and API credentials securely for workflow use.  
  **Key steps:**  
  • Base64 encode the `.p12` and provisioning profile; add them to repo secrets (`P12_BASE64`, `PROVISIONING_PROFILE`, `P12_PASSWORD`).  
  • Add App Store Connect API key values (`APP_STORE_CONNECT_KEY_ID`, `ISSUER_ID`, `PRIVATE_KEY`).  
  • Document in `README` (or `docs/CI.md`) how to rotate credentials and trigger workflows safely.  
  **Dependencies:** Provisioned assets.  
  **Acceptance criteria:** Secrets exist in GitHub, and documentation outlines maintenance.

## 3. GitHub Actions pipeline hardening
- [ ] **Update build workflow to use new project**  
  **Goal:** Make `ios-build.yml` compile & test the committed project.  
  **Key steps:**  
  • Point `xcodebuild` commands at the `.xcodeproj`/`.xcworkspace` and shared scheme.  
  • Add `xcodebuild test` against a simulator destination matching iOS 15+.  
  • Publish build artifacts (`.xcresult`, logs) for troubleshooting.  
  **Dependencies:** Project & scheme committed.  
  **Acceptance criteria:** Workflow succeeds in CI with real build logs and test results.

- [ ] **Finish TestFlight upload workflow**  
  **Goal:** Enable `testflight.yml` to archive and upload a signed build.  
  **Key steps:**  
  • Add guard rails for missing secrets and fail-fast messaging.  
  • Reference a committed `ExportOptions.plist` suited for App Store distribution.  
  • Use Fastlane `pilot` or `xcrun altool/notarytool` for the upload, ensuring logs and the exported `.ipa` are archived on failure.  
  • Ensure tests run before the archive step.  
  **Dependencies:** Build workflow stabilized, secrets configured.  
  **Acceptance criteria:** Manual `workflow_dispatch` completes an end-to-end upload to TestFlight.

- [ ] **Dry-run pipeline verification**  
  **Goal:** Validate workflows before real credentials go live.  
  **Key steps:**  
  • Execute workflows on a branch with placeholder credentials or against a fork.  
  • Review artifacts for simulator build success, archive generation, and (mock) upload steps.  
  • Iterate until no manual intervention is required.  
  **Dependencies:** Build & TestFlight workflows updated.  
  **Acceptance criteria:** Dry-run logs demonstrate successful build/test/archive stages.

## 4. Nightscout service resiliency & tests
- [ ] **Propagate request-construction failures**  
  **Goal:** Distinguish between “no data” and “request could not be built.”  
  **Key steps:**  
  • Update `NightscoutService.makeRequest` to throw descriptive errors instead of returning `nil`.  
  • Adjust public fetch methods to throw the new errors.  
  **Dependencies:** None (parallelizable with pipeline work).  
  **Acceptance criteria:** Callers receive thrown errors when the URL cannot be formed, and tests cover these cases.

- [ ] **Validate HTTP status codes**  
  **Goal:** Ensure non-2xx responses surface meaningful errors.  
  **Key steps:**  
  • Capture the `URLResponse` from `URLSession.shared.data(for:)`.  
  • Guard for `HTTPURLResponse` and verify `200...299` before decoding.  
  • Throw `URLError(.badServerResponse)` (or custom error) when the status is outside the success range.  
  • Update unit tests to assert this behavior without relying on `MockURLProtocol` to inject the error.  
  **Dependencies:** Optional on previous task.  
  **Acceptance criteria:** Tests confirm that actual service code throws on non-success statuses.

- [ ] **Expand decoding & networking test coverage**  
  **Goal:** Harden regressions by covering token headers, query parameters, and failure paths.  
  **Key steps:**  
  • Refactor `MockURLProtocol` to deliver the raw response so the service decides how to error.  
  • Add tests for carb fetch, optional start date handling, and request-building errors.  
  • Consider snapshotting minimal JSON fixtures under `Tests/Fixtures` for readability.  
  **Dependencies:** Error handling updates.  
  **Acceptance criteria:** Test suite fails when headers/queries are wrong or when decoding rules change unexpectedly.

## 5. SwiftUI presentation improvements
- [ ] **Introduce observable view model**  
  **Goal:** Move networking from button closures into an `ObservableObject` so the UI can react to state changes.  
  **Key steps:**  
  • Create a view model exposing `@Published` arrays for BG readings, insulin treatments, carb treatments, and an error state.  
  • Inject the model into `ContentView` and drive fetches via async methods on the model.  
  • Display summaries (counts, latest values) in the UI instead of `print` statements.  
  **Dependencies:** Service error handling in place.  
  **Acceptance criteria:** Users see feedback in the simulator when fetches succeed or fail.

- [ ] **Add user-facing error & loading feedback**  
  **Goal:** Provide clear guidance during network activity.  
  **Key steps:**  
  • Surface loading indicators or disabled buttons while requests are in flight.  
  • Show error messages derived from thrown errors.  
  • Add basic accessibility labels for the new UI elements.  
  **Dependencies:** View model implemented.  
  **Acceptance criteria:** UI reflects loading/error states without relying on console output.

## 6. Documentation & knowledge sharing
- [ ] **Author CI/Release playbook**  
  **Goal:** Capture the full TestFlight release process for maintainers.  
  **Key steps:**  
  • Document prerequisites (Apple Developer roles, required secrets).  
  • Explain how to trigger `testflight.yml`, interpret logs, and verify builds in App Store Connect.  
  • Include troubleshooting guidance for common failures (missing entitlements, expired certificates).  
  **Dependencies:** Workflows finalized.  
  **Acceptance criteria:** A markdown guide exists under `docs/` or README and references the final workflow commands.

- [ ] **Add contributor onboarding notes**  
  **Goal:** Make it easy for new agents to set up the project locally.  
  **Key steps:**  
  • Update `README.md` with steps to open the new Xcode project, run tests, and understand the app architecture.  
  • Outline how to supply Nightscout credentials for local testing.  
  **Dependencies:** Major architecture changes merged.  
  **Acceptance criteria:** README accurately reflects the modernized project setup.

---

> **Execution tip:** Parallelize by having one agent focus on Xcode/CI setup while another improves the networking layer and UI. Sync via pull requests that reference the checkboxes above to keep progress visible.
