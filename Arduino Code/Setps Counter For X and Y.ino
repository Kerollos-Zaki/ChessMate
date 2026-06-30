// ── تعريف البينز (CNC Shield V4) ──
#define MOTOR_A_STEP    7    
#define MOTOR_A_DIR     4
#define MOTOR_B_STEP    6    
#define MOTOR_B_DIR     3

#define LIMIT_X         9    // Limit Switch X is on Pin 9

long totalSteps = 0;
bool finished = false;

void setup() {
  Serial.begin(9600);
  
  pinMode(MOTOR_A_STEP, OUTPUT);
  pinMode(MOTOR_A_DIR,  OUTPUT);
  pinMode(MOTOR_B_STEP, OUTPUT);
  pinMode(MOTOR_B_DIR,  OUTPUT);

  // تفعيل المقاومة الداخلية للزرار
  pinMode(LIMIT_X, INPUT_PULLUP);

  Serial.println("=== X-Axis Step Calibration Tool ===");
  Serial.println("Make sure magnet is at the far end of the X-axis.");
  Serial.println("Starting in 5 seconds... Hands away!");
  
  delay(5000); 
  Serial.println("Moving X-axis and counting steps...");
}

void loop() {
  if (finished) {
    return; // لو الاختبار خلص، ميعملش حاجة تاني
  }

  // الزرار بتاعك Normally Open، يعني طول ما هو مش مضغوط بيقرا HIGH
  if (digitalRead(LIMIT_X) == HIGH) {
    
    // عشان نمشي في خط مستقيم على X، الموتورين بيلفوا في نفس الاتجاه
    // لو لقيتها بتمشي العكس (بتبعد عن الزرار)، غير الاتنين HIGH دول لـ LOW
    digitalWrite(MOTOR_A_DIR, HIGH); 
    digitalWrite(MOTOR_B_DIR, HIGH);  

    // تحريك المواتير خطوة واحدة
    digitalWrite(MOTOR_A_STEP, HIGH);
    digitalWrite(MOTOR_B_STEP, HIGH);
    delayMicroseconds(1000); // سرعة الموتور
    digitalWrite(MOTOR_A_STEP, LOW);
    digitalWrite(MOTOR_B_STEP, LOW);
    delayMicroseconds(1000);
    
    totalSteps++; // بنزود خطوة على العداد
    
  } else {
    // الزرار اتداس (قرأ LOW)!
    finished = true;
    
    Serial.println("\n✅ STOP! X Limit Switch Hit.");
    Serial.print("Total Steps across X-axis: ");
    Serial.println(totalSteps);
    
    // بنقسم الخطوات الكلية على 8 مربعات
    float stepsPerSquare = totalSteps / 8.0;
    
    Serial.println("---------------------------------");
    Serial.print("🎯 EXACT X STEPS PER SQUARE: ");
    Serial.println(stepsPerSquare);
    Serial.println("---------------------------------");
  }
}