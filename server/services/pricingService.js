import { readFileSync } from 'fs';
import { resolve, dirname } from 'path';
import { fileURLToPath } from 'url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const priceMap = JSON.parse(
  readFileSync(resolve(__dirname, '..', 'data', 'priceMap.json'), 'utf-8')
);

export function estimatePrice(labels) {
  for (const label of labels) {
    const key = label.description;
    if (priceMap[key]) {
      return {
        label: key,
        category: priceMap[key].category,
        minPrice: priceMap[key].minPrice,
        maxPrice: priceMap[key].maxPrice,
        confidence: Math.round(label.score * 100),
      };
    }
  }

  return {
    label: labels[0]?.description || 'Unknown',
    category: 'Uncategorized',
    minPrice: 5,
    maxPrice: 20,
    confidence: Math.round((labels[0]?.score || 0) * 100),
  };
}
