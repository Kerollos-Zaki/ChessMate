#define MOTOR_A_STEP    7    
#define MOTOR_A_DIR     4
#define MOTOR_B_STEP    6    
#define MOTOR_B_DIR     3

#define LIMIT_X         9    // Limit Switch X
#define LIMIT_Y         10   // Limit Switch Y

long totalStepsX = 0;
long totalStepsY = 0;

bool xFinished = false;
bool yFinished = false;

void setup() {
  Serial.begin(9600);
  
  pinMode(MOTOR_A_STEP, OUTPUT);
  pinMode(MOTOR_A_DIR,  OUTPUT);
  pinMode(MOTOR_B_STEP, OUTPUT);
  pinMode(MOTOR_B_DIR,  OUTPUT);

  pinMode(LIMIT_X, INPUT_PULLUP);
  pinMode(LIMIT_Y, INPUT_PULLUP);

  Serial.println("=== X & Y Axis Step Calibration Tool ===");
  Serial.println("Make sure magnet is at the far diagonal end (Max X and Max Y).");
  Serial.println("Starting in 5 seconds... Hands away!");
  
  delay(5000); 
  Serial.println("Moving X-axis and counting steps...");
}

void loop() {
  // ---------------------------------------------------------
  // PHASE 1: Calibrate X-Axis
  // ---------------------------------------------------------
  if (!xFinished) {
    if (digitalRead(LIMIT_X) == HIGH) {
      
      // X-Axis Movement
      digitalWrite(MOTOR_A_DIR, HIGH); 
      digitalWrite(MOTOR_B_DIR, HIGH);  

      digitalWrite(MOTOR_A_STEP, HIGH);
      digitalWrite(MOTOR_B_STEP, HIGH);
      delayMicroseconds(1000);
      digitalWrite(MOTOR_A_STEP, LOW);
      digitalWrite(MOTOR_B_STEP, LOW);
      delayMicroseconds(1000);
      
      totalStepsX++;
      
    } else {
      xFinished = true;
      
      Serial.println("\n✅ STOP! X Limit Switch Hit.");
      Serial.print("Total Steps across X-axis: ");
      Serial.println(totalStepsX);
      
      float stepsPerSquareX = totalStepsX / 8.0;
      
      Serial.println("---------------------------------");
      Serial.print("🎯 EXACT X STEPS PER SQUARE: ");
      Serial.println(stepsPerSquareX);
      Serial.println("---------------------------------");
      
      delay(2000); // 2-second pause before starting Y
      Serial.println("\nMoving Y-axis and counting steps...");
    }
  } 
  // ---------------------------------------------------------
  // PHASE 2: Calibrate Y-Axis
  // ---------------------------------------------------------
  else if (!yFinished) {
    if (digitalRead(LIMIT_Y) == HIGH) {
      
      // Y-Axis Movement
      // Note: Depending on your specific motor wiring and CoreXY setup, 
      // you usually need opposite directions to move the other axis. 
      // Change these HIGH/LOW states if the carriage moves diagonally.
      digitalWrite(MOTOR_A_DIR, HIGH); 
      digitalWrite(MOTOR_B_DIR, LOW);  

      digitalWrite(MOTOR_A_STEP, HIGH);
      digitalWrite(MOTOR_B_STEP, HIGH);
      delayMicroseconds(1000);
      digitalWrite(MOTOR_A_STEP, LOW);
      digitalWrite(MOTOR_B_STEP, LOW);
      delayMicroseconds(1000);
      
      totalStepsY++;
      
    } else {
      yFinished = true;
      
      Serial.println("\n✅ STOP! Y Limit Switch Hit.");
      Serial.print("Total Steps across Y-axis: ");
      Serial.println(totalStepsY);
      
      float stepsPerSquareY = totalStepsY / 8.0;
      
      Serial.println("---------------------------------");
      Serial.print("🎯 EXACT Y STEPS PER SQUARE: ");
      Serial.println(stepsPerSquareY);
      Serial.println("---------------------------------");
      
      Serial.println("\n🎉 Full XY Calibration Complete!");
    }
  }
}
