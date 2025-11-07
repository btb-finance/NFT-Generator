import type { CatTraits, NFTMetadata, Trait } from './types';
import {
  BACKGROUNDS,
  BODY_COLORS,
  EYE_COLORS,
  ACCESSORIES,
  EXPRESSIONS,
  PATTERNS,
  BACKGROUND_COLORS,
  BODY_COLOR_CODES,
  EYE_COLOR_CODES
} from './traits';
import { PixelCanvas, drawCatBody, drawCatFace, drawAccessory } from './pixelArt';

export class NFTGenerator {
  private usedCombinations: Set<string> = new Set();

  private selectTrait(traits: Trait[]): string {
    // Weighted random selection based on rarity
    // Lower rarity = more common
    const weights = traits.map(t => 100 - t.rarity);
    const totalWeight = weights.reduce((a, b) => a + b, 0);
    let random = Math.random() * totalWeight;

    for (let i = 0; i < traits.length; i++) {
      random -= weights[i];
      if (random <= 0) {
        return traits[i].name;
      }
    }

    return traits[0].name;
  }

  generateTraits(): CatTraits {
    let attempts = 0;
    const maxAttempts = 1000;

    while (attempts < maxAttempts) {
      const traits: CatTraits = {
        background: this.selectTrait(BACKGROUNDS),
        bodyColor: this.selectTrait(BODY_COLORS),
        eyeColor: this.selectTrait(EYE_COLORS),
        accessory: this.selectTrait(ACCESSORIES),
        expression: this.selectTrait(EXPRESSIONS),
        pattern: this.selectTrait(PATTERNS)
      };

      const combination = JSON.stringify(traits);
      if (!this.usedCombinations.has(combination)) {
        this.usedCombinations.add(combination);
        return traits;
      }

      attempts++;
    }

    throw new Error('Unable to generate unique combination after max attempts');
  }

  generateImage(traits: CatTraits): string {
    const canvas = new PixelCanvas(24, 24, 20);

    // Fill background
    const bgColor = BACKGROUND_COLORS[traits.background] || '#87CEEB';
    canvas.fillRect(0, 0, 24, 24, bgColor);

    // Draw cat
    const bodyColor = BODY_COLOR_CODES[traits.bodyColor] || '#FF8C42';
    drawCatBody(canvas, bodyColor, traits.pattern);

    // Draw face
    const eyeColor = EYE_COLOR_CODES[traits.eyeColor] || '#00FF00';
    drawCatFace(canvas, eyeColor, traits.expression);

    // Draw accessory
    if (traits.accessory !== 'None') {
      drawAccessory(canvas, traits.accessory);
    }

    return canvas.toSVG();
  }

  generateMetadata(traits: CatTraits, edition: number): NFTMetadata {
    return {
      name: `Pixel Cat #${edition}`,
      description: `A unique pixel art cat from the Pixel Cats NFT collection. Each cat is procedurally generated with rare traits and accessories.`,
      image: `ipfs://YOUR_CID_HERE/${edition}.png`,
      edition,
      attributes: [
        { trait_type: 'Background', value: traits.background },
        { trait_type: 'Body Color', value: traits.bodyColor },
        { trait_type: 'Eye Color', value: traits.eyeColor },
        { trait_type: 'Accessory', value: traits.accessory },
        { trait_type: 'Expression', value: traits.expression },
        { trait_type: 'Pattern', value: traits.pattern }
      ]
    };
  }

  calculateRarityScore(traits: CatTraits): number {
    const getTraitRarity = (traitList: Trait[], value: string): number => {
      const trait = traitList.find(t => t.name === value);
      return trait ? trait.rarity : 0;
    };

    return (
      getTraitRarity(BACKGROUNDS, traits.background) +
      getTraitRarity(BODY_COLORS, traits.bodyColor) +
      getTraitRarity(EYE_COLORS, traits.eyeColor) +
      getTraitRarity(ACCESSORIES, traits.accessory) +
      getTraitRarity(EXPRESSIONS, traits.expression) +
      getTraitRarity(PATTERNS, traits.pattern)
    );
  }

  reset() {
    this.usedCombinations.clear();
  }
}
