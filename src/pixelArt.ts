import type { PixelData } from './types';

export class PixelCanvas {
  width: number;
  height: number;
  pixelSize: number;
  pixels: string[][];

  constructor(width: number = 24, height: number = 24, pixelSize: number = 20) {
    this.width = width;
    this.height = height;
    this.pixelSize = pixelSize;
    this.pixels = Array(height).fill(null).map(() => Array(width).fill('transparent'));
  }

  setPixel(x: number, y: number, color: string) {
    if (x >= 0 && x < this.width && y >= 0 && y < this.height) {
      this.pixels[y][x] = color;
    }
  }

  fillRect(x: number, y: number, width: number, height: number, color: string) {
    for (let i = 0; i < height; i++) {
      for (let j = 0; j < width; j++) {
        this.setPixel(x + j, y + i, color);
      }
    }
  }

  drawCircle(centerX: number, centerY: number, radius: number, color: string) {
    for (let y = -radius; y <= radius; y++) {
      for (let x = -radius; x <= radius; x++) {
        if (x * x + y * y <= radius * radius) {
          this.setPixel(centerX + x, centerY + y, color);
        }
      }
    }
  }

  toSVG(): string {
    const totalWidth = this.width * this.pixelSize;
    const totalHeight = this.height * this.pixelSize;

    let svg = `<svg width="${totalWidth}" height="${totalHeight}" xmlns="http://www.w3.org/2000/svg">`;

    for (let y = 0; y < this.height; y++) {
      for (let x = 0; x < this.width; x++) {
        const color = this.pixels[y][x];
        if (color !== 'transparent') {
          const px = x * this.pixelSize;
          const py = y * this.pixelSize;
          svg += `<rect x="${px}" y="${py}" width="${this.pixelSize}" height="${this.pixelSize}" fill="${color}"/>`;
        }
      }
    }

    svg += '</svg>';
    return svg;
  }

  toDataURL(): string {
    const svg = this.toSVG();
    const base64 = Buffer.from(svg).toString('base64');
    return `data:image/svg+xml;base64,${base64}`;
  }
}

export function drawCatBody(canvas: PixelCanvas, bodyColor: string, pattern: string) {
  const outlineColor = '#000000';
  const darkerShade = adjustBrightness(bodyColor, -30);

  // Draw cat head outline and shape - more rounded
  // Top of head
  canvas.fillRect(9, 3, 6, 1, outlineColor);

  // Upper head with rounded corners
  canvas.fillRect(8, 4, 8, 1, bodyColor);
  canvas.setPixel(7, 4, outlineColor);
  canvas.setPixel(16, 4, outlineColor);

  // Main head area - rounder shape
  canvas.fillRect(6, 5, 12, 7, bodyColor);
  canvas.setPixel(6, 5, outlineColor);
  canvas.setPixel(17, 5, outlineColor);
  canvas.setPixel(5, 6, outlineColor);
  canvas.setPixel(18, 6, outlineColor);

  // Head outline sides
  canvas.setPixel(5, 7, outlineColor);
  canvas.setPixel(5, 8, outlineColor);
  canvas.setPixel(5, 9, outlineColor);
  canvas.setPixel(5, 10, outlineColor);
  canvas.setPixel(18, 7, outlineColor);
  canvas.setPixel(18, 8, outlineColor);
  canvas.setPixel(18, 9, outlineColor);
  canvas.setPixel(18, 10, outlineColor);

  // Bottom of head - chin
  canvas.setPixel(6, 11, outlineColor);
  canvas.setPixel(17, 11, outlineColor);
  canvas.fillRect(7, 12, 10, 1, outlineColor);

  // Draw pointed cat ears with outline
  // Left ear
  canvas.setPixel(7, 2, outlineColor);
  canvas.fillRect(7, 3, 2, 1, bodyColor);
  canvas.setPixel(6, 3, outlineColor);
  canvas.setPixel(9, 3, outlineColor);
  canvas.fillRect(6, 4, 2, 1, bodyColor);
  canvas.setPixel(8, 4, darkerShade); // Inner ear

  // Right ear
  canvas.setPixel(16, 2, outlineColor);
  canvas.fillRect(15, 3, 2, 1, bodyColor);
  canvas.setPixel(14, 3, outlineColor);
  canvas.setPixel(17, 3, outlineColor);
  canvas.fillRect(16, 4, 2, 1, bodyColor);
  canvas.setPixel(15, 4, darkerShade); // Inner ear

  // Cat body - sitting pose
  canvas.fillRect(8, 13, 8, 1, outlineColor);
  canvas.fillRect(7, 14, 10, 5, bodyColor);
  canvas.setPixel(6, 14, outlineColor);
  canvas.setPixel(6, 15, outlineColor);
  canvas.setPixel(6, 16, outlineColor);
  canvas.setPixel(6, 17, outlineColor);
  canvas.setPixel(17, 14, outlineColor);
  canvas.setPixel(17, 15, outlineColor);
  canvas.setPixel(17, 16, outlineColor);
  canvas.setPixel(17, 17, outlineColor);

  // Body bottom outline
  canvas.fillRect(6, 18, 12, 1, outlineColor);

  // Front paws
  canvas.fillRect(8, 19, 2, 2, bodyColor);
  canvas.fillRect(14, 19, 2, 2, bodyColor);
  canvas.setPixel(7, 19, outlineColor);
  canvas.setPixel(7, 20, outlineColor);
  canvas.setPixel(8, 21, outlineColor);
  canvas.setPixel(9, 21, outlineColor);
  canvas.setPixel(16, 19, outlineColor);
  canvas.setPixel(16, 20, outlineColor);
  canvas.setPixel(14, 21, outlineColor);
  canvas.setPixel(15, 21, outlineColor);

  // Tail
  canvas.setPixel(18, 16, outlineColor);
  canvas.fillRect(19, 15, 1, 2, bodyColor);
  canvas.setPixel(18, 15, outlineColor);
  canvas.setPixel(20, 15, outlineColor);
  canvas.setPixel(20, 16, outlineColor);
  canvas.setPixel(19, 17, outlineColor);

  // Add pattern details
  if (pattern === 'Striped') {
    // Stripes on body
    for (let i = 0; i < 2; i++) {
      canvas.fillRect(9 + i * 3, 14, 1, 4, darkerShade);
    }
    // Stripes on head
    canvas.fillRect(10, 6, 1, 2, darkerShade);
    canvas.fillRect(13, 6, 1, 2, darkerShade);
  } else if (pattern === 'Spotted') {
    canvas.fillRect(9, 15, 2, 2, darkerShade);
    canvas.fillRect(14, 16, 2, 2, darkerShade);
    canvas.setPixel(10, 7, darkerShade);
    canvas.setPixel(13, 8, darkerShade);
  } else if (pattern === 'Tuxedo') {
    // White chest
    canvas.fillRect(10, 14, 4, 4, '#FFFFFF');
    // White paws
    canvas.fillRect(8, 19, 2, 2, '#FFFFFF');
    canvas.fillRect(14, 19, 2, 2, '#FFFFFF');
  } else if (pattern === 'Patches') {
    const patchColor = adjustBrightness(bodyColor, 40);
    canvas.fillRect(7, 6, 2, 2, patchColor);
    canvas.fillRect(15, 8, 2, 2, patchColor);
    canvas.fillRect(11, 15, 2, 2, patchColor);
  } else if (pattern === 'Tiger Stripes') {
    // Bold tiger-like stripes
    canvas.fillRect(8, 6, 1, 3, darkerShade);
    canvas.fillRect(11, 7, 1, 2, darkerShade);
    canvas.fillRect(14, 6, 1, 3, darkerShade);
    canvas.fillRect(8, 14, 1, 4, darkerShade);
    canvas.fillRect(12, 15, 1, 3, darkerShade);
    canvas.fillRect(15, 14, 1, 4, darkerShade);
  }
}

export function drawCatFace(canvas: PixelCanvas, eyeColor: string, expression: string) {
  const outlineColor = '#000000';
  const noseColor = '#FF69B4';

  // Draw eyes based on expression - more cat-like
  if (expression === 'Happy') {
    // Happy cat eyes (curved, smiling eyes)
    // Left eye
    canvas.fillRect(8, 7, 3, 2, '#FFFFFF');
    canvas.setPixel(8, 7, outlineColor);
    canvas.setPixel(10, 7, outlineColor);
    canvas.fillRect(9, 8, 1, 1, eyeColor);
    canvas.setPixel(8, 9, outlineColor);
    canvas.setPixel(9, 9, outlineColor);
    canvas.setPixel(10, 9, outlineColor);

    // Right eye
    canvas.fillRect(13, 7, 3, 2, '#FFFFFF');
    canvas.setPixel(13, 7, outlineColor);
    canvas.setPixel(15, 7, outlineColor);
    canvas.fillRect(14, 8, 1, 1, eyeColor);
    canvas.setPixel(13, 9, outlineColor);
    canvas.setPixel(14, 9, outlineColor);
    canvas.setPixel(15, 9, outlineColor);
  } else if (expression === 'Sleepy') {
    // Closed eyes (curved lines)
    canvas.fillRect(8, 8, 3, 1, outlineColor);
    canvas.fillRect(13, 8, 3, 1, outlineColor);
    // Small eyelash effect
    canvas.setPixel(7, 7, outlineColor);
    canvas.setPixel(11, 7, outlineColor);
    canvas.setPixel(12, 7, outlineColor);
    canvas.setPixel(16, 7, outlineColor);
  } else if (expression === 'Winking') {
    // Left eye closed
    canvas.fillRect(8, 8, 3, 1, outlineColor);
    canvas.setPixel(7, 7, outlineColor);
    canvas.setPixel(11, 7, outlineColor);

    // Right eye open
    canvas.fillRect(13, 7, 3, 3, '#FFFFFF');
    canvas.setPixel(13, 7, outlineColor);
    canvas.setPixel(14, 7, outlineColor);
    canvas.setPixel(15, 7, outlineColor);
    canvas.fillRect(14, 8, 1, 2, eyeColor);
    canvas.setPixel(14, 9, '#000000');
  } else if (expression === 'Surprised') {
    // Wide open eyes
    canvas.fillRect(8, 6, 3, 4, '#FFFFFF');
    canvas.fillRect(8, 6, 3, 1, outlineColor);
    canvas.setPixel(7, 7, outlineColor);
    canvas.setPixel(11, 7, outlineColor);
    canvas.setPixel(7, 8, outlineColor);
    canvas.setPixel(11, 8, outlineColor);
    canvas.fillRect(9, 8, 1, 2, eyeColor);

    canvas.fillRect(13, 6, 3, 4, '#FFFFFF');
    canvas.fillRect(13, 6, 3, 1, outlineColor);
    canvas.setPixel(12, 7, outlineColor);
    canvas.setPixel(16, 7, outlineColor);
    canvas.setPixel(12, 8, outlineColor);
    canvas.setPixel(16, 8, outlineColor);
    canvas.fillRect(14, 8, 1, 2, eyeColor);
  } else if (expression === 'Grumpy') {
    // Angry slanted eyes
    canvas.fillRect(8, 8, 3, 2, '#FFFFFF');
    canvas.setPixel(7, 7, outlineColor);
    canvas.setPixel(8, 7, outlineColor);
    canvas.setPixel(10, 9, outlineColor);
    canvas.setPixel(11, 9, outlineColor);
    canvas.fillRect(9, 8, 1, 1, eyeColor);

    canvas.fillRect(13, 8, 3, 2, '#FFFFFF');
    canvas.setPixel(15, 7, outlineColor);
    canvas.setPixel(16, 7, outlineColor);
    canvas.setPixel(12, 9, outlineColor);
    canvas.setPixel(13, 9, outlineColor);
    canvas.fillRect(14, 8, 1, 1, eyeColor);
  } else if (expression === 'Loving') {
    // Heart-shaped eyes
    canvas.setPixel(8, 7, '#FF69B4');
    canvas.setPixel(10, 7, '#FF69B4');
    canvas.fillRect(7, 8, 5, 1, '#FF69B4');
    canvas.fillRect(8, 9, 3, 1, '#FF69B4');
    canvas.setPixel(9, 10, '#FF69B4');

    canvas.setPixel(13, 7, '#FF69B4');
    canvas.setPixel(15, 7, '#FF69B4');
    canvas.fillRect(12, 8, 5, 1, '#FF69B4');
    canvas.fillRect(13, 9, 3, 1, '#FF69B4');
    canvas.setPixel(14, 10, '#FF69B4');
  } else {
    // Normal cat eyes with vertical pupils
    // Left eye
    canvas.fillRect(8, 7, 3, 3, eyeColor);
    canvas.setPixel(8, 7, outlineColor);
    canvas.setPixel(9, 7, outlineColor);
    canvas.setPixel(10, 7, outlineColor);
    canvas.fillRect(9, 8, 1, 2, '#000000'); // Vertical pupil
    canvas.setPixel(8, 10, outlineColor);
    canvas.setPixel(9, 10, outlineColor);
    canvas.setPixel(10, 10, outlineColor);

    // Right eye
    canvas.fillRect(13, 7, 3, 3, eyeColor);
    canvas.setPixel(13, 7, outlineColor);
    canvas.setPixel(14, 7, outlineColor);
    canvas.setPixel(15, 7, outlineColor);
    canvas.fillRect(14, 8, 1, 2, '#000000'); // Vertical pupil
    canvas.setPixel(13, 10, outlineColor);
    canvas.setPixel(14, 10, outlineColor);
    canvas.setPixel(15, 10, outlineColor);
  }

  // Draw cute cat nose (triangle shape)
  canvas.setPixel(11, 9, noseColor);
  canvas.fillRect(11, 10, 2, 1, noseColor);
  canvas.setPixel(11, 11, outlineColor);
  canvas.setPixel(12, 11, outlineColor);

  // Draw mouth based on expression
  if (expression === 'Happy') {
    // Big smile
    canvas.setPixel(10, 11, outlineColor);
    canvas.setPixel(13, 11, outlineColor);
    canvas.setPixel(9, 10, outlineColor);
    canvas.setPixel(14, 10, outlineColor);
  } else if (expression === 'Grumpy') {
    // Frown
    canvas.setPixel(10, 10, outlineColor);
    canvas.setPixel(13, 10, outlineColor);
  } else if (expression === 'Surprised') {
    // Open mouth
    canvas.setPixel(11, 11, outlineColor);
    canvas.setPixel(12, 11, outlineColor);
  } else {
    // Normal W-shaped cat mouth
    canvas.setPixel(10, 11, outlineColor);
    canvas.setPixel(13, 11, outlineColor);
  }

  // Draw whiskers - three on each side
  // Left whiskers
  canvas.setPixel(3, 8, outlineColor);
  canvas.setPixel(4, 8, outlineColor);
  canvas.setPixel(3, 9, outlineColor);
  canvas.setPixel(4, 9, outlineColor);
  canvas.setPixel(3, 10, outlineColor);
  canvas.setPixel(4, 10, outlineColor);

  // Right whiskers
  canvas.setPixel(19, 8, outlineColor);
  canvas.setPixel(20, 8, outlineColor);
  canvas.setPixel(19, 9, outlineColor);
  canvas.setPixel(20, 9, outlineColor);
  canvas.setPixel(19, 10, outlineColor);
  canvas.setPixel(20, 10, outlineColor);

  // Add cheek marks for cuteness
  canvas.setPixel(7, 9, '#FFB6C1');
  canvas.setPixel(7, 10, '#FFB6C1');
  canvas.setPixel(16, 9, '#FFB6C1');
  canvas.setPixel(16, 10, '#FFB6C1');
}

export function drawAccessory(canvas: PixelCanvas, accessory: string) {
  const accentColor = '#FFD700';

  switch (accessory) {
    case 'Crown':
      canvas.fillRect(9, 2, 6, 2, accentColor);
      canvas.setPixel(9, 1, accentColor);
      canvas.setPixel(11, 1, accentColor);
      canvas.setPixel(13, 1, accentColor);
      break;

    case 'Top Hat':
      canvas.fillRect(10, 0, 4, 2, '#2C2C2C');
      canvas.fillRect(8, 2, 8, 1, '#2C2C2C');
      canvas.setPixel(10, 1, '#FF0000'); // Red band
      canvas.setPixel(11, 1, '#FF0000');
      canvas.setPixel(12, 1, '#FF0000');
      canvas.setPixel(13, 1, '#FF0000');
      break;

    case 'Bow Tie':
      canvas.setPixel(11, 13, '#FF0000');
      canvas.setPixel(12, 13, '#FF0000');
      canvas.setPixel(10, 13, '#FF0000');
      canvas.setPixel(13, 13, '#FF0000');
      canvas.setPixel(11, 12, '#FF0000');
      canvas.setPixel(12, 12, '#FF0000');
      break;

    case 'Sunglasses':
      canvas.fillRect(8, 8, 3, 2, '#2C2C2C');
      canvas.fillRect(13, 8, 3, 2, '#2C2C2C');
      canvas.fillRect(11, 9, 2, 1, '#2C2C2C');
      break;

    case 'Bandana':
      canvas.fillRect(8, 4, 8, 2, '#FF0000');
      canvas.setPixel(7, 5, '#FF0000');
      canvas.setPixel(16, 5, '#FF0000');
      break;

    case 'Astronaut Helmet':
      // Helmet glass
      canvas.fillRect(7, 4, 10, 10, 'rgba(135, 206, 250, 0.3)');
      // Helmet frame
      canvas.setPixel(7, 4, '#C0C0C0');
      canvas.setPixel(16, 4, '#C0C0C0');
      canvas.setPixel(7, 13, '#C0C0C0');
      canvas.setPixel(16, 13, '#C0C0C0');
      break;

    case 'Pirate Eye Patch':
      canvas.fillRect(9, 8, 2, 2, '#2C2C2C');
      canvas.setPixel(8, 7, '#2C2C2C');
      canvas.setPixel(14, 7, '#2C2C2C');
      break;

    case 'Golden Crown':
      canvas.fillRect(9, 1, 6, 3, accentColor);
      canvas.setPixel(9, 0, accentColor);
      canvas.setPixel(11, 0, accentColor);
      canvas.setPixel(13, 0, accentColor);
      canvas.setPixel(10, 2, '#FF0000'); // Jewels
      canvas.setPixel(12, 2, '#FF0000');
      canvas.setPixel(14, 2, '#FF0000');
      break;
  }
}

function adjustBrightness(color: string, amount: number): string {
  const hex = color.replace('#', '');
  const num = parseInt(hex, 16);
  const r = Math.max(0, Math.min(255, (num >> 16) + amount));
  const g = Math.max(0, Math.min(255, ((num >> 8) & 0x00FF) + amount));
  const b = Math.max(0, Math.min(255, (num & 0x0000FF) + amount));
  return `#${((r << 16) | (g << 8) | b).toString(16).padStart(6, '0')}`;
}
