import "dotenv/config";

export async function detectLabels(imageBuffer) {
  const apiKey = process.env.GOOGLE_VISION_API_KEY;
  if (!apiKey) {
    throw new Error('GOOGLE_VISION_API_KEY environment variable is not set');
  }

  const body = {
    requests: [{
      image: { content: imageBuffer.toString('base64') },
      features: [{ type: 'LABEL_DETECTION', maxResults: 10 }],
    }],
  };

  const response = await fetch(
    `https://vision.googleapis.com/v1/images:annotate?key=${apiKey}`,
    {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(body),
    }
  );

  if (!response.ok) {
    const error = await response.text();
    throw new Error(`Google Vision API error (${response.status}): ${error}`);
  }

  const data = await response.json();
  return data.responses[0]?.labelAnnotations || [];
}

export function detectLabelsMock() {
  return [
    { description: 'Headphones', score: 0.95 },
    { description: 'Audio equipment', score: 0.88 },
    { description: 'Electronics', score: 0.82 },
    { description: 'Gadget', score: 0.75 },
  ];
}
