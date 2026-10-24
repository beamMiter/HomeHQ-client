# HomeHQ

One place to run a household. Bills, shopping and purchases, notes and chores,
medicine stock, contractors on a map, and the home cameras, in one app, in Thai
and English.

| Part | Repository | Stack |
| --- | --- | --- |
| App (this repository) | [HomeHQ-client](https://github.com/beamMiter/HomeHQ-client) | Flutter, Riverpod, go_router, dio |
| API | [HomeHQ-server](https://github.com/beamMiter/HomeHQ-server) | Go, chi, PostgreSQL |

The app talks to the API over HTTP only; nothing is shared between the two
repositories except that contract.

---

## Run it

You need the API running first (see HomeHQ-server: `make dev` starts it with
demo cameras and applies any new migrations). Then:

```bash
open -a Simulator                # open the iOS simulator (or plug in a device)
flutter pub get
flutter run                      # several devices: flutter devices, then flutter run -d <id>
```

- **API address:** the `API_BASE_URL` key in your own `.env.development` (an asset
  of the app, read by `lib/config/env.dart`). The file is git-ignored, so create
  it once after cloning, with one line:

  ```
  API_BASE_URL=http://127.0.0.1:8080/api/v1
  ```

  Without it `flutter analyze` warns and `flutter test` and builds stop (`Failed to
  build asset bundle`), because `pubspec.yaml` lists it as an asset.

  | Running on | Value |
  | --- | --- |
  | iOS simulator | `http://127.0.0.1:8080/api/v1` |
  | Android emulator | `http://10.0.2.2:8080/api/v1` |
  | Physical device | `http://<your machine's LAN IP>:8080/api/v1` |

  Keep only public values in that file: it ships inside the app, and anyone
  can unpack an app. Anything private belongs on the server.

- **Account:** on a database seeded by the server (`make seed`, empty or
  throwaway database only) sign in with `admin@example.com` / `admin2026` or
  `user@example.com` / `user2026`. **Create account** in the app makes a new
  one.

- **Languages:** Thai and English. The app follows the device language and can
  be switched from the translate button on the home screen. Strings live in
  `lib/l10n/app_en.arb` (the template) and `app_th.arb`, which must have the
  same keys. Regenerate the code with `flutter gen-l10n` (it also runs on
  `flutter pub get` and `flutter run`).

- **Models:** after changing a `json_serializable` model,
  `dart run build_runner build --delete-conflicting-outputs`.

## Check and test

```bash
flutter analyze
flutter test
```

The same two commands run in CI on every push to `dev` / `main` and on every
pull request.

## Layout

- `lib/screens/` UI, `lib/state/` Riverpod providers, `lib/repositories/`,
  `lib/services/` (dio API clients), `lib/models/`, `lib/l10n/` translations.
- Each backend domain follows the same chain: `services/<domain>_api.dart` →
  `repositories/<domain>_repository.dart` → `state/<domain>_provider.dart` →
  `screens/<domain>_*.dart`.
- Routes are all in `lib/router.dart`.

## Status

`0.1.0`. Not yet exercised against a real Imou account, a real Google Places
key or a physical device; the cameras and the contractor search are developed
against the server's fake driver and the Places proxy's tests.

## License

No license has been chosen yet, so all rights are reserved.
