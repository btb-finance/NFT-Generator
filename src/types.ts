export interface Trait {
  name: string;
  rarity: number; // 0-100, higher is rarer
}

export interface CatTraits {
  background: string;
  bodyColor: string;
  eyeColor: string;
  accessory: string;
  expression: string;
  pattern: string;
}

export interface NFTMetadata {
  name: string;
  description: string;
  image: string;
  edition: number;
  attributes: Array<{
    trait_type: string;
    value: string;
  }>;
}

export interface PixelData {
  x: number;
  y: number;
  color: string;
}
