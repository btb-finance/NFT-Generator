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

function randomFloat(min, max) {
    return Math.random() * (max - min) + min;
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

    toXML() {
        return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${this.width} ${this.height}" width="800" height="800">
  <defs>${this.defs.join('')}</defs>
  ${this.elements.join('\n  ')}
</svg>`;
    }
}

// --- ULTRA PREMIUM BEAR GENERATOR ---
function generateBear(index) {
    const svg = new SVGBuilder(1000, 1000);
    const traits = {};

    // 1. Palette & Background
    const paletteName = pick(Object.keys(palettes));
    const pal = palettes[paletteName];
    traits.Palette = paletteName;

    // Background Gradient (Diagonal)
    const bgId = `bg-${index}`;
    svg.addDef(`<linearGradient id="${bgId}" x1="0%" y1="0%" x2="100%" y2="100%">
        <stop offset="0%" stop-color="${pal.bg[0]}" />
        <stop offset="100%" stop-color="${pal.bg[1]}" />
    </linearGradient>`);
    svg.add(`<rect width="1000" height="1000" fill="url(#${bgId})" />`);

    // Background Bokeh/Sparkles
    for (let i = 0; i < 15; i++) {
        const cx = randomInt(0, 1000);
        const cy = randomInt(0, 1000);
        const r = randomInt(20, 100);
        const opacity = randomFloat(0.05, 0.15);
        svg.add(`<circle cx="${cx}" cy="${cy}" r="${r}" fill="#FFF" fill-opacity="${opacity}" filter="blur(5px)" />`);

        // Occasional sparkle
        if (Math.random() > 0.8) {
            svg.add(`<circle cx="${cx}" cy="${cy}" r="${r / 4}" fill="#FFF" fill-opacity="0.4" />`);
        }
    }

    // 2. Fur Texture & Body
    // We'll use a complex gradient for the fur to give it volume
    const furId = `fur-${index}`;
    svg.addDef(`<radialGradient id="${furId}" cx="40%" cy="40%" r="60%" fx="40%" fy="30%">
        <stop offset="0%" stop-color="${pal.fur}" /> <!-- Highlight area -->
        <stop offset="70%" stop-color="${pal.fur}" />
        <stop offset="100%" stop-color="${pal.accent}" stop-opacity="0.3" /> <!-- Rim shadow mix -->
    </radialGradient>`);

    // EARS with FLUFF
    // We add small "tufts" by manipulating the path
    const leftEarPath = `
        M 220 400 
        C 200 300 250 220 350 250 
        C 380 260 390 300 370 350 Z
    `;
    const rightEarPath = `
        M 780 400 
        C 800 300 750 220 650 250 
        C 620 260 610 300 630 350 Z
    `;

    // Draw Ears (Bottom layer)
    svg.add(`<path d="${leftEarPath}" fill="url(#${furId})" transform="rotate(-10 300 350)" />`);
    svg.add(`<path d="${rightEarPath}" fill="url(#${furId})" transform="rotate(10 700 350)" />`);

    // Inner Ear Glow
    svg.add(`<ellipse cx="300" cy="320" rx="35" ry="45" fill="${pal.accent}" fill-opacity="0.6" filter="blur(2px)" transform="rotate(-15 300 320)" />`);
    svg.add(`<ellipse cx="700" cy="320" rx="35" ry="45" fill="${pal.accent}" fill-opacity="0.6" filter="blur(2px)" transform="rotate(15 700 320)" />`);

    // HEAD SHAPE (Textured / Fluffy)
    // Instead of a perfect squircle, we gently wobble or bulge the cheeks specifically
    const headPath = `
        M 500 220
        C 650 220 780 320 820 500
        C 840 600 820 750 700 820
        C 600 860 400 860 300 820
        C 180 750 160 600 180 500
        C 220 320 350 220 500 220
        Z
    `;

    // Drop Shadow for geometric depth
    svg.add(`<path d="${headPath}" transform="translate(0, 15)" fill="#000" fill-opacity="0.15" filter="blur(10px)" />`);

    // Main Head
    svg.add(`<path d="${headPath}" fill="url(#${furId})" />`);

    // Rim Light (Top)
    svg.add(`<path d="M 300 250 Q 500 180 700 250" fill="none" stroke="#FFF" stroke-width="8" stroke-opacity="0.15" stroke-linecap="round" />`);

    // 3. Face Features - SNOUT
    const snoutY = 600;
    // Snout gradient
    const snoutId = `snout-${index}`;
    svg.addDef(`<radialGradient id="${snoutId}" cx="50%" cy="40%" r="50%">
        <stop offset="0%" stop-color="#FFFFFF" stop-opacity="0.4" />
        <stop offset="80%" stop-color="${pal.accent}" stop-opacity="0.1" />
        <stop offset="100%" stop-color="${pal.fur}" stop-opacity="0" />
    </radialGradient>`);

    svg.add(`<ellipse cx="500" cy="${snoutY}" rx="160" ry="120" fill="url(#${snoutId})" />`);

    // Nose (Soft rounded triangle)
    svg.add(`<path d="M 450 560 C 450 540 550 540 550 560 L 530 600 C 530 620 470 620 470 600 Z" fill="${pal.eye}" />`);
    // Nose Highlight
    svg.add(`<ellipse cx="480" cy="565" rx="15" ry="8" fill="#FFF" fill-opacity="0.5" />`);

    // Mouth
    const mouthType = pick(['Smile', 'Tiny', 'Grin']);
    if (mouthType === 'Smile') {
        svg.add(`<path d="M 500 610 L 500 640" stroke="${pal.eye}" stroke-width="6" stroke-linecap="round" />`);
        svg.add(`<path d="M 460 640 Q 500 680 540 640" fill="none" stroke="${pal.eye}" stroke-width="6" stroke-linecap="round" />`);
    } else if (mouthType === 'Tiny') {
        svg.add(`<path d="M 490 630 Q 500 640 510 630" fill="none" stroke="${pal.eye}" stroke-width="6" stroke-linecap="round" />`);
    } else {
        svg.add(`<path d="M 460 630 Q 500 680 540 630 Z" fill="#4E342E" stroke="${pal.eye}" stroke-width="4" />`);
        // Tongue
        svg.add(`<path d="M 480 660 Q 500 670 520 660" fill="none" stroke="#FF8A80" stroke-width="8" stroke-linecap="round" />`);
    }

    // 4. Eyes (Ultra Premium)
    // Complex construction
    const drawPremiumEye = (cx, cy) => {
        // Deep Socket Shadow (Ambient Occlusion)
        svg.add(`<ellipse cx="${cx}" cy="${cy}" rx="60" ry="65" fill="#000" fill-opacity="0.1" filter="blur(2px)" />`);

        // Sclera (White base)
        svg.add(`<ellipse cx="${cx}" cy="${cy}" rx="55" ry="60" fill="#FFF" />`);

        // Iris Gradient
        const irisId = `iris-${cx}`;
        svg.addDef(`<radialGradient id="${irisId}" cx="30%" cy="30%" r="80%">
            <stop offset="0%" stop-color="${pal.eye}" /> <!-- Lighter center part of iris -->
            <stop offset="80%" stop-color="#000" /> <!-- Dark outer rim -->
        </radialGradient>`);

        // Iris
        svg.add(`<circle cx="${cx}" cy="${cy}" r="45" fill="url(#${irisId})" />`);

        // Pupil (Large for cute factor)
        svg.add(`<circle cx="${cx}" cy="${cy}" r="25" fill="#000" />`);

        // Primary Highlight (Top Left - Window Reflection)
        svg.add(`<ellipse cx="${cx - 20}" cy="${cy - 20}" rx="12" ry="8" transform="rotate(-45 ${cx - 20} ${cy - 20})" fill="#FFF" fill-opacity="0.9" />`);

        // Secondary Highlight (Bottom Right - Bounce Light)
        svg.add(`<circle cx="${cx + 20}" cy="${cy + 20}" r="5" fill="#FFF" fill-opacity="0.6" />`);

        // Eyelash / Eyelid shadow top
        svg.add(`<path d="M ${cx - 50} ${cy - 20} Q ${cx} ${cy - 60} ${cx + 50} ${cy - 20}" fill="none" stroke="${pal.eye}" stroke-width="4" stroke-opacity="0.5" />`);
    };

    drawPremiumEye(360, 480);
    drawPremiumEye(640, 480);

    // Cheeks (Blush with gradient)
    const blushId = `blush-${index}`;
    svg.addDef(`<radialGradient id="${blushId}">
        <stop offset="0%" stop-color="#FF5252" stop-opacity="0.4" />
        <stop offset="100%" stop-color="#FF5252" stop-opacity="0" />
    </radialGradient>`);
    svg.add(`<circle cx="300" cy="620" r="70" fill="url(#${blushId})" />`);
    svg.add(`<circle cx="700" cy="620" r="70" fill="url(#${blushId})" />`);

    // 5. Accessories
    if (Math.random() > 0.5) {
        const acc = pick(['Glasses', 'Halo', 'Bowtie']);
        traits.Accessory = acc;

        if (acc === 'Glasses') {
            // Chic round glasses
            svg.add(`<circle cx="360" cy="480" r="70" fill="#000" fill-opacity="0.1" stroke="#FFD700" stroke-width="8" />`);
            svg.add(`<circle cx="640" cy="480" r="70" fill="#000" fill-opacity="0.1" stroke="#FFD700" stroke-width="8" />`);
            // Bridge
            svg.add(`<line x1="430" y1="480" x2="570" y2="480" stroke="#FFD700" stroke-width="8" />`);
            // Shine on glass
            svg.add(`<path d="M 330 460 L 390 500" stroke="#FFF" stroke-width="3" stroke-opacity="0.3" />`);
            svg.add(`<path d="M 610 460 L 670 500" stroke="#FFF" stroke-width="3" stroke-opacity="0.3" />`);
        } else if (acc === 'Halo') {
            // Glowing Halo
            svg.add(`<ellipse cx="500" cy="150" rx="150" ry="30" fill="none" stroke="#FFD700" stroke-width="12" filter="blur(2px)" />`);
            svg.add(`<ellipse cx="500" cy="150" rx="150" ry="30" fill="none" stroke="#FFF" stroke-width="4" />`);
        } else if (acc === 'Bowtie') {
            // Premium Silk Bowtie
            const tieGradientId = `tie-${index}`;
            svg.addDef(`<linearGradient id="${tieGradientId}" x1="0%" y1="0%" x2="0%" y2="100%">
                <stop offset="0%" stop-color="${pal.accent}" />
                <stop offset="100%" stop-color="${pal.eye}" /> 
            </linearGradient>`);

            svg.add(`<path d="M 500 800 L 400 750 C 380 740 380 860 400 850 L 500 800 Z" fill="url(#${tieGradientId})" />`);
            svg.add(`<path d="M 500 800 L 600 750 C 620 740 620 860 600 850 L 500 800 Z" fill="url(#${tieGradientId})" />`);
            svg.add(`<circle cx="500" cy="800" r="25" fill="${pal.eye}" />`);
        }
    }

    return { svg: svg.toXML(), traits };
}

async function main() {
    console.log(`Generating ${editionSize} ULTRA-PREMIUM SVG Bears...`);
    ensureDir(imagesDir);
    ensureDir(metadataDir);

    for (let i = 1; i <= editionSize; i++) {
        const { svg, traits } = generateBear(i);

        fs.writeFileSync(path.join(imagesDir, `${i}.svg`), svg);
        const metadata = {
            name: `Ultra-Premium Bear #${i}`,
            description: "An ultra-premium vector art bear with advanced texturing.",
            image: `${i}.svg`,
            attributes: Object.entries(traits).map(([k, v]) => ({ trait_type: k, value: v }))
        };
        fs.writeFileSync(path.join(metadataDir, `${i}.json`), JSON.stringify(metadata, null, 2));

        if (i % 10 === 0) process.stdout.write('.');
    }

    console.log(`\nDONE. Generated ${editionSize} Ultra-Premium SVGs in ${outputDir}`);
}

main().catch(console.error);
