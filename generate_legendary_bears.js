import fs from 'fs';
import path from 'path';
import { createCanvas } from 'canvas';
import { fileURLToPath } from 'url';
import crypto from 'crypto';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// LEGENDARY SPECS
const pixelSize = 24; // Keep effective pixel size large for visibility
const resolution = 32; // 32x32 grid
const width = pixelSize * resolution;
const height = pixelSize * resolution;
const editionSize = 100;

const outputDir = path.join(__dirname, 'legendary_bears_output');
const imagesDir = path.join(outputDir, 'images');
const metadataDir = path.join(outputDir, 'metadata');

function ensureDir(dir) {
    fs.mkdirSync(dir, { recursive: true });
}

// --- COLOR ENGINE ---
function hsl(h, s, l) {
    return `hsl(${h}, ${s}%, ${l}%)`;
}

// Generate a palette with Base, Highlight, Shadow, and Dark Shadow
function generatePalette(baseHue, saturation = 70, lightness = 50) {
    return {
        base: hsl(baseHue, saturation, lightness),
        highlight: hsl(baseHue, saturation, Math.min(100, lightness + 20)),
        shadow: hsl(baseHue, saturation + 10, Math.max(0, lightness - 15)),
        darkShadow: hsl(baseHue, saturation + 20, Math.max(0, lightness - 30)),
        hue: baseHue
    };
}

const specialPalettes = {
    'Polar': generatePalette(200, 10, 95),
    'Grizzly': generatePalette(30, 60, 35),
    'Panda': { base: '#FFF', highlight: '#EEE', shadow: '#DDD', darkShadow: '#CCC', secondary: '#333' },
    'Void': generatePalette(270, 80, 15),
    'Golden': generatePalette(45, 90, 60),
    'Rose Gold': generatePalette(350, 60, 75),
    'Neon Blue': generatePalette(190, 100, 60),
    'Toxic': generatePalette(120, 100, 50)
};

// --- DRAWING ENGINE ---
// Grid based drawing with shading support
function drawPixel(ctx, x, y, color) {
    ctx.fillStyle = color;
    ctx.fillRect(x * pixelSize, y * pixelSize, pixelSize, pixelSize);
}

function fillRect(ctx, x, y, w, h, color) {
    ctx.fillStyle = color;
    ctx.fillRect(x * pixelSize, y * pixelSize, w * pixelSize, h * pixelSize);
}

// Draw a shaded box (simulating 3D voxel)
function drawShadedBox(ctx, x, y, w, h, palette) {
    // Base
    fillRect(ctx, x, y, w, h, palette.base);

    // Highlight (Top and Left edges)
    fillRect(ctx, x, y, w, 1, palette.highlight); // Top
    fillRect(ctx, x, y, 1, h, palette.highlight); // Left

    // Shadow (Bottom and Right edges)
    fillRect(ctx, x, y + h - 1, w, 1, palette.shadow); // Bottom
    fillRect(ctx, x + w - 1, y, 1, h, palette.shadow); // Right

    // Corner accents
    drawPixel(ctx, x, y, '#FFFFFF'); // Specular pixel top-left
    drawPixel(ctx, x + w - 1, y + h - 1, palette.darkShadow); // Deep shadow bottom-right
}

// --- GENERATIVE BACKGROUNDS ---

function drawBackground(ctx, type) {
    // Clear
    ctx.fillStyle = '#000';
    ctx.fillRect(0, 0, width, height);

    if (type === 'Sunset Peaks') {
        // Sky Gradient (Manual dithering/banding for retro feel)
        for (let y = 0; y < resolution; y++) {
            const h = 280 - (y * 5); // Purple to Orange
            const l = 20 + (y * 2);
            fillRect(ctx, 0, y, resolution, 1, hsl(h, 60, l));
        }
        // Sun
        const sunY = 10;
        const sunX = 16;
        const sunR = 6;
        for (let y = sunY - sunR; y <= sunY + sunR; y++) {
            for (let x = sunX - sunR; x <= sunX + sunR; x++) {
                if ((x - sunX) ** 2 + (y - sunY) ** 2 <= sunR ** 2) {
                    drawPixel(ctx, x, y, '#FFD700'); // Gold sun
                    if (y > sunY + 2) drawPixel(ctx, x, y, '#FF4500'); // Reddish bottom
                }
            }
        }
        // Mountains
        ctx.fillStyle = '#300030'; // Dark purple base
        let peakY = 20;
        for (let x = 0; x < resolution; x++) {
            const noise = Math.sin(x * 0.5) * 3 + Math.cos(x * 0.9) * 2;
            const h = Math.floor(peakY + noise);
            fillRect(ctx, x, h, 1, resolution - h, '#200020');
            drawPixel(ctx, x, h, '#500050'); // Highlight edge
        }
    } else if (type === 'Aurora Borealis') {
        // Night Sky
        fillRect(ctx, 0, 0, resolution, resolution, '#050510');
        // Stars
        for (let i = 0; i < 30; i++) {
            drawPixel(ctx, Math.random() * resolution, Math.random() * resolution, '#FFF');
        }
        // Aurora Curves
        const auroraColor = '#00FF99'; // Green/Teal
        for (let x = 0; x < resolution; x++) {
            const yBase = 10 + Math.sin(x * 0.2) * 4;
            for (let w = 0; w < 3; w++) {
                drawPixel(ctx, x, yBase + w, `rgba(0, 255, 153, ${0.8 - w * 0.2})`);
            }
        }
    } else if (type === 'Cyber Grid') {
        // Dark Base
        fillRect(ctx, 0, 0, resolution, resolution, '#000020');
        // Perspective Grid
        const horizon = 12;
        ctx.fillStyle = '#FF00FF'; // Magenta Grid

        // Vertical lines fanning out
        for (let i = -10; i <= 10; i += 2) {
            const x1 = 16 + i;
            const y1 = horizon;
            const x2 = 16 + i * 4;
            const y2 = resolution;

            // Simple line algo
            let currX = x1;
            for (let y = y1; y < y2; y++) {
                drawPixel(ctx, Math.floor(currX), y, '#FF00FF');
                currX += (x2 - x1) / (y2 - y1);
            }
        }
        // Horizontal lines getting further apart
        for (let y = horizon; y < resolution; y += Math.max(1, (y - horizon) / 2)) {
            fillRect(ctx, 0, Math.floor(y), resolution, 1, '#FF00FF');
        }
    } else {
        // Solid Pastel
        const h = Math.random() * 360;
        fillRect(ctx, 0, 0, resolution, resolution, hsl(h, 70, 85));
    }
}


// --- MAIN BEAR GENERATOR ---
function drawLegendaryBear(ctx) {
    const traits = {};

    // 1. Background
    const bgTypes = ['Sunset Peaks', 'Aurora Borealis', 'Cyber Grid', 'Solid'];
    const bg = bgTypes[Math.floor(Math.random() * bgTypes.length)];
    traits.background = bg;
    drawBackground(ctx, bg);

    // 2. Fur Palette
    const paletteNames = Object.keys(specialPalettes);
    const chosenPaletteName = paletteNames[Math.floor(Math.random() * paletteNames.length)];
    traits.fur = chosenPaletteName;
    const palette = specialPalettes[chosenPaletteName];

    // Bear Geometry (Centered 32x32)
    const bx = 8;  // Body X
    const by = 18; // Body Y
    const bw = 16; // Body Width
    const bh = 14; // Body Height (off bottom)

    const hx = 6;  // Head X
    const hy = 8;  // Head Y
    const hw = 20; // Head Width
    const hh = 12; // Head Height

    // 3. Draw Body (Stocky & Shaded)
    drawShadedBox(ctx, bx, by, bw, bh, palette);

    // Legs
    drawShadedBox(ctx, bx - 1, by + 6, 4, 8, palette); // Left Arm/Leg
    drawShadedBox(ctx, bx + bw - 3, by + 6, 4, 8, palette); // Right Arm/Leg

    // 4. Draw Head (The main attraction)
    // Ears
    drawShadedBox(ctx, hx, hy - 3, 5, 4, palette); // Left Ear
    drawShadedBox(ctx, hx + hw - 5, hy - 3, 5, 4, palette); // Right Ear

    // Main Face Block
    drawShadedBox(ctx, hx, hy, hw, hh, palette);

    // Snout (Protruding)
    const snoutColor = {
        base: palette.highlight, // Snout is usually lighter
        highlight: '#FFF',
        shadow: palette.base,
        darkShadow: palette.shadow
    };
    drawShadedBox(ctx, hx + 6, hy + 5, 8, 5, snoutColor);

    // Nose
    drawPixel(ctx, hx + 9, hy + 6, '#000');
    drawPixel(ctx, hx + 10, hy + 6, '#000');

    // Mouth
    // simple line
    drawPixel(ctx, hx + 9, hy + 8, '#333');
    drawPixel(ctx, hx + 10, hy + 8, '#333');

    // 5. Eyes (Emotive)
    const eyeColor = '#000';
    // Left Eye
    fillRect(ctx, hx + 3, hy + 4, 3, 3, eyeColor);
    drawPixel(ctx, hx + 4, hy + 4, '#FFF'); // Shine
    // Right Eye
    fillRect(ctx, hx + hw - 6, hy + 4, 3, 3, eyeColor);
    drawPixel(ctx, hx + hw - 5, hy + 4, '#FFF'); // Shine

    // 6. Accessories
    if (Math.random() > 0.7) {
        // Sunglasses
        traits.face = "Sunglasses";
        ctx.fillStyle = '#111';
        fillRect(ctx, hx + 2, hy + 4, 6, 3, '#111');
        fillRect(ctx, hx + hw - 8, hy + 4, 6, 3, '#111');
        fillRect(ctx, hx + 8, hy + 5, 4, 1, '#111'); // Bridge
        // Reflection
        drawPixel(ctx, hx + 3, hy + 4, '#555');
        drawPixel(ctx, hx + hw - 7, hy + 4, '#555');
    }

    if (Math.random() > 0.8) {
        // Crown
        traits.head = "King's Crown";
        const cx = hx + 4;
        const cy = hy - 6;
        fillRect(ctx, cx, cy, 12, 4, '#FFD700'); // Gold Band
        drawPixel(ctx, cx + 2, cy - 1, '#FFD700');
        drawPixel(ctx, cx + 6, cy - 2, '#FFD700'); // Peak
        drawPixel(ctx, cx + 10, cy - 1, '#FFD700');
        // Gem
        drawPixel(ctx, cx + 6, cy + 1, '#FF0000'); // Ruby
    } else if (Math.random() > 0.8) {
        // Halo
        traits.head = "Angel Halo";
        const cx = hx + 4;
        const cy = hy - 6;
        fillRect(ctx, cx, cy, 12, 1, '#FFFF00'); // Gold ring front
        // Floating effect simulated by shadow
    }

    // 7. Clothing
    if (Math.random() > 0.5) {
        const clothes = ['Tuxedo', 'Cape', 'Gold Chain'];
        const cloth = clothes[Math.floor(Math.random() * clothes.length)];
        traits.clothing = cloth;

        if (cloth === 'Tuxedo') {
            // Jacket
            fillRect(ctx, bx + 2, by + 2, bw - 4, bh - 2, '#111');
            // White shirt V
            fillRect(ctx, bx + 6, by + 2, 4, 4, '#FFF');
            // Bowtie
            fillRect(ctx, bx + 7, by + 3, 2, 1, '#FF0000');
        } else if (cloth === 'Gold Chain') {
            // Chain loop
            ctx.fillStyle = '#FFD700';
            drawPixel(ctx, bx + 4, by + 1, '#FFD700');
            drawPixel(ctx, bx + 11, by + 1, '#FFD700');
            drawPixel(ctx, bx + 5, by + 3, '#FFD700');
            drawPixel(ctx, bx + 10, by + 3, '#FFD700');
            fillRect(ctx, bx + 6, by + 4, 4, 4, '#FFD700'); // Medallion
        }
    }

    return traits;
}

// --- EXECUTION ---
async function main() {
    console.log("Starting LEGENDARY BEAR generation...");
    ensureDir(imagesDir);
    ensureDir(metadataDir);

    for (let i = 1; i <= editionSize; i++) {
        const canvas = createCanvas(width, height);
        const ctx = canvas.getContext('2d');
        ctx.imageSmoothingEnabled = false;

        const traits = drawLegendaryBear(ctx);

        // Save Image
        const buffer = canvas.toBuffer('image/png');
        fs.writeFileSync(path.join(imagesDir, `${i}.png`), buffer);

        // Save Metadata
        const metadata = {
            name: `Legendary Pixel Bear #${i}`,
            description: "A high-fidelity Legendary Pixel Bear.",
            image: `${i}.png`,
            attributes: Object.entries(traits).map(([k, v]) => ({ trait_type: k, value: v }))
        };
        fs.writeFileSync(path.join(metadataDir, `${i}.json`), JSON.stringify(metadata, null, 2));

        if (i % 10 === 0) process.stdout.write('.');
    }
    console.log(`\nDONE. Generated ${editionSize} Legendary Bears in ${outputDir}`);
}

main().catch(console.error);
