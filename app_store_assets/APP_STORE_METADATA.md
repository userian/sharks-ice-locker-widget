# App Store Connect Submission Guide & Metadata

All required screenshot sets and the `1024×1024` App Store marketing icon are located in [`app_store_assets/`](./) as **24-bit RGB PNGs (no alpha/transparency)** at Apple's exact pixel specifications.

---

## 1. Screenshot & Icon Files Ready to Upload

| App Store Slot | Folder / File | Resolution | Format |
| :--- | :--- | :--- | :--- |
| **iPhone 6.9" Display** *(Required)* | [`app_store_assets/iphone_6.9_1320x2868/`](./iphone_6.9_1320x2868/) | `1320 × 2868` px | 24-bit RGB PNG |
| **iPhone 6.5" Display** *(Fallback/Optional)* | [`app_store_assets/iphone_6.5_1284x2778/`](./iphone_6.5_1284x2778/) | `1284 × 2778` px | 24-bit RGB PNG |
| **iPad 13" Display** *(Required for Universal builds)* | [`app_store_assets/ipad_13_2064x2752/`](./ipad_13_2064x2752/) | `2064 × 2752` px | 24-bit RGB PNG |
| **iPad 12.9" Display** *(Fallback/Optional)* | [`app_store_assets/ipad_12.9_2048x2732/`](./ipad_12.9_2048x2732/) | `2048 × 2732` px | 24-bit RGB PNG |
| **App Store Icon** | [`app_store_assets/icon_1024x1024.png`](./icon_1024x1024.png) | `1024 × 1024` px | 24-bit RGB PNG |

Each device folder contains 4 ordered screenshots:
1. `01_home_screen_widget.png` — iOS Home Screen Small & Medium widgets showing room number, rink surface, game time, and White/Dark jersey badge alongside the **Which Room?** app icon.
2. `02_todays_games.png` — Main **Which Locker Room?** screen highlighting multiple games today at the top of the schedule.
3. `03_add_teams_search.png` — **Add Teams** page with live search pinned at the top above the keyboard across 170+ SIAHL teams.
4. `04_multi_rink_settings.png` — **Settings** screen showing San Jose, Fremont, and Oakland Ice facility selection and team management.

---

## 2. Copy-Paste Text Fields for App Store Connect

### App Information
- **Name** *(max 30 chars)*:
  ```text
  Which Locker Room?
  ```
- **Subtitle** *(max 30 chars)*:
  ```text
  Ice Hockey Rink & Room Finder
  ```
- **Primary Category**: `Sports`
- **Secondary Category**: `Utilities`

### Version Information
- **Promotional Text** *(max 170 chars)*:
  ```text
  Know your locker room number, rink surface, game time, and Home/Away jersey color before walking into the arena—right from your iPhone Home Screen widget!
  ```

- **Description** *(max 4000 chars)*:
  ```text
  Skip crowding around the lobby TV monitor with your hockey bag on your shoulder. Which Locker Room? gives adult league and youth hockey players instant access to today's live locker room assignments, ice surfaces, game times, and Home/Away jersey colors.

  KEY FEATURES
  • iOS Home Screen Widgets (Small, Medium & Large): See your locker room number, rink surface, opponent, game time, and whether you are wearing White (Home) or Dark (Away) jerseys without even opening the app.
  • Multi-Team Support: Play on more than one team or subbing tonight? Add all of your teams and see every game you have today highlighted right at the top of the app and on your widget.
  • Full League Team Directory: Search and add from over 170 SIAHL teams across every division—even on days when your team isn't on the schedule—or add any custom team name.
  • Multi-Rink Coverage: Switch seamlessly between San Jose (Sharks Ice at San Jose / Tech CU Arena), Fremont (Sharks Ice at Fremont), and Oakland Ice Center.
  • Live Rink Schedule: Browse the full daily locker room board grouped by ice surface to see where friends, opponents, or other divisions are skating.
  • Zero Accounts, Zero Tracking: Your favorite teams and rink preferences are stored locally on your device. No sign-ups, no ads, and no personal data collection.
  ```

- **Keywords** *(max 100 chars, comma-separated, no spaces after commas)*:
  ```text
  hockey,locker room,sharks ice,siahl,san jose,rink,ice hockey,schedule,fremont,oakland,adult league
  ```

- **What's New in This Version (1.0.0)**:
  ```text
  Initial release of Which Locker Room? featuring Small, Medium, and Large iOS Home Screen widgets, multi-team game cards, instant search across 170+ league teams, and support for San Jose, Fremont, and Oakland ice facilities.
  ```

### URLs & Copyright
- **Support URL**:
  ```text
  https://userian.github.io/sharks-ice-locker-widget/#support
  ```
- **Marketing URL**:
  ```text
  https://userian.github.io/sharks-ice-locker-widget/
  ```
- **Privacy Policy URL**:
  ```text
  https://userian.github.io/sharks-ice-locker-widget/#privacy
  ```
- **Copyright**:
  ```text
  2026 Ian MacBean
  ```

*(Note: Make sure GitHub Pages is enabled in your repository under **Settings → Pages → Build and deployment → Source: Deploy from a branch → Branch: `main` / `/docs`** so the URLs above resolve publicly.)*

---

## 3. App Privacy & Age Rating Questionnaire

- **App Privacy (Data Collection)**:
  - *Do you or your third-party partners collect data from this app?* → **No, we do not collect data from this app.**
- **Age Rating**:
  - Select **None / No** for all content descriptors (Violence, Gambling, Profanity, User-Generated Content, Unrestricted Web Access, etc.). Resulting rating: **4+**.
- **Export Compliance (Encryption)**:
  - *Does your app use encryption?* → **No** (or *Standard OS HTTPS only*, which is exempt under `ITSAppUsesNonExemptEncryption = false`).

---

## 4. App Review Information (Notes for Apple Reviewer)

- **Sign-In Required**: Uncheck *(No sign-in required)*.
- **Notes for Reviewer**:
  ```text
  Which Locker Room? displays live daily hockey locker room assignments for Bay Area ice rinks (San Jose, Fremont, and Oakland).

  How to test:
  1. Open the app to view today's live locker room assignments grouped by rink surface.
  2. Tap the Settings gear icon (top right) -> tap "+ Add Teams" to search and select one or more teams (or pick any team playing today from the main schedule).
  3. Return to the main screen to see your selected teams' games highlighted at the top with their locker room number, rink surface, game time, and Home (White) / Away (Dark) jersey indicator.
  4. On the iOS Home Screen, long-press -> tap "+" -> search for "Which Room?" to add the Small, Medium, or Large locker room widget.
  ```
