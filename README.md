# Chess Mate - Automated Chessboard System ♟️

Welcome to the official repository for **Chess Mate**, an integrated hardware and software system for an automated chessboard. 

This repository acts as a **monorepo**, housing the cross-platform mobile application alongside the embedded systems code required for the chessboard's physical operation.

## 📂 Repository Layout Explained

To keep the development workflow straightforward, the **root directory of this repository serves as the main Flutter project**. The hardware-specific codes are neatly organized into their own dedicated folders at the root level.

Here is how the project is structured:

### 1. Mobile Application (Root Directory)
The root of this repository contains the complete Flutter application and Firebase configurations. 
* **`lib/`**: Contains the core Dart source code, UI/UX designs, and game logic for the mobile app.
* **`assets/`**: Images, icons, and other static resources.
* **`android/`, `ios/`, `web/`, `linux/`, `macos/`, `windows/`**: Platform-specific build configurations.
* **`pubspec.yaml` & `firebase.json`**: App dependencies and Firebase backend configurations.

### 2. Sensor Management (Raspberry Pi)
* **`Rassbery pi Codes/`**: This folder contains the scripts executed by the Raspberry Pi. The Raspberry Pi acts as the brain for sensory input, strictly responsible for listening to the 64-coordinate reed switch matrix and processing board state changes.

### 3. Movement Execution (Arduino Nano)
* **`Arduino Code/`**: This folder contains the C/C++ (`.ino`) firmware for the Arduino Nano. The Arduino is strictly responsible for physical execution—driving the motors and mechanical components to physically move the chess pieces across the board based on instructions.

---
