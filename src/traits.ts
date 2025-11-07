import type { Trait } from './types';

export const BACKGROUNDS: Trait[] = [
  { name: 'Sky Blue', rarity: 20 },
  { name: 'Sunset Orange', rarity: 30 },
  { name: 'Forest Green', rarity: 25 },
  { name: 'Deep Purple', rarity: 40 },
  { name: 'Pink Dream', rarity: 35 },
  { name: 'Galaxy Black', rarity: 60 },
  { name: 'Golden Hour', rarity: 70 },
  { name: 'Cyber Neon', rarity: 80 },
  { name: 'Rainbow', rarity: 90 },
  { name: 'Cosmic Void', rarity: 95 }
];

export const BODY_COLORS: Trait[] = [
  { name: 'Orange Tabby', rarity: 15 },
  { name: 'Black', rarity: 20 },
  { name: 'White', rarity: 25 },
  { name: 'Gray', rarity: 18 },
  { name: 'Calico', rarity: 35 },
  { name: 'Siamese', rarity: 40 },
  { name: 'Blue Russian', rarity: 50 },
  { name: 'Golden', rarity: 65 },
  { name: 'Pink Bubblegum', rarity: 75 },
  { name: 'Cyber Chrome', rarity: 85 },
  { name: 'Rainbow Holographic', rarity: 95 }
];

export const EYE_COLORS: Trait[] = [
  { name: 'Green', rarity: 20 },
  { name: 'Blue', rarity: 25 },
  { name: 'Yellow', rarity: 22 },
  { name: 'Brown', rarity: 18 },
  { name: 'Amber', rarity: 30 },
  { name: 'Heterochromia', rarity: 60 },
  { name: 'Red Laser', rarity: 70 },
  { name: 'Diamond White', rarity: 80 },
  { name: 'Galaxy', rarity: 90 }
];

export const ACCESSORIES: Trait[] = [
  { name: 'None', rarity: 10 },
  { name: 'Bow Tie', rarity: 25 },
  { name: 'Collar', rarity: 20 },
  { name: 'Sunglasses', rarity: 40 },
  { name: 'Crown', rarity: 55 },
  { name: 'Top Hat', rarity: 50 },
  { name: 'Bandana', rarity: 30 },
  { name: 'Pirate Eye Patch', rarity: 60 },
  { name: 'VR Headset', rarity: 75 },
  { name: 'Laser Eyes', rarity: 85 },
  { name: 'Astronaut Helmet', rarity: 90 },
  { name: 'Golden Crown', rarity: 95 }
];

export const EXPRESSIONS: Trait[] = [
  { name: 'Happy', rarity: 15 },
  { name: 'Sleepy', rarity: 20 },
  { name: 'Grumpy', rarity: 25 },
  { name: 'Surprised', rarity: 30 },
  { name: 'Winking', rarity: 35 },
  { name: 'Loving', rarity: 40 },
  { name: 'Mischievous', rarity: 45 },
  { name: 'Derpy', rarity: 50 },
  { name: 'Cool', rarity: 60 },
  { name: 'Alien', rarity: 85 }
];

export const PATTERNS: Trait[] = [
  { name: 'Solid', rarity: 15 },
  { name: 'Striped', rarity: 25 },
  { name: 'Spotted', rarity: 30 },
  { name: 'Tuxedo', rarity: 35 },
  { name: 'Patches', rarity: 40 },
  { name: 'Tiger Stripes', rarity: 50 },
  { name: 'Leopard Spots', rarity: 60 },
  { name: 'Glitch', rarity: 75 },
  { name: 'Pixel Matrix', rarity: 85 },
  { name: 'Cosmic Swirl', rarity: 92 }
];

export const BACKGROUND_COLORS: { [key: string]: string } = {
  'Sky Blue': '#87CEEB',
  'Sunset Orange': '#FF6B35',
  'Forest Green': '#228B22',
  'Deep Purple': '#4B0082',
  'Pink Dream': '#FFB6C1',
  'Galaxy Black': '#0D0221',
  'Golden Hour': '#FFD700',
  'Cyber Neon': '#00FFFF',
  'Rainbow': '#FF69B4',
  'Cosmic Void': '#000000'
};

export const BODY_COLOR_CODES: { [key: string]: string } = {
  'Orange Tabby': '#FF8C42',
  'Black': '#2C2C2C',
  'White': '#F5F5F5',
  'Gray': '#808080',
  'Calico': '#FF8C42',
  'Siamese': '#D4A574',
  'Blue Russian': '#6495ED',
  'Golden': '#FFD700',
  'Pink Bubblegum': '#FF69B4',
  'Cyber Chrome': '#C0C0C0',
  'Rainbow Holographic': '#FF00FF'
};

export const EYE_COLOR_CODES: { [key: string]: string } = {
  'Green': '#00FF00',
  'Blue': '#0000FF',
  'Yellow': '#FFFF00',
  'Brown': '#8B4513',
  'Amber': '#FFBF00',
  'Heterochromia': '#00FF00',
  'Red Laser': '#FF0000',
  'Diamond White': '#FFFFFF',
  'Galaxy': '#9370DB'
};
