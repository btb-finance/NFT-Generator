import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import crypto from 'crypto';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const outputDir = path.join(__dirname, 'svg_bears_output');
const imagesDir = path.join(outputDir, 'images');
const metadataDir = path.join(outputDir, 'metadata');

const editionSize = 100;

function ensureDir(dir) {
    fs.mkdirSync(dir, { recursive: true });
}

// --- UTILS ---
function pick(array) {
    return array[Math.floor(Math.random() * array.length)];
}

function randomInt(min, max) {
    return Math.floor(Math.random() * (max - min + 1)) + min;
}

// --- CURATED PALETTES ---
const palettes = {
    'Matcha Latte': { bg: ['#F0F4C3', '#C5E1A5'], fur: '#7CB342', accent: '#DCEDC8', eye: '#33691E' },
    'Royal Guard': { bg: ['#212121', '#424242'], fur: '#FFD700', accent: '#D32F2F', eye: '#000000' },
    'Cyber Punk': { bg: ['#311B92', '#6200EA'], fur: '#00E5FF', accent: '#FF4081', eye: '#FFFF00' },
    'Cotton Candy': { bg: ['#E1F5FE', '#B3E5FC'], fur: '#F8BBD0', accent: '#E1BEE7', eye: '#880E4F' },
    'Night Sky': { bg: ['#263238', '#37474F'], fur: '#FFF59D', accent: '#FFAB91', eye: '#1A237E' },
    'Grizzly': { bg: ['#D7CCC8', '#A1887F'], fur: '#5D4037', accent: '#8D6E63', eye: '#3E2723' },
    'Polar': { bg: ['#0277BD', '#0288D1'], fur: '#FFFFFF', accent: '#B3E5FC', eye: '#01579B' },
    'Bamboo': { bg: ['#E8F5E9', '#C8E6C9'], fur: '#333333', accent: '#4CAF50', eye: '#1B5E20' },
    'Sunset': { bg: ['#FF5722', '#FF9800'], fur: '#FFCCBC', accent: '#FF7043', eye: '#BF360C' },
    'Lavender': { bg: ['#EDE7F6', '#D1C4E9'], fur: '#9575CD', accent: '#B39DDB', eye: '#4527A0' },
};

// --- SVG BUILDER ---
class SVGBuilder {
    constructor(w, h) {
        this.width = w;
        this.height = h;
        this.elements = [];
        this.defs = [];
    }

    addDef(def) {
        this.defs.push(def);
    }

    add(element) {
        this.elements.push(element);
    }

    // Organic gradients
    addGradient(id, colors, type = 'linear') {
        const stops = colors.map((c, i) =>
            `<stop offset="${(i / (colors.length - 1)) * 100}%" stop-color="${c}" />`
        ).join('');

        if (type === 'linear') {
            this.addDef(`<linearGradient id="${id}" x1="0%" y1="0%" x2="0%" y2="100%">${stops}</linearGradient>`);
        } else {
            this.addDef(`<radialGradient id="${id}" cx="50%" cy="50%" r="50%" fx="50%" fy="20%">${stops}</radialGradient>`);
        }
    }

    toXML() {
        return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${this.width} ${this.height}" width="800" height="800">
  <defs>${this.defs.join('')}</defs>
  ${this.elements.join('\n  ')}
</svg>`;
    }
}

// --- PREMIUM BEAR GENERATOR ---
function generateBear(index) {
    const svg = new SVGBuilder(1000, 1000);
    const traits = {};

    // 1. Palette
    const paletteName = pick(Object.keys(palettes));
    const pal = palettes[paletteName];
    traits.Palette = paletteName;

    // 2. Background (Soft Gradient)
    const bgId = `bg-${index}`;
    svg.addGradient(bgId, pal.bg, 'linear');
    svg.add(`<rect width="1000" height="1000" fill="url(#${bgId})" />`);

    // Background Pattern (Subtle)
    for (let i = 0; i < 10; i++) {
        const cx = randomInt(0, 1000);
        const cy = randomInt(0, 1000);
        const r = randomInt(50, 150);
        svg.add(`<circle cx="${cx}" cy="${cy}" r="${r}" fill="#FFF" fill-opacity="0.05" />`);
    }

    // 3. The Bear Shape (Organic Path)
    const furId = `fur-${index}`;
    // Fur gradient: slightly lighter top to darker bottom
    svg.addGradient(furId, [pal.fur, pal.fur], 'radial'); // Solid for now, or subtle gradient

    // HEAD & BODY
    // Using a "squircle" path modified to be a cute bear shape
    // Center: 500, 500

    // Ears (Behind head)
    const lEarPath = `M 300 350 C 200 350 180 500 280 500 C 300 500 300 450 350 450 Z`; // Simplified path logic
    // Actually simpler: Circles are fine for ears if shaded well
    svg.add(`<circle cx="300" cy="350" r="80" fill="${pal.fur}" />`); // Left Ear Base
    svg.add(`<circle cx="700" cy="350" r="80" fill="${pal.fur}" />`); // Right Ear Base

    // Inner Ears
    svg.add(`<circle cx="300" cy="350" r="50" fill="${pal.accent}" fill-opacity="0.8" />`);
    svg.add(`<circle cx="700" cy="350" r="50" fill="${pal.accent}" fill-opacity="0.8" />`);

    // Head Shape (Organic Bezier)
    // Starting top center, going clockwise
    const headPath = `
        M 500 250
        C 700 250 800 400 800 550
        C 800 750 700 850 500 850
        C 300 850 200 750 200 550
        C 200 400 300 250 500 250
        Z
    `;
    svg.add(`<path d="${headPath}" fill="${pal.fur}" />`);

    // Head Highlight (Rim Light)
    const highlightPath = `
        M 500 265
        C 650 265 750 380 770 500
        M 500 265
        C 350 265 250 380 230 500
    `;
    // svg.add(`<path d="${highlightPath}" fill="none" stroke="#FFF" stroke-width="15" stroke-opacity="0.3" stroke-linecap="round" />`);
    svg.add(`<ellipse cx="400" cy="350" rx="80" ry="40" transform="rotate(-45 400 350)" fill="#FFF" fill-opacity="0.2" />`); // Forehead Shine

    // 4. Face Features

    // Snout (OVAL)
    svg.add(`<ellipse cx="500" cy="620" rx="140" ry="110" fill="#FFF" fill-opacity="0.2" />`); // Snout shadow/base
    svg.add(`<ellipse cx="500" cy="600" rx="140" ry="110" fill="${pal.accent}" fill-opacity="0.3" />`); // Snout color

    // Nose (Heart shape or soft rounding)
    const nosePath = `M 500 570 C 530 560 550 580 500 610 C 450 580 470 560 500 570 Z`;
    svg.add(`<path d="${nosePath}" fill="${pal.eye}" />`);
    svg.add(`<ellipse cx="490" cy="575" rx="10" ry="5" fill="#FFF" fill-opacity="0.6" />`); // Nose Shine

    // Mouth
    svg.add(`<path d="M 500 610 L 500 650" stroke="${pal.eye}" stroke-width="8" stroke-linecap="round" />`);
    svg.add(`<path d="M 450 650 Q 500 690 550 650" stroke="${pal.eye}" stroke-width="8" fill="none" stroke-linecap="round" />`);

    // Eyes (Premium)
    const drawEye = (cx, cy) => {
        // Shadow/Socket
        svg.add(`<circle cx="${cx}" cy="${cy}" r="55" fill="#000" fill-opacity="0.1" />`);
        // Sclera
        svg.add(`<circle cx="${cx}" cy="${cy}" r="50" fill="#FFF" />`);
        // Iris/Pupil
        svg.add(`<circle cx="${cx}" cy="${cy}" r="35" fill="${pal.eye}" />`);
        // Highlights (Kawaii sparkle)
        svg.add(`<circle cx="${cx - 12}" cy="${cy - 12}" r="12" fill="#FFF" />`);
        svg.add(`<circle cx="${cx + 15}" cy="${cy + 10}" r="6" fill="#FFF" fill-opacity="0.7" />`);
    };

    drawEye(380, 500);
    drawEye(620, 500);

    // Cheeks (Blush)
    svg.add(`<ellipse cx="320" cy="600" rx="40" ry="25" fill="#FF8A80" fill-opacity="0.4" />`);
    svg.add(`<ellipse cx="680" cy="600" rx="40" ry="25" fill="#FF8A80" fill-opacity="0.4" />`);

    // 5. Clothing / Accessories
    const clothing = pick(['None', 'Bowtie', 'Bandana', 'Scarf']);
    traits.Clothing = clothing;

    if (clothing === 'Bowtie') {
        const tieColor = pal.accent === pal.bg[1] ? '#FFF' : pal.bg[0]; // Contrast
        svg.add(`<path d="M 500 780 L 420 720 L 420 840 Z" fill="${tieColor}" stroke="#000" stroke-width="2" stroke-opacity="0.1" />`);
        svg.add(`<path d="M 500 780 L 580 720 L 580 840 Z" fill="${tieColor}" stroke="#000" stroke-width="2" stroke-opacity="0.1" />`);
        svg.add(`<circle cx="500" cy="780" r="30" fill="${tieColor}" stroke="#000" stroke-width="2" stroke-opacity="0.1" />`);
    } else if (clothing === 'Bandana') {
        const bandColor = pal.eye;
        // Simple triangular shape
        svg.add(`<path d="M 350 750 Q 500 900 650 750 L 500 850 Z" fill="${bandColor}" />`);
    }

    return { svg: svg.toXML(), traits };
}

async function main() {
    console.log(`Generating ${editionSize} PREMIUM SVG Bears...`);
    ensureDir(imagesDir);
    ensureDir(metadataDir);

    for (let i = 1; i <= editionSize; i++) {
        const { svg, traits } = generateBear(i);

        fs.writeFileSync(path.join(imagesDir, `${i}.svg`), svg);
        const metadata = {
            name: `Premium Bear #${i}`,
            description: "A premium vector art bear.",
            image: `${i}.svg`,
            attributes: Object.entries(traits).map(([k, v]) => ({ trait_type: k, value: v }))
        };
        fs.writeFileSync(path.join(metadataDir, `${i}.json`), JSON.stringify(metadata, null, 2));

        if (i % 10 === 0) process.stdout.write('.');
    }

    console.log(`\nDONE. Generated ${editionSize} Premium SVGs in ${outputDir}`);
}

main().catch(console.error);
