# 🚀 Firebase Notes & Productivity Suite

A premium, cross-platform productivity application built with **Flutter** and **Firebase**. Seamlessly manage your notes, tasks, and focus sessions with a high-end, responsive UI.

---

## ✨ Screens & States

| Dashboard (Notes) | Focus Timer | Todo List |
| :---: | :---: | :---: |
| ![Dashboard](screenshots/mobile_dashboard.png) | ![Focus](screenshots/mobile_focus.png) | ![Todos](screenshots/mobile_todos.png) |

> [!TIP]
> **Search Anywhere**: Use the global search overlay to find anything across your notes and tasks instantly.
| ![Search Overlay](screenshots/mobile_search.png) |

---

## 📖 App Guide

### 1. Smart Notes System
*   **Staggered Layout**: View your notes in a modern, dynamic grid grid that adapts to content length.
*   **Color Coding**: Organize visually by assigning vibrant colors (Slate, Purple, Pink, Emerald, Amber, Teal).
*   **Pinning**: Keep your most important thoughts at the very top.
*   **Live Filtering**: Filter by color or interactive hashtags (#tasks, #ideas, etc.).
*   **Gestures**: Swipe to delete or use the quick-action menu for copying to clipboard.

### 2. Focus Management (Pomodoro)
*   **Immersive Timer**: Use the 25/5 Pomodoro technique to boost productivity.
*   **Mode Toggling**: Seamlessly switch between Focus and Break modes.
*   **Live Analytics**: Track your focus sessions over time with built-in activity charts.

### 3. Integrated Todo List
*   **Quick Entry**: Add tasks on the fly with the sleek input bar.
*   **Status Tracking**: Mark tasks as complete with satisfying animations.
*   **Cloud Sync**: All tasks are synced in real-time to Firebase Firestore.

---

## 🛠️ Tech Stack

*   **Frontend**: [Flutter](https://flutter.dev) (Dart)
*   **Backend**: [Firebase](https://firebase.google.com)
    *   **Firestore**: Real-time NoSQL database.
    *   **Auth**: Seamless Anonymous Authentication for guest access.
*   **Styling**: 
    *   **Google Fonts**: Outfit Typography.
    *   **Custom UI**: Glassmorphism, Neon Glows, and Staggered Masonry Grids.

---

## 🚀 Getting Started

### Prerequisites
*   Flutter SDK (^3.11.4)
*   Firebase Project

### Setup
1.  **Clone the repo**:
    ```bash
    git clone <your-repo-url>
    ```
2.  **Install dependencies**:
    ```bash
    flutter pub get
    ```
3.  **Firebase Config**:
    *   Run `flutterfire configure` or replace `lib/firebase_options.dart` with your project's credentials.
    *   Enable **Anonymous Authentication** in your Firebase Console.
4.  **Launch**:
    ```bash
    flutter run
    ```

---

## 🎨 Aesthetic & Mobile-First Design
Designed for **Total Immersion** on mobile and web. Featuring:
- **Responsive Layout**: Optimized for mobile screen ratios (390x844+).
- **OLED Optimized**: Deep blacks and slate tones for premium readability.
- **Glassmorphism**: Translucent navigation and overlays for a high-end feel.
- **Micro-animations**: Smooth transitions between notes, tasks, and timer modes.

---


