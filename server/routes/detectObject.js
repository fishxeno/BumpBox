import { Router } from 'express';
import multer from 'multer';
import { writeFileSync } from 'fs';
import { detectLabels, detectLabelsMock } from '../services/visionService.js';
import { estimatePrice } from '../services/pricingService.js';
import { storeDetection } from '../storage.js';

const router = Router();

const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 1 * 1024 * 1024 },
  fileFilter: (req, file, cb) => {
    if (file.mimetype === 'image/jpeg' || file.mimetype === 'image/png') {
      cb(null, true);
    } else {
      cb(new Error('Only JPEG and PNG images are allowed'));
    }
  },
});

router.post('/detect-object', upload.single('image'), async (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({ error: 'No image file provided. Send a multipart form with field name "image".' });
    }

    // Save image for debugging (view in server/debug_capture.jpg)
    const debugPath = new URL('../debug_capture.jpg', import.meta.url).pathname.replace(/^\/([A-Z]:)/, '$1');
    writeFileSync(debugPath, req.file.buffer);
    console.log(`[detect-object] Saved debug image: ${debugPath} (${req.file.buffer.length} bytes)`);

    const useMock = process.env.USE_MOCK_VISION === 'true' || req.query.mock === 'true';

    const labels = useMock
      ? detectLabelsMock()
      : await detectLabels(req.file.buffer);

    const priceEstimate = estimatePrice(labels);

    console.log(`[detect-object] ALL labels from Vision API:`);
    labels.forEach((l, i) => console.log(`  ${i+1}. ${l.description} (${Math.round(l.score * 100)}%)`));
    console.log(`[detect-object] Result: ${priceEstimate.label} (${priceEstimate.confidence}%) | ${priceEstimate.category} | $${priceEstimate.minPrice}-$${priceEstimate.maxPrice}`);

    const detection = {
      label: priceEstimate.label,
      category: priceEstimate.category,
      minPrice: priceEstimate.minPrice,
      maxPrice: priceEstimate.maxPrice,
      confidence: priceEstimate.confidence,
    };

    // Store detection result for Flutter app polling
    const lockerId = req.query.lockerId || req.body.lockerId || 'locker1';
    storeDetection(detection, lockerId, req.file.buffer);

    return res.status(200).json({
      success: true,
      detection,
      allLabels: labels.map(l => ({ description: l.description, score: l.score })),
    });
  } catch (error) {
    console.error('[detect-object] Error:', error.message);
    return res.status(500).json({ error: 'Detection failed', details: error.message });
  }
});

export default router;
