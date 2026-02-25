import mqtt from 'mqtt';

// ---------- Configuration ----------
const BROKER_URL = 'mqtt://broker.hivemq.com:1883';
const TOPIC_LED  = 'bumpbox/led';

// ---------- Singleton MQTT Client ----------
let client = null;

function getClient() {
  if (client && client.connected) return client;

  client = mqtt.connect(BROKER_URL, {
    clientId: `bumpbox-server-${Math.random().toString(16).slice(2, 8)}`,
    clean: true,
    connectTimeout: 5000,
    reconnectPeriod: 5000,
  });

  client.on('connect', () => {
    console.log('[MQTT] Connected to broker:', BROKER_URL);
  });

  client.on('error', (err) => {
    console.error('[MQTT] Error:', err.message);
  });

  client.on('offline', () => {
    console.log('[MQTT] Client offline, will reconnect...');
  });

  return client;
}

// ---------- Public API ----------

/**
 * Publish LED control command.
 * @param {'on' | 'off'} state
 */
export function controlLED(state) {
  return new Promise((resolve, reject) => {
    const payload = state === 'on' ? 'on' : 'off';
    const mqttClient = getClient();

    mqttClient.publish(TOPIC_LED, payload, { qos: 1 }, (err) => {
      if (err) {
        console.error('[MQTT] Publish failed:', err.message);
        reject(err);
      } else {
        console.log(`[MQTT] Published to ${TOPIC_LED}: ${payload}`);
        resolve();
      }
    });
  });
}

// Connect eagerly when the module is first imported
getClient();
