# ♟️ ChessMate: Fully Automated Smart Chessboard

![Project Status](https://img.shields.io/badge/Status-In_Development-orange)
![Hardware](https://img.shields.io/badge/Hardware-Core--XY-blue)
![App](https://img.shields.io/badge/App-Flutter_%7C_Firebase-FFCA28)
![AI](https://img.shields.io/badge/AI-Stockfish_%7C_A*-success)

**ChessMate** is a fully automated, internet-connected physical chessboard built as a graduation project. It bridges the gap between traditional over-the-board chess and online matchmaking. Using a hidden Core-XY mechanical system and an electromagnet, the board autonomously moves the opponent's physical pieces in real-time, syncing directly with a custom mobile application and powered by advanced AI and pathfinding algorithms.

---

## ✨ Key Features
* **Autonomous Movement:** Ghost-like movement of chess pieces using a high-precision Core-XY mechanism and electromagnet.
* **Smart Routing (A* Algorithm):** Implements the A* (A-Star) pathfinding algorithm to calculate collision-free routes for captured and moving pieces across the board.
* **Powered by Stockfish:** Integrated with the open-source Stockfish chess engine to allow users to play against a world-class AI directly on the physical board.
* **Online Matchmaking:** Play against friends or online opponents globally via Firebase.
* **Mobile App Integration:** A dedicated cross-platform app ("ChessMate") built with Flutter to handle user accounts, game logic, and board communication.

---

## 🛠️ Tech Stack & Architecture

### 1. Hardware & Mechanics
* **Processing & Logic:** **Raspberry Pi 4** (handles App communication, Stockfish AI, and A* routing).
* **Motion Controller:** **Arduino Nano** (handles stepper motor steps and electromagnet triggers).
* **Motion System:** Core-XY kinematics.
* **Frame:** 2020 V-Slot Aluminum Extrusions.
* **Drive System:** 2x NEMA 17 Stepper Motors with GT2 Timing Belts.
* **Actuation:** Electromagnet mounted on a custom 3D-printed central trolley.

### 2. Software & Firmware
* **Firmware:** Custom **Arduino C/C++** for precise stepper control and serial communication.
* **Algorithms:** **A* (A-Star)** pathfinding algorithm.
* **Chess Engine:** **Stockfish**.
* **Mobile Application:** **Flutter** (iOS & Android).
* **Backend:** **Firebase** (Realtime Database & Authentication).

---

## 🚀 Current Progress
- [x] Hardware Design & 3D Printing.
- [x] Sub-assemblies construction (Trolley, Gantries, Motor Mounts).
- [x] Frame assembly and V-Wheel tuning.
- [x] Mobile App UI and Firebase Backend logic.
- [ ] Belt routing and tensioning.
- [ ] Serial communication between Raspberry Pi and Arduino Nano.
- [ ] A* algorithm and Stockfish integration calibration.

---

## 📸 Gallery
* <img width="636" height="786" alt="image" src="https://github.com/user-attachments/assets/aa529fed-845d-46aa-9592-9e694df77c45" />
* - The Core-XY mechanism and frame assembly.
* <img width="1157" height="646" alt="image" src="https://github.com/user-attachments/assets/fda41ce4-000a-4a25-a480-454efa3b1990" />
* - The Flutter mobile app interface.

---

## 👥 Credits & Acknowledgements

**Project Lead & Full-Stack Developer:**
* **[Kerollos Bassem]** - Team Leader (Responsible for Mechanical Assembly, Hardware Integration, Software Development, and Pathfinding Logic).

**Supervision & Guidance:**
* **Supervisor:** Dr. Hafez Selim
* **Teaching Assistants:** Eng. Fatma Elwasify & Eng. Ahmed Ibrahim

**Institution:**
* Faculty of Computer Science, **Ain Shams University** - Class of 2025/2026.

---
*Feel free to star ⭐ this repository if you find this project interesting!*
<img width="1157" height="646" alt="image" src="https://github.com/user-attachments/assets/fda41ce4-000a-4a25-a480-454efa3b1990" />


