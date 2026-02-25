#define SWITCH_PIN     21    // Microswitch NO terminal
#define RELAY_PIN      16    // Relay IN pin
#define DEBOUNCE_MS    50    // Debounce time (ms)
#define LID_DELAY_MS   500   // Wait for lid to fully settle on switch (ms)
#define SOLENOID_ON_MS 2000  // How long solenoid stays active (ms)

#define RELAY_ON  LOW
#define RELAY_OFF HIGH

int lastSteaadyState      = HIGH;
int lastFlickerableState = HIGH;
int currentState;
unsigned long lastDebounceTime = 0;

void setup() {
  Serial.begin(115200);
  pinMode(SWITCH_PIN, INPUT_PULLUP);
  pinMode(RELAY_PIN, OUTPUT);
  digitalWrite(RELAY_PIN, RELAY_OFF); // Solenoid OFF at boot
}

void loop() {
  currentState = digitalRead(SWITCH_PIN);

  // Debounce logic
  if (currentState != lastFlickerableState) {
    lastDebounceTime = millis();
    lastFlickerableState = currentState;
  }

  if ((millis() - lastDebounceTime) > DEBOUNCE_MS) {

    // Switch CLOSED → lid pressed down (HIGH → LOW)
    if (lastSteadyState == HIGH && currentState == LOW) {
      Serial.println("Switch closed — waiting for lid to settle...");
      delay(LID_DELAY_MS);

      Serial.println("Activating solenoid...");
      digitalWrite(RELAY_PIN, RELAY_ON);   // Solenoid ON
      delay(SOLENOID_ON_MS);               // Hold for 2 seconds
      digitalWrite(RELAY_PIN, RELAY_OFF);  // Solenoid OFF
      Serial.println("Solenoid deactivated.");
    }

    lastSteadyState = currentState;
  }
}