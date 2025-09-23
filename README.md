# iAPS-AI

An AI-assisted companion app that helps review iAPS (Loop) therapy settings against current Nightscout data before suggesting adjustments.

## What the app can do today

- **Collect Loop configuration context.** Enter your Loop team identifier (TEAMID) so the app can display the matching App Group name (`group.com.{TEAMID}.loopkit.LoopGroup`) that is required when sharing data between Loop components.
- **Connect to a Nightscout site.** Provide the base Nightscout URL and, if needed, an API token. The built-in Nightscout service will attach the token as the `api-secret` header so it can reach protected endpoints.
- **Review glucose trends.** Fetch the latest 100 blood glucose (BG) readings for a given start date via the `/api/v1/entries.json` endpoint.
- **Audit recent insulin delivery.** Retrieve recent insulin injection events from the `/api/v1/treatments.json` endpoint, filtered by start date, to understand how Loop has been dosing.
- **Inspect carbohydrate intake.** Pull recent carb correction treatments so you can compare Loop settings to the user’s logged meals.
- **Run everything on-device.** All API calls are issued from the app with Swift’s async/await networking so you can experiment directly in the simulator or on-device.

Console output currently surfaces the fetched data, making it easy to prototype additional AI-powered analysis or automate setting recommendations.

## Project layout

- **iAPSAdvisor** – SwiftUI iOS 15+ target that contains the `ContentView` UI and the Nightscout integration service.
- **Tests** – Placeholder folder ready for unit/UI tests as functionality grows.

## Getting started

1. Open `iAPSAdvisor.xcodeproj` in Xcode 15 or newer.
2. Update the Nightscout URL and optional API token fields with your site details.
3. Build and run the app in the iOS simulator (15.0+) or on a device to start fetching Loop-related data.

> ⚠️ The AI logic that interprets the fetched data and recommends setting changes is not implemented yet. The current build focuses on establishing secure connectivity to Nightscout so future AI modules can reason over real-world Loop usage.
