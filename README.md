# iAPS-AI

An AI-assisted companion app that helps review iAPS (Loop) therapy settings against current Nightscout data before suggesting adjustments.

## What the app can do today

- **Load Loop settings directly.** Pick a `freeaps_settings.json` file from the on-device Files app, preview the raw JSON, and reuse any Nightscout URL or API secret it can infer so connectivity stays aligned with the Loop setup.
- **Connect to a Nightscout site.** Provide the base Nightscout URL and, if needed, an API token. The built-in Nightscout service will attach the token as the `api-secret` header so it can reach protected endpoints.
- **Review glucose trends.** Fetch the latest 100 blood glucose (BG) readings for a given start date via the `/api/v1/entries.json` endpoint.
- **Audit recent insulin delivery.** Retrieve recent insulin injection events from the `/api/v1/treatments.json` endpoint, filtered by start date, to understand how Loop has been dosing.
- **Inspect carbohydrate intake.** Pull recent carb correction treatments so you can compare Loop settings to the user’s logged meals.
- **Run everything on-device.** All API calls are issued from the app with Swift’s async/await networking so you can experiment directly in the simulator or on-device.

Console output currently surfaces the fetched data, making it easy to prototype additional AI-powered analysis or automate setting recommendations.

The app treats Loop's `freeaps_settings.json` as the source of truth. The UI will browse for the file via the Files picker, preview its contents, and reuse any Nightscout URL or API secret it can infer so Nightscout calls stay aligned with the Loop setup. A helper button writes an `iAPSAdvisorLastTouched` marker back to the file so you can confirm round-trip access.

## Working with `freeaps_settings.json`

`ContentView` now uses `LoopSettingsProvider` with a file importer so you can select `freeaps_settings.json` from the Files app, infer Nightscout connection info, and show a preview of the entire JSON payload. A "Stamp advisor signature" button writes an `iAPSAdvisorLastTouched` field back to the file so you can confirm read/write access end-to-end.

Future enhancements for AI-driven recommendations can build on the same provider to parse additional settings, merge model output, and write the amended JSON back into the Loop container.

## Project layout

- **iAPSAdvisor** – SwiftUI iOS 15+ target that contains the `ContentView` UI and the Nightscout integration service.
- **Tests** – Placeholder folder ready for unit/UI tests as functionality grows.

## Getting started

1. Open `iAPSAdvisor.xcodeproj` in Xcode 15 or newer.
2. Update the Nightscout URL and optional API token fields with your site details.
3. Build and run the app in the iOS simulator (15.0+) or on a device to start fetching Loop-related data.

> ⚠️ The AI logic that interprets the fetched data and recommends setting changes is not implemented yet. The current build focuses on establishing secure connectivity to Nightscout so future AI modules can reason over real-world Loop usage.
