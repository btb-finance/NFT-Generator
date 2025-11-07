import { NFTGenerator } from './generator';
import type { CatTraits } from './types';

export class OnChainEncoder {
  private generator: NFTGenerator;

  constructor() {
    this.generator = new NFTGenerator();
  }

  /**
   * Generate base64 encoded data URI for on-chain storage
   */
  generateDataURI(traits: CatTraits): string {
    const svg = this.generator.generateImage(traits);
    const base64 = Buffer.from(svg).toString('base64');
    return `data:image/svg+xml;base64,${base64}`;
  }

  /**
   * Generate compact on-chain metadata JSON
   */
  generateOnChainMetadata(traits: CatTraits, edition: number): string {
    const svg = this.generator.generateImage(traits);
    const base64 = Buffer.from(svg).toString('base64');

    const metadata = {
      name: `Pixel Cat #${edition}`,
      description: 'A fully on-chain pixel art cat NFT',
      image: `data:image/svg+xml;base64,${base64}`,
      attributes: [
        { trait_type: 'Background', value: traits.background },
        { trait_type: 'Body Color', value: traits.bodyColor },
        { trait_type: 'Eye Color', value: traits.eyeColor },
        { trait_type: 'Accessory', value: traits.accessory },
        { trait_type: 'Expression', value: traits.expression },
        { trait_type: 'Pattern', value: traits.pattern }
      ]
    };

    return Buffer.from(JSON.stringify(metadata)).toString('base64');
  }

  /**
   * Encode traits as a compact uint256 for on-chain storage
   */
  encodeTraitsToUint(traits: CatTraits): string {
    // We can encode all traits into a single uint256
    // This saves massive gas costs compared to storing strings
    const traitIndexes = this.getTraitIndexes(traits);

    // Pack into single number: background(8) + body(8) + eyes(8) + accessory(8) + expression(8) + pattern(8) = 48 bits
    const packed =
      (traitIndexes.background << 40) |
      (traitIndexes.bodyColor << 32) |
      (traitIndexes.eyeColor << 24) |
      (traitIndexes.accessory << 16) |
      (traitIndexes.expression << 8) |
      traitIndexes.pattern;

    return '0x' + packed.toString(16).padStart(64, '0');
  }

  /**
   * Get numeric indexes for each trait (for compact storage)
   */
  private getTraitIndexes(traits: CatTraits): any {
    const { BACKGROUNDS, BODY_COLORS, EYE_COLORS, ACCESSORIES, EXPRESSIONS, PATTERNS } = require('./traits');

    return {
      background: BACKGROUNDS.findIndex((t: any) => t.name === traits.background),
      bodyColor: BODY_COLORS.findIndex((t: any) => t.name === traits.bodyColor),
      eyeColor: EYE_COLORS.findIndex((t: any) => t.name === traits.eyeColor),
      accessory: ACCESSORIES.findIndex((t: any) => t.name === traits.accessory),
      expression: EXPRESSIONS.findIndex((t: any) => t.name === traits.expression),
      pattern: PATTERNS.findIndex((t: any) => t.name === traits.pattern)
    };
  }

  /**
   * Decode uint256 back to trait names
   */
  decodeUintToTraits(encodedValue: string): CatTraits {
    const { BACKGROUNDS, BODY_COLORS, EYE_COLORS, ACCESSORIES, EXPRESSIONS, PATTERNS } = require('./traits');

    const num = BigInt(encodedValue);

    return {
      background: BACKGROUNDS[Number((num >> 40n) & 0xFFn)].name,
      bodyColor: BODY_COLORS[Number((num >> 32n) & 0xFFn)].name,
      eyeColor: EYE_COLORS[Number((num >> 24n) & 0xFFn)].name,
      accessory: ACCESSORIES[Number((num >> 16n) & 0xFFn)].name,
      expression: EXPRESSIONS[Number((num >> 8n) & 0xFFn)].name,
      pattern: PATTERNS[Number(num & 0xFFn)].name
    };
  }

  /**
   * Generate Solidity-compatible trait mapping
   */
  generateSolidityTraitMapping(): string {
    const { BACKGROUNDS, BODY_COLORS, EYE_COLORS, ACCESSORIES, EXPRESSIONS, PATTERNS } = require('./traits');

    const formatArray = (name: string, traits: any[]) => {
      const items = traits.map(t => `"${t.name}"`).join(', ');
      return `    string[${traits.length}] private ${name} = [${items}];`;
    };

    return `
    // Trait arrays for on-chain generation
${formatArray('backgrounds', BACKGROUNDS)}
${formatArray('bodyColors', BODY_COLORS)}
${formatArray('eyeColors', EYE_COLORS)}
${formatArray('accessories', ACCESSORIES)}
${formatArray('expressions', EXPRESSIONS)}
${formatArray('patterns', PATTERNS)}
`;
  }
}
