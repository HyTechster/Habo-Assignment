<div align="center">

<img src="https://habo.space/images/logo.svg" alt="Habo Logo" height="80" />

# Habo

**Simple, open-source habit tracker — CSE6364 enhanced build**

[![Stars](https://img.shields.io/github/stars/xpavle00/Habo?style=flat-square&color=FFD700)](https://github.com/xpavle00/Habo/stargazers)
[![License](https://img.shields.io/badge/license-GPL--3.0-blue?style=flat-square)](LICENSE)
[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?style=flat-square&logo=flutter)](https://flutter.dev)
[![Weblate](https://img.shields.io/badge/translations-Weblate-brightgreen?style=flat-square)](https://hosted.weblate.org/projects/habo/)

<br/>

[<img src="https://habo.space/images/googleplay_badge_hu_edf4094967c7bf97.webp" height="50" alt="Get it on Google Play" />](https://play.google.com/store/apps/details?id=com.pavlenko.Habo)&nbsp;&nbsp;
[<img src="https://habo.space/images/appstore_badge_black.svg" height="50" alt="Download on the App Store" />](https://apps.apple.com/us/app/habo-habit-tracker/id1670223360)&nbsp;&nbsp;
[<img src="https://habo.space/images/izzy_badge_hu_1e22e7507a064b3b.webp" height="50" alt="Get it on IzzyOnDroid" />](https://apt.izzysoft.de/fdroid/index/apk/com.pavlenko.Habo)

</div>


## 🔗 **Repo:** [HyTechster/Habo-Assignment](https://github.com/HyTechster/Habo-Assignment)

| Branch | Description |
|---|---|
| [`original`](https://github.com/HyTechster/Habo-Assignment/tree/original) | Unmodified Habo v3.1.2 — baseline for comparison, no changes made |
| [`updated`](https://github.com/HyTechster/Habo-Assignment/tree/updated) | Our group's enhanced build — all four CSE6364 enhancements (E1–E4) applied |

<sub>Original base repo — this project is a modified version of [Habo](https://github.com/xpavle00/Habo), originally developed by Peter Pavlenko.</sub>


## What is Habo?

Habo is a fast, minimalist habit tracker that respects your privacy. No clutter — just a clean, focused tool for building routines that stick.

This build extends the original Habo with four group-project enhancements: a redesigned onboarding experience, a richer statistics module with heatmaps and trend charts, optional cloud backup via Supabase, and a social layer so signed-in users can share progress and stay accountable with friends.

---

## Features

### ✨ UI/UX Polish

A guided, three-page onboarding walks first-time users through the cue → routine → reward habit loop and explains every logging action before they create their first habit. Navigation was also reorganised: a persistent **bottom bar** (Home | Stats | Social) replaces the previous model where Statistics was always a separate pushed route, and new **Archive** and **Help** icons with tooltips were added to the app bar.


### 📊 Enhanced Statistics

The Statistics screen was rebuilt around five cards, replacing the original per-habit monthly bar chart:

- **Overall summary** — a donut chart breaking all logged days into checks, skips, fails, and numeric-habit progress, with your active habit count in the centre
- **Habit Comparison leaderboard** — ranks every active habit by current streak, top streak, or completion rate; three sort modes and an optional category filter narrow the view
- **Weekly Trend chart** — a 12-week line chart of your overall completion rate; tap any point to see which habits completed that week; a category dropdown recomputes the line on the fly
- **Yearly Heatmap** — one colour-coded row per habit grouped by category; consecutive completed days grow progressively darker as a streak lengthens; toggle between a scrollable full-year grid and a monthly calendar view
- **Best Day & Time** — a seven-bar chart of your average completion rate by weekday, with a highlighted best day and a best-time-of-day label (Morning, Afternoon, Evening, or Night) derived from your notification schedule


### ☁️ Authentication & Cloud Sync

Sign in with **email/password** or **Google** to back up all habit data to the cloud and restore it automatically on any device. All habit tracking continues to work fully offline without an account.

- Data pushed to Supabase in batches and pulled as a delta since the last sync
- Debounced sync on every user edit — changes propagate within seconds
- Entry-deletion reconciliation: cleared days are removed from the cloud, not silently restored on the next pull
- Per-user settings isolation: each account keeps its own theme and notification preferences


### 👥 Social Friend Features

Signed-in users can optionally connect with friends to stay accountable together. Everything here is opt-in — people who use Habo without signing in see no change to their experience.

- **Friends tab** — appears in the app bar once signed in, with a friends list, incoming/outgoing request management, a username search, and a read-only friend profile showing shared habits and streaks
- **Habit visibility mode** — choose between sharing all habits automatically or toggling individual habits with a per-row eye icon
- **Nudges** — send a gentle reminder about a friend's shared habit (rate-limited to once per friend per habit per day)
- **Social tab** — splits into *My Habits* (your habits with friends' reaction counts) and *Friends* (an aggregated feed where you can react with a heart or open a comment thread)
- **Activity bell** — badged icon in the app bar showing who reacted to or commented on your habits

All social data is stored in Supabase and protected by Row Level Security. Personal habit data remains local and offline regardless of social settings.


### 📱 Core Tracking

- **Multiple completion types**: yes/no check, numeric progress, skip (doesn't break streaks)
- **Notes & comments**: add context to each check-in
- **Smart reminders**: gentle nudges at the right time
- **Calendar view**: see streaks and completions on a scrollable grid
- **Categories**: group habits by theme

### 🎨 Personalization

- Dark and Light themes
- Custom check, fail, and skip button colours
- Drag-and-drop habit reordering
- Categories with custom icons

### 🔒 Privacy & Control

- **Offline first**: everything works without an internet connection
- **Biometric lock**: Face ID, Touch ID, or passcode
- **Export & backup**: own your data, always
- **Archive**: pause habits without losing history
- **Open source**: GPL-3.0 licensed, auditable, forkable

### 🌍 Translations

Community-contributed translations via [Weblate](https://hosted.weblate.org/projects/habo/). Want to help bring Habo to your language? No coding required.

---

## Building from Source

**Requirements**
- Flutter 3.x
- Dart SDK (bundled with Flutter)
- Android Studio or Xcode for device targets

```bash
git clone https://github.com/HyTechster/Habo-Assignment.git
cd Habo-Assignment
flutter pub get
flutter run
```

---

## Contributing

Contributions are welcome and appreciated. Here's how to help:

- **Bug reports & feature requests** → [Open an issue](https://github.com/xpavle00/Habo/issues)
- **Code contributions** → Fork, branch, PR; please open an issue first for large changes
- **Translations** → Join the project on [Weblate](https://hosted.weblate.org/projects/habo/) — no coding required

Please read [CONTRIBUTING.md](CONTRIBUTING.md) before submitting a pull request.

---

## Support the Project

Habo is a one-person open-source project. If it's useful to you, consider supporting its development:

- ⭐ Star the repo: it helps others find the project
- ☕ [Buy me a coffee](https://buymeacoffee.com/peterpavlenko)
- 💬 Leave a review on the [App Store](https://apps.apple.com/us/app/habo-habit-tracker/id1670223360) or [Google Play](https://play.google.com/store/apps/details?id=com.pavlenko.Habo)

---

## License

Habo is released under the [GNU General Public License v3.0](LICENSE).

---

<div align="center">

Made with ❤️ by [Peter Pavlenko](https://github.com/xpavle00)

</div>
