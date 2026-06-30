// ================================================
//   CoreXY Chess Controller
//   v3.5 — Maximum Magnet Grip Edition
//   Changes:
//   - 8 pulse jolts on pickup
//   - Two intermediate pauses during carry
//   - Very slow carry speed (3500us)
//   - Maximum energize and settle delays
// ================================================
#include <EEPROM.h>

// ── Pins (CNC Shield V4) ──────────────────────────
#define MOTOR_A_STEP    7
#define MOTOR_A_DIR     4
#define MOTOR_B_STEP    6
#define MOTOR_B_DIR     3
#define LIMIT_X         9
#define LIMIT_Y         10
#define MAGNET_PIN      12   // Electromagnet relay/MOSFET gate

// ── Calibration (steps per chess square) ─────────
const float STEPS_PER_SQ_X = 166.38;
const float STEPS_PER_SQ_Y = 187.75;

// ── Speed & Acceleration Settings ────────────────
const int CRUISE_SPEED   = 1000;  // µs — normal travel speed
const int CARRY_SPEED    = 3500;  // µs — very slow when carrying a piece
const int START_SPEED    = 2000;  // µs — ramp start/end speed
const int RAMP_STEPS     = 250;   // steps to spend on accel/decel
const int HOMING_SPEED   = 1200;  // µs — homing speed

// ── Board Limits (chess squares 1–8) ─────────────
const float BOARD_MIN = 1.0;
const float BOARD_MAX = 8.0;

// ── Magnet timing ─────────────────────────────────
const int MAGNET_SETTLE_MS    = 2000; // ms to wait before releasing
const int MAGNET_ENERGIZE_MS  = 800;  // ms after jolt before moving
const int MAGNET_PULSE_ON_MS  = 150;  // ms ON during each jolt pulse
const int MAGNET_PULSE_OFF_MS = 10;   // ms OFF between jolt pulses
const int MAGNET_PULSE_COUNT  = 8;    // number of jolt pulses
const int QUARTER_PAUSE_MS    = 300;  // ms pause at each quarter point

// ── EEPROM Addresses ──────────────────────────────
const int EEPROM_ADDR_X = 0;
const int EEPROM_ADDR_Y = 4;

// ── Machine State ─────────────────────────────────
float current_square_X = 0.0;
float current_square_Y = 0.0;

// ─────────────────────────────────────────────────
//   FORWARD DECLARATIONS
// ─────────────────────────────────────────────────
void homeAll();
void moveToSquare(float target_sq_X, float target_sq_Y, int cruiseUs);
void singleStep(int speedUs);
void savePosition(float x, float y);
void executePieceMove(float x1, float y1, float x2, float y2);
void magnetOn();
void magnetOff();

// ─────────────────────────────────────────────────
//   SETUP
// ─────────────────────────────────────────────────
void setup() {
  Serial.begin(9600);

  pinMode(MOTOR_A_STEP, OUTPUT);
  pinMode(MOTOR_A_DIR,  OUTPUT);
  pinMode(MOTOR_B_STEP, OUTPUT);
  pinMode(MOTOR_B_DIR,  OUTPUT);
  pinMode(MAGNET_PIN,   OUTPUT);
  digitalWrite(MAGNET_PIN, LOW);  // magnet OFF at startup

  // Normally Open limit switches
  pinMode(LIMIT_X, INPUT_PULLUP);
  pinMode(LIMIT_Y, INPUT_PULLUP);

  Serial.println("=== CoreXY Chess Controller v3.5 ===");

  // Restore last known position from EEPROM
  float saved_X, saved_Y;
  EEPROM.get(EEPROM_ADDR_X, saved_X);
  EEPROM.get(EEPROM_ADDR_Y, saved_Y);

  if (!isnan(saved_X) && !isnan(saved_Y) &&
      saved_X >= BOARD_MIN && saved_X <= BOARD_MAX &&
      saved_Y >= BOARD_MIN && saved_Y <= BOARD_MAX) {
    current_square_X = saved_X;
    current_square_Y = saved_Y;
    Serial.print("[INFO] Restored position: X=");
    Serial.print(saved_X);
    Serial.print(" Y=");
    Serial.println(saved_Y);
    if (saved_X < 1.0 || saved_Y < 1.0) {
      moveToSquare(1.0, 1.0, CRUISE_SPEED);
    }
  }

  homeAll();

  Serial.println("-----------------------------------------");
  Serial.println("[READY] Waiting for Pi commands.");
  Serial.println("        Format: x1,y1,x2,y2");
  Serial.println("        Example: 5,2,5,4");
  Serial.println("-----------------------------------------");
}

// ─────────────────────────────────────────────────
//   MAIN LOOP — parse Pi command
// ─────────────────────────────────────────────────
void loop() {
  if (Serial.available() > 0) {
    String command = Serial.readStringUntil('\n');
    command.trim();

    if (command.length() == 0) return;

    // ── Parse x1,y1,x2,y2 ────────────────────────
    int idx1 = command.indexOf(',');
    int idx2 = command.indexOf(',', idx1 + 1);
    int idx3 = command.indexOf(',', idx2 + 1);

    if (idx1 <= 0 || idx2 <= idx1 || idx3 <= idx2) {
      Serial.println("[ERR] Bad format. Expected: x1,y1,x2,y2");
      return;
    }

    float x1 = command.substring(0, idx1).toFloat();
    float y1 = command.substring(idx1 + 1, idx2).toFloat();
    float x2 = command.substring(idx2 + 1, idx3).toFloat();
    float y2 = command.substring(idx3 + 1).toFloat();

    // ── Bounds check all four values ──────────────
    if (x1 < BOARD_MIN || x1 > BOARD_MAX ||
        y1 < BOARD_MIN || y1 > BOARD_MAX ||
        x2 < BOARD_MIN || x2 > BOARD_MAX ||
        y2 < BOARD_MIN || y2 > BOARD_MAX) {
      Serial.print("[ERR] Out of bounds! All values must be ");
      Serial.print(BOARD_MIN);
      Serial.print("-");
      Serial.println(BOARD_MAX);
      return;
    }

    Serial.print("[MOVE] Received: (");
    Serial.print(x1); Serial.print(","); Serial.print(y1);
    Serial.print(") -> (");
    Serial.print(x2); Serial.print(","); Serial.print(y2);
    Serial.println(")");

    executePieceMove(x1, y1, x2, y2);

    Serial.println("[DONE] Move complete. Waiting for next command.\n");
  }
}

// ─────────────────────────────────────────────────
//   MAGNET ON — pulse jolt then hold
//   Pulses the coil rapidly to give strong
//   initial kick, then holds it steady
// ─────────────────────────────────────────────────
void magnetOn() {
  Serial.println("[MAGNET] Jolting coil...");
  for (int i = 0; i < MAGNET_PULSE_COUNT; i++) {
    digitalWrite(MAGNET_PIN, HIGH);
    delay(MAGNET_PULSE_ON_MS);
    digitalWrite(MAGNET_PIN, LOW);
    delay(MAGNET_PULSE_OFF_MS);
  }
  // Hold ON after jolt
  digitalWrite(MAGNET_PIN, HIGH);
  delay(MAGNET_ENERGIZE_MS);  // wait for full grip before moving
  Serial.println("[MAGNET] ON and gripping.");
}

// ─────────────────────────────────────────────────
//   MAGNET OFF — clean release
// ─────────────────────────────────────────────────
void magnetOff() {
  digitalWrite(MAGNET_PIN, LOW);
  Serial.println("[MAGNET] OFF.");
}

// ─────────────────────────────────────────────────
//   PIECE MOVE SEQUENCE
//   1. Move to (x1,y1)       magnet OFF
//   2. Magnet jolt + ON      grab piece
//   3. Move to 33% point     slow carry
//   4. Pause                 re-settle grip
//   5. Move to 66% point     slow carry
//   6. Pause                 re-settle grip
//   7. Move to (x2,y2)       slow carry
//   8. Settle delay
//   9. Magnet OFF            release piece
// ─────────────────────────────────────────────────
void executePieceMove(float x1, float y1, float x2, float y2) {

  // Coordinates from Pi are correct — no mirroring needed
  Serial.print("[MAP] Moving: (");
  Serial.print(x1); Serial.print(","); Serial.print(y1);
  Serial.print(") -> (");
  Serial.print(x2); Serial.print(","); Serial.print(y2);
  Serial.println(")");

  // Step 1 — navigate to source square, magnet off
  Serial.println("[1/9] Navigating to source square...");
  magnetOff();
  moveToSquare(x1, y1, CRUISE_SPEED);

  // Step 2 — jolt magnet to grab piece
  Serial.println("[2/9] Grabbing piece...");
  magnetOn();

  // Step 3 — move to first quarter (33%) slowly
  Serial.println("[3/9] Carrying to first waypoint...");
  float q1X = x1 + (x2 - x1) * 0.33;
  float q1Y = y1 + (y2 - y1) * 0.33;
  moveToSquare(q1X, q1Y, CARRY_SPEED);

  // Step 4 — pause at first waypoint
  Serial.println("[4/9] Waypoint 1 pause...");
  delay(QUARTER_PAUSE_MS);

  // Step 5 — move to second quarter (66%) slowly
  Serial.println("[5/9] Carrying to second waypoint...");
  float q2X = x1 + (x2 - x1) * 0.66;
  float q2Y = y1 + (y2 - y1) * 0.66;
  moveToSquare(q2X, q2Y, CARRY_SPEED);

  // Step 6 — pause at second waypoint
  Serial.println("[6/9] Waypoint 2 pause...");
  delay(QUARTER_PAUSE_MS);

  // Step 7 — carry to final destination slowly
  Serial.println("[7/9] Carrying to destination...");
  moveToSquare(x2, y2, CARRY_SPEED);

  // Step 8 — settle delay so piece lands cleanly
  Serial.println("[8/9] Settling...");
  delay(MAGNET_SETTLE_MS);

  // Step 9 — release piece
  Serial.println("[9/9] Releasing piece.");
  magnetOff();

  // Save final position to EEPROM
  savePosition(x2, y2);
}

// ─────────────────────────────────────────────────
//   HOMING SEQUENCE  (magnet stays OFF)
// ─────────────────────────────────────────────────
void homeAll() {
  Serial.println("[HOME] Homing Y-Axis...");
  while (digitalRead(LIMIT_Y) == HIGH) {
    digitalWrite(MOTOR_A_DIR, HIGH);
    digitalWrite(MOTOR_B_DIR, LOW);
    singleStep(HOMING_SPEED);
  }
  Serial.println("[HOME] Y Homed.");
  delay(300);

  Serial.println("[HOME] Homing X-Axis...");
  while (digitalRead(LIMIT_X) == HIGH) {
    digitalWrite(MOTOR_A_DIR, HIGH);
    digitalWrite(MOTOR_B_DIR, HIGH);
    singleStep(HOMING_SPEED);
  }
  Serial.println("[HOME] X Homed.");
  delay(300);

  current_square_X = 0.0;
  current_square_Y = 0.0;
  Serial.println("[HOME] Origin (0,0) set.");
}

// ─────────────────────────────────────────────────
//   SINGLE STEP HELPER
// ─────────────────────────────────────────────────
void singleStep(int speedUs) {
  digitalWrite(MOTOR_A_STEP, HIGH);
  digitalWrite(MOTOR_B_STEP, HIGH);
  delayMicroseconds(speedUs);
  digitalWrite(MOTOR_A_STEP, LOW);
  digitalWrite(MOTOR_B_STEP, LOW);
  delayMicroseconds(speedUs);
}

// ─────────────────────────────────────────────────
//   EEPROM SAVE
// ─────────────────────────────────────────────────
void savePosition(float x, float y) {
  EEPROM.put(EEPROM_ADDR_X, x);
  EEPROM.put(EEPROM_ADDR_Y, y);
}

// ─────────────────────────────────────────────────
//   CORE MOVE FUNCTION — trapezoidal acceleration
// ─────────────────────────────────────────────────
void moveToSquare(float target_sq_X, float target_sq_Y, int cruiseUs) {

  long target_step_X  = round(target_sq_X * STEPS_PER_SQ_X);
  long target_step_Y  = round(target_sq_Y * STEPS_PER_SQ_Y);
  long current_step_X = round(current_square_X * STEPS_PER_SQ_X);
  long current_step_Y = round(current_square_Y * STEPS_PER_SQ_Y);

  long delta_X = target_step_X - current_step_X;
  long delta_Y = target_step_Y - current_step_Y;

  // CoreXY kinematics
  long motor_A_steps = -delta_X - delta_Y;
  long motor_B_steps = -delta_X + delta_Y;

  if (motor_A_steps == 0 && motor_B_steps == 0) {
    Serial.println("[INFO] Already at target square.");
    return;
  }

  digitalWrite(MOTOR_A_DIR, (motor_A_steps >= 0) ? HIGH : LOW);
  digitalWrite(MOTOR_B_DIR, (motor_B_steps >= 0) ? HIGH : LOW);

  long absA  = abs(motor_A_steps);
  long absB  = abs(motor_B_steps);
  long total = max(absA, absB);

  long errA = total / 2;
  long errB = total / 2;

  long ramp = min((long)RAMP_STEPS, total / 2);

  for (long i = 0; i < total; i++) {

    // ── Trapezoidal speed profile ──────────────────
    int stepSpeed;
    if (ramp == 0) {
      stepSpeed = cruiseUs;
    } else if (i < ramp) {
      stepSpeed = START_SPEED - (int)((long)(START_SPEED - cruiseUs) * i / ramp);
    } else if (i > total - ramp) {
      stepSpeed = START_SPEED - (int)((long)(START_SPEED - cruiseUs) * (total - i) / ramp);
    } else {
      stepSpeed = cruiseUs;
    }

    // ── Bresenham step distribution ───────────────
    bool stepA = false, stepB = false;

    errA -= absA;
    if (errA < 0) { errA += total; stepA = true; }

    errB -= absB;
    if (errB < 0) { errB += total; stepB = true; }

    // ── Pulse motors ──────────────────────────────
    if (stepA) digitalWrite(MOTOR_A_STEP, HIGH);
    if (stepB) digitalWrite(MOTOR_B_STEP, HIGH);
    delayMicroseconds(stepSpeed);
    digitalWrite(MOTOR_A_STEP, LOW);
    digitalWrite(MOTOR_B_STEP, LOW);
    delayMicroseconds(stepSpeed);
  }

  current_square_X = target_sq_X;
  current_square_Y = target_sq_Y;
}