# TTS Alarm ⏰🗣️

A modern, smart alarm clock app for Android built with Flutter that speaks your reminders out loud using Text-to-Speech (TTS). Never wake up wondering why your alarm is ringing — **TTS Alarm** speaks your custom reminder message clearly and repeatedly until you wake up!

---

## ✨ Features

- 🗣️ **Speaking Alarms (TTS)**: Type any message (e.g., *"Good morning Balram, time for your morning run!"* or *"Take your medicine"*) and the app will speak it when the alarm rings.
- 🎚️ **Customizable Voice Settings**:
  - Adjustable **Volume** with real-time voice preview.
  - **Speech Rate (Speed)** and **Pitch** controls.
  - Support for multiple languages (English, Hindi, etc.) and system voices.
  - Interactive **Voice Test** button with animated play/pause indicator.
- 🔒 **Reliable Wake-up & Lock Screen Support**:
  - Automatically wakes the device screen even if the phone is locked or sleeping.
  - Full-screen Ringing UI with **Snooze** and **Dismiss** controls.
  - Works smoothly when the screen is active or unlocked.
- 🔁 **Flexible Scheduling**:
  - One-time or recurring alarms for specific days of the week (Mon–Sun).
  - Quick toggle to turn alarms on or off.
- 🎨 **Modern Dark Aesthetic**:
  - Crafted with a sleek deep-slate and violet/indigo theme.
  - Smooth micro-interactions, clean cards, and responsive layouts.
- 🔋 **Battery-Friendly & Offline**:
  - Runs locally on your device without needing an active internet connection.
  - Respects Android power-saving rules while ensuring alarms fire right on time.

---

## 📱 Screenshots

> *Add your app screenshots here*
<!-- 
| Alarm List | Create / Edit Alarm | Ringing Screen |
|:---:|:---:|:---:|
| <img src="screenshots/alarm_list.png" width="220" /> | <img src="screenshots/create_alarm.png" width="220" /> | <img src="screenshots/ring_screen.png" width="220" /> |
-->

---

## 🚀 Getting Started

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (v3.10.0 or higher)
- Android Studio or VS Code with Flutter extension
- An Android device (API 24+) or Emulator

### Installation

1. **Clone the repository:**
   ```bash
   git clone https://github.com/Balramsingh12233/TTS-Based-Alarm-App.git
   cd TTS-Based-Alarm-App
   ```

2. **Install dependencies:**
   ```bash
   flutter pub get
   ```

3. **Run launcher icon generator (if updating icons):**
   ```bash
   dart run flutter_launcher_icons
   ```

4. **Run the app:**
   ```bash
   flutter run
   ```

---

## ⚙️ Permissions Used

To make sure your alarms ring accurately on Android (even when the phone is locked or deep in sleep), the app uses the following permissions:

| Permission | Why It's Needed |
|---|---|
| `SCHEDULE_EXACT_ALARM` | Guarantees alarms ring at the exact minute without system delays. |
| `USE_FULL_SCREEN_INTENT` | Displays the ringing screen over the lock screen. |
| `WAKE_LOCK` | Wakes the screen when the alarm triggers. |
| `SYSTEM_ALERT_WINDOW` | Allows alarm alerts to appear over other apps if your phone is unlocked. |
| `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` | Prevents aggressive battery savers from killing background alarm services. |

---

## 🛠️ Tech Stack & Packages

- **Framework**: [Flutter](https://flutter.dev) (Dart)
- **Alarm Scheduling**: [`alarm`](https://pub.dev/packages/alarm)
- **Text-to-Speech**: [`flutter_tts`](https://pub.dev/packages/flutter_tts)
- **Local Storage**: [`shared_preferences`](https://pub.dev/packages/shared_preferences)
- **Permissions**: [`permission_handler`](https://pub.dev/packages/permission_handler)
- **Date & Time Formatting**: [`intl`](https://pub.dev/packages/intl)
- **Icon Generation**: [`flutter_launcher_icons`](https://pub.dev/packages/flutter_launcher_icons)

---

## 💡 How It Works

1. **Set your Alarm**: Choose your desired time and repeat schedule.
2. **Personalize the Voice**: Enter your reminder message and adjust volume, pitch, or speed.
3. **Save**: The alarm is registered with the system alarm manager.
4. **Wake Up**: When the time arrives, the device wakes up, presents the full-screen alarm screen, and your phone speaks the reminder message until dismissed or snoozed.

---

## 🤝 Contributing

Contributions, issues, and feature requests are always welcome! Feel free to check the [issues page](https://github.com/Balramsingh12233/TTS-Based-Alarm-App/issues).

---

## 📄 License

This project is open source and available under the [MIT License](LICENSE).
