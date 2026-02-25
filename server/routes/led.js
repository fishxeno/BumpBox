import { Router } from 'express';
import { controlLED } from '../services/mqttService.js';

const router = Router();

router.get('/api/led/:state', async (req, res) => {
  const state = req.params.state;

  if (state !== 'on' && state !== 'off') {
    return res.status(400).json({ error: 'State must be "on" or "off"' });
  }

  try {
    await controlLED(state);
    return res.status(200).json({
      success: true,
      message: `LED turned ${state}`,
      topic: 'bumpbox/led',
      payload: state,
    });
  } catch (err) {
    return res.status(500).json({ error: 'MQTT publish failed', details: err.message });
  }
});

export default router;
