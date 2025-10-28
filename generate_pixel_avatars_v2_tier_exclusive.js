import fs from 'fs';
import path from 'path';
import { createCanvas } from 'canvas';
import { fileURLToPath } from 'url';
import crypto from 'crypto';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const pixelSize = 24;
const scale = 20;
const width = pixelSize * scale;
const height = pixelSize * scale;
const editionSize = 1000; // TEST batch

const outputDir = path.join(__dirname, 'pixel_avatars_v2_tier_exclusive_output');
const imagesDir = path.join(outputDir, 'images');
const metadataDir = path.join(outputDir, 'metadata');

// Set to track generated avatar hashes for uniqueness
const generatedHashes = new Set();

// Define the expanded 15-tier rarity system for TEST (1000)
const rarityTiers = [
	{ name: 'Primordial', quantity: 5 },      // Top 5
	{ name: 'Eternal', quantity: 15 },        // Next 15
	{ name: 'Mythic', quantity: 30 },         // Next 30
	{ name: 'Divine', quantity: 50 },         // Next 50
	{ name: 'Celestial', quantity: 100 },     // Next 100
	{ name: 'Transcendent', quantity: 100 },  // Next 100
	{ name: 'Legendary', quantity: 100 },     // Next 100
	{ name: 'Epic', quantity: 100 },          // Next 100
	{ name: 'Superior', quantity: 100 },      // Next 100
	{ name: 'Rare', quantity: 100 },          // Next 100
	{ name: 'Uncommon', quantity: 100 },      // Next 100
	{ name: 'Common', quantity: 100 },        // Next 100
	{ name: 'Standard', quantity: 50 },       // Next 50
	{ name: 'Basic', quantity: 40 },          // Next 40
	{ name: 'Starter', quantity: 10 }         // Last 10
];

// Character power level ranges by tier
const powerRanges = {
	'Primordial': { min: 98, max: 100 },
	'Eternal': { min: 95, max: 97 },
	'Mythic': { min: 90, max: 94 },
	'Divine': { min: 85, max: 89 },
	'Celestial': { min: 80, max: 84 },
	'Transcendent': { min: 75, max: 79 },
	'Legendary': { min: 68, max: 74 },
	'Epic': { min: 60, max: 67 },
	'Superior': { min: 52, max: 59 },
	'Rare': { min: 44, max: 51 },
	'Uncommon': { min: 36, max: 43 },
	'Common': { min: 28, max: 35 },
	'Standard': { min: 20, max: 27 },
	'Basic': { min: 12, max: 19 },
	'Starter': { min: 5, max: 11 }
};

// Character class types based on traits
const characterClasses = [
	'Warrior', 'Mage', 'Rogue', 'Paladin', 'Ranger',
	'Necromancer', 'Druid', 'Bard', 'Monk', 'Guardian'
];

// Origins for lore
const origins = [
	'Aetheria', 'Shadowvale', 'Crystal Peaks', 'Emberforge', 'Mistral Isles',
	'Nova Sanctum', 'Dusk Haven', 'Arcane Nexus', 'Verdant Wild', 'Void Frontier'
];

// TIER-EXCLUSIVE TRAIT OPTIONS - EXPANDED FOR 100K COLLECTION
// Each tier has completely unique items to create visual distinction
const tierExclusiveTraits = {
	'Primordial': {
		// GOD TIER - Ultra legendary items ONLY Primordial gets
		headwear: ['diamond crown', 'cosmic helmet', 'infinity crown'],
		pet: ['ancient dragon', 'cosmic phoenix', 'reality beast'],
		item: ['excalibur', 'infinity gauntlet', 'reality stone', 'cosmic staff'],
		faceAccessory: ['legendary mask', 'reality visor', 'cosmic eye'],
		neckAccessory: ['diamond chain', 'infinity necklace', 'cosmic pendant']
	},
	'Eternal': {
		// ANGEL TIER - Legendary items, second only to Primordial
		headwear: ['golden crown', 'platinum helmet', 'crystal tiara', 'celestial halo'],
		pet: ['alien', 'spirit dragon', 'robot companion', 'white phoenix'],
		item: ['holy sword', 'divine shield', 'sacred staff', 'crystal blade'],
		faceAccessory: ['golden mask', 'crystal visor', 'holy tattoo'],
		neckAccessory: ['platinum chain', 'silver pendant', 'sacred amulet']
	},
	'Mythic': {
		// MYTHIC TIER - Powerful legendary items
		headwear: ['battle helm', 'demon horns', 'angel wings', 'war crown', 'samurai helmet'],
		pet: ['black panther', 'white tiger', 'mystic fox', 'lightning hawk', 'shadow wolf'],
		item: ['obsidian blade', 'thunder hammer', 'death scythe', 'magic grimoire', 'fire staff'],
		faceAccessory: ['battle mask', 'demon mask', 'war paint stripes', 'mystic tattoo'],
		neckAccessory: ['metal chain', 'spiked collar', 'mystic amulet', 'battle scarf']
	},
	'Divine': {
		// DIVINE TIER - High-tier epic items
		headwear: ['knight helmet', 'viking helmet', 'wizard hat', 'royal bandana', 'top hat'],
		pet: ['eagle', 'owl', 'raven', 'wolf', 'snake', 'falcon'],
		item: ['enchanted sword', 'battle axe', 'war hammer', 'spell tome', 'crystal wand'],
		faceAccessory: ['face tattoos', 'complex war paint', 'multiple piercings', 'tribal marks'],
		neckAccessory: ['silk scarf', 'fancy tie', 'medal', 'badge', 'gemstone necklace']
	},
	'Celestial': {
		// CELESTIAL TIER - Good quality items
		headwear: ['baseball cap', 'beanie', 'fedora', 'beret', 'cowboy hat', 'bucket hat'],
		pet: ['bird', 'parrot', 'hawk', 'crow', 'dove'],
		item: ['knight sword', 'iron shield', 'steel axe', 'mage staff', 'crossbow', 'bow'],
		faceAccessory: ['sunglasses', 'goggles', 'eyepatch', 'simple war paint'],
		neckAccessory: ['wool scarf', 'simple tie', 'necklace', 'choker']
	},
	'Transcendent': {
		// TRANSCENDENT TIER - Above average items
		headwear: ['cap', 'snapback', 'trucker cap', 'visor', 'headband', 'bandana'],
		pet: ['cat', 'dog', 'rabbit', 'bird', 'none'],
		item: ['sword', 'dagger', 'staff', 'book', 'tablet', 'gadget'],
		faceAccessory: ['glasses', 'reading glasses', 'scars', 'freckles', 'none'],
		neckAccessory: ['simple chain', 'dog tag', 'pendant', 'scarf', 'none']
	},
	'Legendary': {
		// LEGENDARY TIER - Decent items
		headwear: ['cap', 'beanie', 'headband', 'hair clips', 'none'],
		pet: ['small bird', 'mouse', 'squirrel', 'hamster', 'none'],
		item: ['phone', 'laptop', 'book', 'notebook', 'drink', 'none'],
		faceAccessory: ['simple glasses', 'beauty mark', 'small scar', 'none'],
		neckAccessory: ['tie', 'scarf', 'simple necklace', 'none']
	},
	'Epic': {
		// EPIC TIER - Basic+ items
		headwear: ['cap', 'beanie', 'none'],
		pet: ['butterfly', 'ladybug', 'small bug', 'none'],
		item: ['coffee', 'soda', 'water bottle', 'book', 'phone', 'none'],
		faceAccessory: ['none'],
		neckAccessory: ['tie', 'none']
	},
	'Superior': {
		// SUPERIOR TIER - Mostly empty with occasional basic items
		headwear: ['cap', 'none'],
		pet: ['none'],
		item: ['drink', 'coffee', 'none'],
		faceAccessory: ['none'],
		neckAccessory: ['none']
	},
	'Rare': {
		// RARE TIER - Very basic
		headwear: ['none', 'cap'],
		pet: ['none'],
		item: ['drink', 'none'],
		faceAccessory: ['none'],
		neckAccessory: ['none']
	},
	'Uncommon': {
		// UNCOMMON TIER - Almost nothing
		headwear: ['none'],
		pet: ['none'],
		item: ['drink', 'none'],
		faceAccessory: ['none'],
		neckAccessory: ['none']
	},
	'Common': {
		// COMMON TIER - Rarely anything
		headwear: ['none'],
		pet: ['none'],
		item: ['none', 'drink'],
		faceAccessory: ['none'],
		neckAccessory: ['none']
	},
	'Standard': {
		// STANDARD TIER - Empty
		headwear: ['none'],
		pet: ['none'],
		item: ['none'],
		faceAccessory: ['none'],
		neckAccessory: ['none']
	},
	'Basic': {
		// BASIC TIER - Empty
		headwear: ['none'],
		pet: ['none'],
		item: ['none'],
		faceAccessory: ['none'],
		neckAccessory: ['none']
	},
	'Starter': {
		// STARTER TIER - Completely empty
		headwear: ['none'],
		pet: ['none'],
		item: ['none'],
		faceAccessory: ['none'],
		neckAccessory: ['none']
	}
};

// Calculate total tier quantity
const totalTierQuantity = rarityTiers.reduce((sum, tier) => sum + tier.quantity, 0);

function ensureDir(dir) {
	fs.mkdirSync(dir, { recursive: true });
}

function pastelColor() {
	const hue = Math.floor(Math.random() * 360);
	return `hsl(${hue}, 70%, 85%)`;
}

function hslToRgb(h, s, l) {
	s /= 100;
	l /= 100;
	const k = n => (n + h / 30) % 12;
	const a = s * Math.min(l, 1 - l);
	const f = n =>
		l - a * Math.max(-1, Math.min(k(n) - 3, 9 - k(n), 1));
	return [
		Math.round(255 * f(0)),
		Math.round(255 * f(8)),
		Math.round(255 * f(4))
	];
}

function luminanceFromHSL(hsl) {
	const match = /hsl\((\d+),\s*(\d+)%?,\s*(\d+)%?\)/.exec(hsl);
	if (!match) return 1;
	const h = parseInt(match[1]);
	const s = parseInt(match[2]);
	const l = parseInt(match[3]);
	const [r, g, b] = hslToRgb(h, s, l);
	return 0.299 * r + 0.587 * g + 0.114 * b;
}

// WEIGHTED TRAIT SYSTEM - Rarer traits have lower probability
const traitProbabilities = {
	headwear: {
		'none': 0.40,      // 40% - Most common
		'cap': 0.25,       // 25%
		'bandana': 0.20,   // 20%
		'helmet': 0.10,    // 10%
		'crown': 0.05      // 5% - Rarest
	},
	pet: {
		'none': 0.50,      // 50%
		'bird': 0.25,      // 25%
		'robot': 0.15,     // 15%
		'alien': 0.10      // 10% - Rarest
	},
	item: {
		'none': 0.35,      // 35%
		'drink': 0.25,     // 25%
		'gadget': 0.15,    // 15%
		'book': 0.12,      // 12%
		'shield': 0.08,    // 8%
		'sword': 0.05      // 5% - Rarest
	},
	clothing: {
		't-shirt': 0.30,   // 30%
		'hoodie': 0.25,    // 25%
		'jacket': 0.20,    // 20%
		'dress': 0.15,     // 15%
		'armor': 0.10      // 10% - Rarest
	},
	backgroundPattern: {
		'none': 0.40,      // 40%
		'stripes': 0.25,   // 25%
		'dots': 0.20,      // 20%
		'grid': 0.10,      // 10%
		'stars': 0.05      // 5% - Rarest
	},
	faceAccessory: {
		'none': 0.50,      // 50%
		'war paint': 0.20, // 20%
		'scars': 0.15,     // 15%
		'piercings': 0.10, // 10%
		'mask': 0.05       // 5% - Rarest
	},
	neckAccessory: {
		'none': 0.55,      // 55%
		'tie': 0.20,       // 20%
		'scarf': 0.15,     // 15%
		'chain': 0.10      // 10% - Rarest
	}
};

// Weighted random selection based on probabilities
function weightedRandom(probabilities) {
	const rand = Math.random();
	let cumulative = 0;

	for (const [value, probability] of Object.entries(probabilities)) {
		cumulative += probability;
		if (rand < cumulative) {
			return value;
		}
	}

	// Fallback to first option
	return Object.keys(probabilities)[0];
}

// Helper function to select random item from tier-exclusive array
function randomChoice(array) {
	return array[Math.floor(Math.random() * array.length)];
}

// Get tier-exclusive trait for a specific category
function getTierExclusiveTrait(tierName, traitCategory) {
	if (!tierName || !tierExclusiveTraits[tierName]) {
		return 'none'; // Fallback
	}
	const options = tierExclusiveTraits[tierName][traitCategory];
	if (!options || options.length === 0) {
		return 'none';
	}
	return randomChoice(options);
}

function chance(probability) {
	return Math.random() < probability;
}

function drawOutline(ctx, x, y, w, h, color) {
	ctx.fillStyle = color;
	ctx.fillRect((x-1)*scale, y*scale, scale, scale*h);
	ctx.fillRect((x+w)*scale, y*scale, scale, scale*h);
	ctx.fillRect(x*scale, (y-1)*scale, scale*w, scale);
	ctx.fillRect(x*scale, (y+h)*scale, scale*w, scale);
}

// NEW: Calculate TRUE rarity score based on trait probabilities
function calculateRarityScore(traits) {
	let score = 0;

	// Score based on actual probability of each trait
	if (traits.headwear && traitProbabilities.headwear[traits.headwear]) {
		score += (1 - traitProbabilities.headwear[traits.headwear]) * 100;
	}

	if (traits.pet && traitProbabilities.pet[traits.pet]) {
		score += (1 - traitProbabilities.pet[traits.pet]) * 100;
	}

	if (traits.item && traitProbabilities.item[traits.item]) {
		score += (1 - traitProbabilities.item[traits.item]) * 100;
	}

	if (traits.clothing && traitProbabilities.clothing[traits.clothing]) {
		score += (1 - traitProbabilities.clothing[traits.clothing]) * 80;
	}

	if (traits.backgroundPattern && traitProbabilities.backgroundPattern[traits.backgroundPattern]) {
		score += (1 - traitProbabilities.backgroundPattern[traits.backgroundPattern]) * 60;
	}

	if (traits.faceAccessory && traitProbabilities.faceAccessory[traits.faceAccessory]) {
		score += (1 - traitProbabilities.faceAccessory[traits.faceAccessory]) * 100;
	}

	if (traits.neckAccessory && traitProbabilities.neckAccessory[traits.neckAccessory]) {
		score += (1 - traitProbabilities.neckAccessory[traits.neckAccessory]) * 60;
	}

	// Ultra-rare trait combinations get massive bonuses
	if (traits.headwear === 'crown' && traits.pet === 'alien') score += 200;
	if (traits.item === 'sword' && traits.clothing === 'armor') score += 150;
	if (traits.faceAccessory === 'mask' && traits.backgroundPattern === 'stars') score += 180;
	if (traits.headwear === 'crown' && traits.neckAccessory === 'chain') score += 160;
	if (traits.pet === 'alien' && traits.item === 'sword') score += 140;
	if (traits.pet === 'robot' && traits.backgroundPattern === 'stars') score += 120;

	// Specific color combos that are very rare
	if (traits.eyeColor === '#FFFF99' && traits.faceAccessory === 'mask') score += 100;
	if (traits.bodyColor === '#330066' && traits.eyeColor === '#FFFF99') score += 90;
	if (traits.clothingColor === '#663300' && traits.headwear === 'crown') score += 85;

	return score;
}

function drawAvatar(ctx, tierName = null) {
	const traits = {};

	// Background gradient
	const color1 = pastelColor();
	const color2 = pastelColor();
	traits.background = `gradient ${color1} to ${color2}`;
	const gradient = ctx.createLinearGradient(0, 0, width, height);
	gradient.addColorStop(0, color1);
	gradient.addColorStop(1, color2);
	ctx.fillStyle = gradient;
	ctx.fillRect(0, 0, width, height);

	// Background pattern type - WEIGHTED
	const bgPattern = weightedRandom(traitProbabilities.backgroundPattern);
	traits.backgroundPattern = bgPattern;
	if (bgPattern === 'stars') {
		for (let i = 0; i < 30; i++) {
			ctx.fillStyle = '#fff';
			ctx.beginPath();
			ctx.arc(Math.random()*width, Math.random()*height, 3, 0, Math.PI*2);
			ctx.fill();
		}
	} else if (bgPattern === 'stripes') {
		for (let i = 0; i < width; i += 40) {
			ctx.fillStyle = 'rgba(255,255,255,0.2)';
			ctx.fillRect(i, 0, 20, height);
		}
	} else if (bgPattern === 'dots') {
		for (let y = 0; y < height; y += 40) {
			for (let x = 0; x < width; x += 40) {
				ctx.fillStyle = 'rgba(255,255,255,0.2)';
				ctx.beginPath();
				ctx.arc(x, y, 5, 0, Math.PI*2);
				ctx.fill();
			}
		}
	} else if (bgPattern === 'grid') {
		ctx.strokeStyle = 'rgba(255,255,255,0.2)';
		for (let i = 0; i < width; i += 40) {
			ctx.beginPath();
			ctx.moveTo(i, 0);
			ctx.lineTo(i, height);
			ctx.stroke();
		}
		for (let i = 0; i < height; i += 40) {
			ctx.beginPath();
			ctx.moveTo(0, i);
			ctx.lineTo(width, i);
			ctx.stroke();
		}
	}

	// Calculate average background luminance
	const lum1 = luminanceFromHSL(color1);
	const lum2 = luminanceFromHSL(color2);
	const avgLum = (lum1 + lum2) / 2;

	// Contrasting palette
	let charPalette;
	if (avgLum > 128) {
		charPalette = ['#222222', '#333333', '#444444', '#555555', '#660000', '#003366', '#330066', '#006600', '#663300'];
	} else {
		charPalette = ['#DDDDDD', '#CCCCCC', '#BBBBBB', '#AAAAAA', '#FFFF99', '#FFCCFF', '#CCFFFF', '#99FFCC', '#FF9999'];
	}
	function pickCharColor() {
		return charPalette[Math.floor(Math.random() * charPalette.length)];
	}

	// Body
	const bodyColor = pickCharColor();
	traits.bodyColor = bodyColor;
	drawOutline(ctx, 8, 8, 8, 8, '#000');
	ctx.fillStyle = bodyColor;
	ctx.fillRect(8*scale, 8*scale, 8*scale, 8*scale);

	// Eyes
	const eyeColor = pickCharColor();
	traits.eyeColor = eyeColor; // Assign trait
	ctx.fillStyle = '#000'; // Eye outline/socket
	ctx.fillRect(10*scale - 2, 11*scale - 2, scale + 4, scale + 4);
	ctx.fillRect(13*scale - 2, 11*scale - 2, scale + 4, scale + 4);
	ctx.fillStyle = eyeColor; // Eye pupil/iris
	ctx.fillRect(10*scale, 11*scale, scale, scale);
	ctx.fillRect(13*scale, 11*scale, scale, scale);

	// --- Decide conditional traits early - TIER-EXCLUSIVE ---
	const headwear = getTierExclusiveTrait(tierName, 'headwear');
	traits.headwear = headwear;

	const faceAccessory = getTierExclusiveTrait(tierName, 'faceAccessory');
	traits.faceAccessory = faceAccessory;
	// --- End conditional trait decisions ---

	// Hair (conditional on headwear)
	if (headwear !== 'helmet') {
		const hairColor = pickCharColor();
		traits.hairColor = hairColor; // Assign trait
		drawOutline(ctx, 7, 6, 10, 2, '#000');
		ctx.fillStyle = hairColor;
		for (let y = 6; y < 8; y++) {
			for (let x = 7; x < 17; x++) {
				ctx.fillRect(x*scale, y*scale, scale, scale);
			}
		}
	} else {
		traits.hairColor = 'None (Hidden)'; // Indicate hidden trait in metadata
	}

	// Headwear (drawing)
	let headwearColor = 'none';
	if (headwear === 'cap') {
		headwearColor = pickCharColor();
		ctx.fillStyle = headwearColor;
		ctx.fillRect(7*scale, 5*scale, 10*scale, scale); // Position relative to hair/head
	} else if (headwear === 'crown') {
		headwearColor = '#FFD700';
		ctx.fillStyle = headwearColor;
		ctx.fillRect(8*scale, 4*scale, 8*scale, scale); // Position relative to hair/head
	} else if (headwear === 'helmet') {
		headwearColor = '#888888';
		ctx.fillStyle = headwearColor;
		ctx.fillRect(7*scale, 5*scale, 10*scale, 2*scale); // Covers hair area
	} else if (headwear === 'bandana') {
		headwearColor = pickCharColor();
		ctx.fillStyle = headwearColor;
		ctx.fillRect(7*scale, 6*scale, 10*scale, scale/2); // Position relative to hair/head
	}
	if (headwear !== 'none') traits.headwearColor = headwearColor; // Add color trait if applicable


	// Mouth (conditional on face accessory)
	if (faceAccessory !== 'mask') {
		const mouthColor = pickCharColor();
		traits.mouthColor = mouthColor; // Assign trait
		ctx.fillStyle = '#000'; // Outline
		ctx.fillRect(11*scale - 2, 14*scale - 2, scale*2 + 4, scale/2 + 4);
		ctx.fillStyle = mouthColor; // Fill
		ctx.fillRect(11*scale, 14*scale, scale*2, scale/2);
	} else {
		traits.mouthColor = 'None (Hidden)'; // Indicate hidden trait in metadata
	}

	// Face accessories (drawing)
	let faceAccessoryColor = 'none';
	if (faceAccessory === 'mask') {
		faceAccessoryColor = '#555555';
		ctx.fillStyle = faceAccessoryColor;
		ctx.fillRect(9*scale, 13*scale, scale*6, scale*2); // Covers mouth area
	} else if (faceAccessory === 'piercings') {
		faceAccessoryColor = '#FFD700';
		ctx.fillStyle = faceAccessoryColor;
		ctx.fillRect(7*scale, 12*scale, scale/2, scale/2);
		ctx.fillRect(16*scale, 12*scale, scale/2, scale/2);
	} else if (faceAccessory === 'scars') {
		faceAccessoryColor = '#800000'; // Color of the scar line
		ctx.strokeStyle = faceAccessoryColor;
		ctx.lineWidth = 2;
		ctx.beginPath();
		ctx.moveTo(10*scale, 10*scale); // Example scar position
		ctx.lineTo(11*scale, 11*scale);
		ctx.stroke();
		ctx.lineWidth = 1; // Reset line width
	} else if (faceAccessory === 'war paint') {
		faceAccessoryColor = '#ff0000';
		ctx.fillStyle = faceAccessoryColor;
		ctx.fillRect(9*scale, 12*scale, scale/2, scale/2); // Example paint position
		ctx.fillRect(14*scale, 12*scale, scale/2, scale/2);
	}
	if (faceAccessory !== 'none') traits.faceAccessoryColor = faceAccessoryColor; // Add color trait if applicable


	// Neck accessories - TIER-EXCLUSIVE
	const neckAccessory = getTierExclusiveTrait(tierName, 'neckAccessory');
	traits.neckAccessory = neckAccessory;
	let neckAccessoryColor = 'none';
	if (neckAccessory === 'chain') {
		neckAccessoryColor = '#FFD700';
		ctx.fillStyle = neckAccessoryColor;
		ctx.fillRect(9*scale, 16*scale + scale/2, scale*6, scale/4);
	} else if (neckAccessory === 'tie') {
		neckAccessoryColor = '#0000ff';
		ctx.fillStyle = neckAccessoryColor;
		ctx.fillRect(11*scale, 16*scale, scale*2, scale*4); // Might clash with clothing
	} else if (neckAccessory === 'scarf') {
		neckAccessoryColor = pickCharColor();
		ctx.fillStyle = neckAccessoryColor;
		ctx.fillRect(8*scale, 16*scale, scale*8, scale); // Might clash with clothing
	}
    if (neckAccessory !== 'none') traits.neckAccessoryColor = neckAccessoryColor; // Add color trait if applicable


	// Clothing - WEIGHTED
	const clothing = weightedRandom(traitProbabilities.clothing);
	traits.clothing = clothing;
	const clothingColor = pickCharColor();
	traits.clothingColor = clothingColor; // Assign trait
	ctx.fillStyle = clothingColor;
	// Basic clothing rect - could be improved based on type
	for (let y = 16; y < 20; y++) {
		for (let x = 8; x < 16; x++) {
			ctx.fillRect(x*scale, y*scale, scale, scale);
		}
	}
	// TODO: Add logic here to draw different clothing shapes?
	// TODO: Add logic to handle clashes between clothing and neck accessories? (e.g., draw neck accessory after clothing if it's a tie/scarf?)


	// Handheld items - TIER-EXCLUSIVE
	const item = getTierExclusiveTrait(tierName, 'item');
	traits.item = item;
	let itemColor = 'none'; // Or primary color
	if (item === 'sword') {
		itemColor = '#cccccc';
		ctx.fillStyle = itemColor; // Blade
		ctx.fillRect(15*scale, 12*scale, scale/2, scale*4);
		ctx.fillStyle = '#900'; // Hilt
		ctx.fillRect(14*scale, 14*scale, scale*2, scale/2);
	} else if (item === 'shield') {
		itemColor = '#888888';
		ctx.fillStyle = itemColor;
		ctx.fillRect(7*scale, 12*scale, scale*2, scale*4);
	} else if (item === 'drink') {
		itemColor = '#00ffff';
		ctx.fillStyle = itemColor; // Drink
		ctx.fillRect(15*scale, 14*scale, scale, scale*2);
		ctx.fillStyle = '#ffffff'; // Top/Straw?
		ctx.fillRect(15*scale, 13*scale, scale, scale/2);
	} else if (item === 'book') {
		itemColor = '#964B00';
		ctx.fillStyle = itemColor;
		ctx.fillRect(7*scale, 14*scale, scale*2, scale*3);
	} else if (item === 'gadget') {
		itemColor = '#00ffff';
		ctx.fillStyle = itemColor;
		ctx.fillRect(15*scale, 12*scale, scale, scale*2);
	}
    if (item !== 'none') traits.itemColor = itemColor; // Add color trait if applicable


	// Pets - TIER-EXCLUSIVE
	const pet = getTierExclusiveTrait(tierName, 'pet');
	traits.pet = pet;
	let petColor = 'none';
	if (pet === 'bird') {
		petColor = '#ffff00';
		ctx.fillStyle = petColor;
		ctx.fillRect(10*scale, 20*scale, scale*2, scale*2);
	} else if (pet === 'robot') {
		petColor = '#888888';
		ctx.fillStyle = petColor;
		ctx.fillRect(12*scale, 20*scale, scale*2, scale*2);
	} else if (pet === 'alien') {
		petColor = '#00ff00';
		ctx.fillStyle = petColor;
		ctx.fillRect(14*scale, 20*scale, scale*2, scale*2);
	}
    if (pet !== 'none') traits.petColor = petColor; // Add color trait if applicable

    // VISUALIZE NEW METADATA: Add visual elements based on tier and class
    if (tierName) {
        // Determine affinity based on color combinations
        let affinity = 'Nature'; // default
        if (bodyColor === '#660000' || clothingColor === '#660000') {
            affinity = 'Fire';
        } else if (eyeColor === '#CCFFFF' || itemColor === '#00ffff') {
            affinity = 'Water';
        } else if (bodyColor === '#663300' || clothingColor === '#663300') {
            affinity = 'Earth';
        } else if (bgPattern === 'stars') {
            affinity = 'Air';
        } else if (eyeColor === '#FFFF99') {
            affinity = 'Light';
        } else if (faceAccessory === 'mask') {
            affinity = 'Shadow';
        } else if (petColor === '#00ff00') {
            affinity = 'Arcane';
        } else if (headwear === 'crown') {
            affinity = 'Lightning';
        }
        
        // Store affinity in traits without drawing the visual elements
        traits.affinity = affinity;
        
        // We're keeping the metadata but not drawing the visual elements
        // No tier emblem, no border, no class emblem, no affinity circle, no aura
    }

	return traits;
}

// Generate character attributes based on NFT traits
function generateCharacterAttributes(traits, tierName) {
	// Determine class based on traits
	let characterClass = '';
	
	if (traits.item === 'sword' || traits.item === 'shield') {
		characterClass = Math.random() > 0.5 ? 'Warrior' : 'Paladin';
	} else if (traits.item === 'book') {
		characterClass = Math.random() > 0.5 ? 'Mage' : 'Necromancer';
	} else if (traits.headwear === 'crown') {
		characterClass = 'Guardian';
	} else if (traits.pet === 'bird') {
		characterClass = 'Ranger';
	} else if (traits.pet === 'alien') {
		characterClass = 'Mage';
	} else if (traits.faceAccessory === 'mask') {
		characterClass = 'Rogue';
	} else if (traits.backgroundPattern === 'stars') {
		characterClass = 'Druid';
	} else {
		characterClass = characterClasses[Math.floor(Math.random() * characterClasses.length)];
	}
	
	// Calculate power level based on tier
	const range = powerRanges[tierName];
	const powerLevel = Math.floor(range.min + Math.random() * (range.max - range.min + 1));
	
	// Choose origin
	const origin = origins[Math.floor(Math.random() * origins.length)];
	
	// Generate stats based on class and power level
	const statTotal = powerLevel * 10;
	let strength, intelligence, dexterity, constitution, charisma;
	
	// Distribute stats based on class
	switch (characterClass) {
		case 'Warrior':
			strength = Math.floor(statTotal * 0.3);
			intelligence = Math.floor(statTotal * 0.1);
			dexterity = Math.floor(statTotal * 0.2);
			constitution = Math.floor(statTotal * 0.3);
			charisma = Math.floor(statTotal * 0.1);
			break;
		case 'Mage':
			strength = Math.floor(statTotal * 0.1);
			intelligence = Math.floor(statTotal * 0.4);
			dexterity = Math.floor(statTotal * 0.2);
			constitution = Math.floor(statTotal * 0.1);
			charisma = Math.floor(statTotal * 0.2);
			break;
		case 'Rogue':
			strength = Math.floor(statTotal * 0.2);
			intelligence = Math.floor(statTotal * 0.2);
			dexterity = Math.floor(statTotal * 0.4);
			constitution = Math.floor(statTotal * 0.1);
			charisma = Math.floor(statTotal * 0.1);
			break;
		case 'Paladin':
			strength = Math.floor(statTotal * 0.3);
			intelligence = Math.floor(statTotal * 0.2);
			dexterity = Math.floor(statTotal * 0.1);
			constitution = Math.floor(statTotal * 0.2);
			charisma = Math.floor(statTotal * 0.2);
			break;
		case 'Ranger':
			strength = Math.floor(statTotal * 0.2);
			intelligence = Math.floor(statTotal * 0.2);
			dexterity = Math.floor(statTotal * 0.3);
			constitution = Math.floor(statTotal * 0.2);
			charisma = Math.floor(statTotal * 0.1);
			break;
		case 'Necromancer':
			strength = Math.floor(statTotal * 0.1);
			intelligence = Math.floor(statTotal * 0.4);
			dexterity = Math.floor(statTotal * 0.1);
			constitution = Math.floor(statTotal * 0.2);
			charisma = Math.floor(statTotal * 0.2);
			break;
		case 'Druid':
			strength = Math.floor(statTotal * 0.2);
			intelligence = Math.floor(statTotal * 0.3);
			dexterity = Math.floor(statTotal * 0.1);
			constitution = Math.floor(statTotal * 0.3);
			charisma = Math.floor(statTotal * 0.1);
			break;
		case 'Bard':
			strength = Math.floor(statTotal * 0.1);
			intelligence = Math.floor(statTotal * 0.2);
			dexterity = Math.floor(statTotal * 0.2);
			constitution = Math.floor(statTotal * 0.1);
			charisma = Math.floor(statTotal * 0.4);
			break;
		case 'Monk':
			strength = Math.floor(statTotal * 0.2);
			intelligence = Math.floor(statTotal * 0.2);
			dexterity = Math.floor(statTotal * 0.3);
			constitution = Math.floor(statTotal * 0.2);
			charisma = Math.floor(statTotal * 0.1);
			break;
		case 'Guardian':
			strength = Math.floor(statTotal * 0.25);
			intelligence = Math.floor(statTotal * 0.2);
			dexterity = Math.floor(statTotal * 0.15);
			constitution = Math.floor(statTotal * 0.25);
			charisma = Math.floor(statTotal * 0.15);
			break;
		default:
			// Balanced stats
			strength = Math.floor(statTotal * 0.2);
			intelligence = Math.floor(statTotal * 0.2);
			dexterity = Math.floor(statTotal * 0.2);
			constitution = Math.floor(statTotal * 0.2);
			charisma = Math.floor(statTotal * 0.2);
	}
	
	const speed = dexterity + 50;
	const hp = constitution * 10;
	const mp = intelligence * 8;
	
	// Generate the character level (1-100)
	const level = Math.floor(powerLevel * 0.8 + Math.random() * 20);
	
	// Generate experience points
	const experiencePoints = Math.floor(level * level * 100 + Math.random() * 1000);
	
	// Generate a unique ID for the character
	const characterId = crypto.createHash('md5').update(`${Date.now()}-${Math.random()}`).digest('hex').substring(0, 8);
	
	// Calculate evolution tier (how many times it can evolve)
	const evolutionTier = Math.min(3, Math.floor(powerLevel / 30) + 1);
	
	// Determine if character has reached max level
	const maxLevel = (powerLevel >= 90);
	
	// Generate potential evolution forms
	const potentialEvolutions = [];
	if (evolutionTier < 3) {
		const upgradedClasses = {
			'Warrior': ['Berserker', 'Champion'],
			'Mage': ['Archmage', 'Elementalist'],
			'Rogue': ['Assassin', 'Shadow Dancer'],
			'Paladin': ['Holy Knight', 'Crusader'],
			'Ranger': ['Beast Master', 'Marksman'],
			'Necromancer': ['Lich', 'Soul Reaper'],
			'Druid': ['Archdruid', 'Shapeshifter'],
			'Bard': ['Maestro', 'Enchanter'],
			'Monk': ['Grandmaster', 'Ascendant'],
			'Guardian': ['Sentinel', 'Warden']
		};
		
		if (upgradedClasses[characterClass]) {
			potentialEvolutions.push(...upgradedClasses[characterClass]);
		}
	}
	
	// Generate badges/achievements based on character traits and tier
	const badges = [];
	if (powerLevel >= 90) badges.push('Legendary');
	if (level >= 50) badges.push('Veteran');
	if (strength >= 400) badges.push('Mighty');
	if (intelligence >= 400) badges.push('Genius');
	if (dexterity >= 400) badges.push('Swift');
	if (tierName === 'Mythic') badges.push('Mythical');
	if (tierName === 'Divine') badges.push('Divine');
	
	// Generate affinity (element the character is aligned with)
	const affinities = ['Fire', 'Water', 'Earth', 'Air', 'Light', 'Shadow', 'Nature', 'Arcane', 'Void', 'Lightning'];
	const affinity = affinities[Math.floor(Math.random() * affinities.length)];
	
	// Generate faction membership
	const factions = ['Order of Light', 'Shadow Conclave', 'Eternal Vanguard', 'Nature\'s Guardians', 'Arcane Society', 'Merchant Guild', 'Astral Seekers'];
	const faction = factions[Math.floor(Math.random() * factions.length)];
	
	return {
		class: characterClass,
		origin: origin,
		powerLevel: powerLevel,
		level: level,
		experiencePoints: experiencePoints,
		characterId: characterId,
		evolutionTier: evolutionTier,
		potentialEvolutions: potentialEvolutions,
		maxLevel: maxLevel,
		badges: badges,
		affinity: affinity,
		faction: faction,
		stats: {
			strength,
			intelligence,
			dexterity,
			constitution,
			charisma,
			speed,
			hp,
			mp
		},
		specialAbility: generateSpecialAbility(characterClass, tierName),
		secondaryAbilities: generateSecondaryAbilities(characterClass, tierName),
		generation: 1,
		mintDate: new Date().toISOString(),
		lastUpgraded: new Date().toISOString()
	};
}

// Generate secondary abilities based on class and tier
function generateSecondaryAbilities(characterClass, tierName) {
	const abilities = [];
	const tier = tierName.toLowerCase();
	const tierLevel = ['starter', 'basic', 'standard', 'common', 'uncommon', 'rare', 'superior', 'epic', 'legendary', 'transcendent', 'celestial', 'divine', 'mythic', 'eternal', 'primordial'].indexOf(tier);
	
	// Number of abilities based on tier (higher tier = more abilities)
	const numAbilities = Math.min(3, Math.max(1, Math.floor(tierLevel / 3) + 1));
	
	const classAbilities = {
		warrior: ['Bash', 'Charge', 'Intimidate', 'Disarm', 'Rally'],
		mage: ['Blink', 'Polymorph', 'Frost Armor', 'Counterspell', 'Arcane Intellect'],
		rogue: ['Vanish', 'Pickpocket', 'Evasion', 'Feint', 'Poison'],
		paladin: ['Lay on Hands', 'Divine Shield', 'Judgement', 'Consecration', 'Rebuke'],
		ranger: ['Track', 'Animal Companion', 'Camouflage', 'Quick Shot', 'Trap'],
		necromancer: ['Fear', 'Drain Life', 'Bone Spikes', 'Unholy Aura', 'Death Pact'],
		druid: ['Regrowth', 'Moonfire', 'Hibernate', 'Thorns', 'Nature\'s Grasp'],
		bard: ['Fascinate', 'Countersong', 'Inspire', 'Lullaby', 'Harmony'],
		monk: ['Meditate', 'Flurry', 'Stunning Strike', 'Deflect', 'Inner Peace'],
		guardian: ['Intervene', 'Challenging Shout', 'Last Stand', 'Shield Slam', 'Vigilance']
	};
	
	// Normalize class name to lowercase for lookup
	const classLower = characterClass.toLowerCase();
	
	// Get class abilities or default to warrior
	const availableAbilities = classAbilities[classLower] || classAbilities.warrior;
	
	// Shuffle available abilities and take the first numAbilities
	const shuffled = [...availableAbilities].sort(() => 0.5 - Math.random());
	abilities.push(...shuffled.slice(0, numAbilities));
	
	return abilities;
}

// Generate a special ability based on class and rarity tier
function generateSpecialAbility(characterClass, rarityTier) {
	const tier = rarityTier.toLowerCase();
	
	const abilities = {
		warrior: {
			primordial: "Universe Breaker",
			eternal: "Infinite Warfare",
			mythic: "Titan's Fury",
			divine: "Blade Storm",
			celestial: "Heroic Strike",
			transcendent: "Warrior's Ascension",
			legendary: "Crushing Blow",
			epic: "Mighty Swing",
			superior: "Enhanced Strike",
			rare: "Power Attack",
			uncommon: "Cleave",
			common: "Heavy Strike",
			standard: "Firm Slash",
			basic: "Basic Slash",
			starter: "Weak Swing"
		},
		mage: {
			primordial: "Reality Rewrite",
			eternal: "Cosmic Annihilation",
			mythic: "Arcane Singularity",
			divine: "Meteor Shower",
			celestial: "Astral Beam",
			transcendent: "Dimensional Rift",
			legendary: "Elemental Mastery",
			epic: "Fireball",
			superior: "Greater Blast",
			rare: "Frost Nova",
			uncommon: "Arcane Missiles",
			common: "Magic Bolt",
			standard: "Simple Spell",
			basic: "Spark",
			starter: "Cantrip"
		},
		rogue: {
			primordial: "Void Assassination",
			eternal: "Eternal Shadow",
			mythic: "Shadow Dance",
			divine: "Phantom Strike",
			celestial: "Thousand Cuts",
			transcendent: "Death's Embrace",
			legendary: "Deathmark",
			epic: "Backstab",
			superior: "Precise Strike",
			rare: "Venomous Strike",
			uncommon: "Stealth Attack",
			common: "Quick Slice",
			standard: "Swift Cut",
			basic: "Sneak",
			starter: "Poke"
		},
		paladin: {
			primordial: "God's Judgement",
			eternal: "Heaven's Decree",
			mythic: "Divine Intervention",
			divine: "Holy Wrath",
			celestial: "Sacred Shield",
			transcendent: "Radiant Ascension",
			legendary: "Righteous Fury",
			epic: "Holy Light",
			superior: "Blessed Aura",
			rare: "Divine Protection",
			uncommon: "Blessed Strike",
			common: "Healing Touch",
			standard: "Minor Blessing",
			basic: "Minor Heal",
			starter: "Prayer"
		},
		ranger: {
			primordial: "Nature's Apocalypse",
			eternal: "Infinite Hunt",
			mythic: "Arrow Storm",
			divine: "Piercing Shot",
			celestial: "Multishot",
			transcendent: "Beast Lord",
			legendary: "Hawk's Eye",
			epic: "Aimed Shot",
			superior: "Focused Shot",
			rare: "Trueshot",
			uncommon: "Quick Shot",
			common: "Steady Shot",
			standard: "Basic Shot",
			basic: "Simple Shot",
			starter: "Pebble Toss"
		},
		necromancer: {
			primordial: "End of All Life",
			eternal: "Eternal Undeath",
			mythic: "Army of the Dead",
			divine: "Soul Harvest",
			celestial: "Death Wave",
			transcendent: "Lich Transformation",
			legendary: "Bone Armor",
			epic: "Raise Dead",
			superior: "Soul Siphon",
			rare: "Life Drain",
			uncommon: "Curse",
			common: "Shadow Bolt",
			standard: "Dark Touch",
			basic: "Bone Spike",
			starter: "Spooky Gesture"
		},
		druid: {
			primordial: "Gaia's Wrath",
			eternal: "Primeval Evolution",
			mythic: "Force of Nature",
			divine: "Celestial Alignment",
			celestial: "Starfall",
			transcendent: "Ancient Guardian",
			legendary: "Wild Growth",
			epic: "Shapeshift",
			superior: "Nature's Call",
			rare: "Entangling Roots",
			uncommon: "Healing Seed",
			common: "Thorns",
			standard: "Leaf Swirl",
			basic: "Nature's Touch",
			starter: "Twig Snap"
		},
		bard: {
			primordial: "Universal Harmony",
			eternal: "Eternal Ballad",
			mythic: "Symphony of Destruction",
			divine: "Captivating Performance",
			celestial: "Harmonious Melody",
			transcendent: "Maestro's Opus",
			legendary: "Inspiring Anthem",
			epic: "Battle Hymn",
			superior: "Rousing Song",
			rare: "Healing Song",
			uncommon: "Soothing Tune",
			common: "Minor Chord",
			standard: "Simple Melody",
			basic: "Simple Note",
			starter: "Hum"
		},
		monk: {
			primordial: "One With Everything",
			eternal: "Perfect Enlightenment",
			mythic: "Transcendence",
			divine: "Spirit Burst",
			celestial: "Flying Dragon",
			transcendent: "Nirvana State",
			legendary: "Inner Peace",
			epic: "Flying Kick",
			superior: "Chi Burst",
			rare: "Chi Wave",
			uncommon: "Focused Strike",
			common: "Palm Strike",
			standard: "Basic Punch",
			basic: "Jab",
			starter: "Poke"
		},
		guardian: {
			primordial: "Cosmic Sentinel",
			eternal: "Eternal Bastion",
			mythic: "Eternal Vigilance",
			divine: "Guardian's Shield",
			celestial: "Protective Aura",
			transcendent: "Unbreakable Will",
			legendary: "Stalwart Defense",
			epic: "Defensive Stance",
			superior: "Strong Guard",
			rare: "Shield Wall",
			uncommon: "Taunt",
			common: "Block",
			standard: "Basic Defense",
			basic: "Defend",
			starter: "Cover"
		}
	};
	
	// Normalize class name to lowercase for lookup
	const classLower = characterClass.toLowerCase();
	
	// Default to warrior if class not found
	const classAbilities = abilities[classLower] || abilities.warrior;
	
	// Return ability based on tier, defaulting to basic if tier not found
	return classAbilities[tier] || classAbilities.basic;
}

async function main() {
	ensureDir(imagesDir);
	ensureDir(metadataDir);

	let duplicatesAvoided = 0;

	// Array to hold all NFTs
	const nftCollection = [];

	console.log("Pre-assigning tiers to all NFTs...\n");

	// PRE-ASSIGN TIERS FIRST - Then generate based on tier!
	let currentId = 1;
	for (const tier of rarityTiers) {
		for (let i = 0; i < tier.quantity; i++) {
			nftCollection.push({
				id: currentId,
				tierName: tier.name,
				rarityRank: currentId  // Rank matches tier order
			});
			currentId++;
		}
	}

	// Shuffle to randomize which IDs get which tiers
	for (let i = nftCollection.length - 1; i > 0; i--) {
		const j = Math.floor(Math.random() * (i + 1));
		[nftCollection[i], nftCollection[j]] = [nftCollection[j], nftCollection[i]];
	}

	console.log("Generating NFTs with tier-exclusive traits...\n");

	// NOW Generate each NFT based on its pre-assigned tier!
	for (let i = 0; i < nftCollection.length; i++) {
		const nft = nftCollection[i];
		const canvas = createCanvas(width, height);
		const ctx = canvas.getContext('2d');

		// Generate avatar WITH tier-exclusive traits from the start!
		const traits = drawAvatar(ctx, nft.tierName);

		// Save the image
		const buffer = canvas.toBuffer('image/png');
		const imageName = `${nft.id}.png`;
		fs.writeFileSync(path.join(imagesDir, imageName), buffer);

		// Calculate rarity score (optional, tier is the real rarity)
		const rarityScore = calculateRarityScore(traits);

		// Generate additional character attributes
		const characterAttributes = generateCharacterAttributes(traits, nft.tierName);

		// Create complete metadata
		const metadata = {
			name: `Pixel Avatar #${nft.id}`,
			description: "A unique procedurally generated pixel art avatar from BTB Finance",
			image: `${nft.id}.png`,
			edition: nft.id,
			rarityScore: rarityScore,
			attributes: Object.entries(traits).map(([trait_type, value]) => ({
				trait_type,
				value
			})),
			rarity: nft.tierName,
			rarityRank: nft.rarityRank,
			class: characterAttributes.class,
			origin: characterAttributes.origin,
			powerLevel: characterAttributes.powerLevel,
			level: characterAttributes.level,
			experiencePoints: characterAttributes.experiencePoints,
			characterId: characterAttributes.characterId,
			evolutionTier: characterAttributes.evolutionTier,
			potentialEvolutions: characterAttributes.potentialEvolutions,
			maxLevel: characterAttributes.maxLevel,
			badges: characterAttributes.badges,
			affinity: traits.affinity || characterAttributes.affinity,
			faction: characterAttributes.faction,
			stats: characterAttributes.stats,
			specialAbility: characterAttributes.specialAbility,
			secondaryAbilities: characterAttributes.secondaryAbilities,
			generation: characterAttributes.generation,
			mintDate: characterAttributes.mintDate,
			lastUpgraded: characterAttributes.lastUpgraded,
			uniqueHash: crypto.createHash('sha256').update(`${nft.id}-${Date.now()}`).digest('hex'),
			collection: "BTB Finance Pixel Avatars",
			universe: "BTB Finance Pixel Realm",
			publisher: "BTB Finance",
			sponsor: "BTB Finance",
			lore: generateCharacterLore(characterAttributes),
			tradeable: true,
			storyArc: generateStoryArc(characterAttributes),
			specialTraits: generateSpecialTraits(characterAttributes.class, nft.tierName),
			itemCompatibility: generateCompatibleItems(characterAttributes),
			btbTokenId: `BTB-${nft.tierName.toUpperCase()}-${nft.id.toString().padStart(5, '0')}`,
			btbFinanceCompatible: true
		};

		// Add tier and character attributes to metadata attributes array
		metadata.attributes.push({ trait_type: "Rarity Tier", value: nft.tierName });
		metadata.attributes.push({ trait_type: "Class", value: characterAttributes.class });
		metadata.attributes.push({ trait_type: "Origin", value: characterAttributes.origin });
		metadata.attributes.push({ trait_type: "Power Level", value: characterAttributes.powerLevel.toString() });
		metadata.attributes.push({ trait_type: "Level", value: characterAttributes.level.toString() });
		metadata.attributes.push({ trait_type: "Affinity", value: traits.affinity || characterAttributes.affinity });
		metadata.attributes.push({ trait_type: "Faction", value: characterAttributes.faction });
		metadata.attributes.push({ trait_type: "Evolution Tier", value: characterAttributes.evolutionTier.toString() });
		metadata.attributes.push({ trait_type: "Special Ability", value: characterAttributes.specialAbility });

		// Add badges
		characterAttributes.badges.forEach(badge => {
			metadata.attributes.push({ trait_type: "Badge", value: badge });
		});

		// Save metadata
		fs.writeFileSync(
			path.join(metadataDir, `${nft.id}.json`),
			JSON.stringify(metadata, null, 2)
		);

		// Progress logging
		if ((i + 1) % 100 === 0 || (i + 1) === nftCollection.length) {
			console.log(`Generated ${i + 1}/${nftCollection.length} NFTs`);
		}
	}
	
	// Output rarity distribution
	console.log("\n✅ Generation Complete!");
	console.log("\nTier Distribution:");

	rarityTiers.forEach(tier => {
		console.log(`${tier.name}: ${tier.quantity} NFTs`);
	});

	console.log("\n🎉 All NFTs generated with tier-exclusive traits!");
	console.log("Check the output folder to see Primordial NFTs with crowns and aliens!");
}

// Generate character lore based on attributes
function generateCharacterLore(attributes) {
	const { class: charClass, origin, faction, affinity, level, powerLevel } = attributes;
	
	// Define potential origin stories
	const originStories = {
		'Aetheria': `Born in the floating cities of Aetheria, where magic flows freely through crystalline spires.`,
		'Shadowvale': `Raised in the perpetual twilight of Shadowvale, where stealth and cunning are necessary for survival.`,
		'Crystal Peaks': `Forged in the harsh conditions of the Crystal Peaks, where only the strongest endure.`,
		'Emberforge': `Tempered in the volcanic forges of Emberforge, home to master craftsmen and fierce warriors.`,
		'Mistral Isles': `Hailing from the sea-swept Mistral Isles, where navigation and water magic are mastered from youth.`,
		'Nova Sanctum': `Educated in the ancient libraries of Nova Sanctum, repository of forgotten knowledge.`,
		'Dusk Haven': `A child of Dusk Haven, the borderlands where light and shadow magic intermingle.`,
		'Arcane Nexus': `Awakened at the Arcane Nexus, where ley lines converge and arcane power surges.`,
		'Verdant Wild': `Nurtured by the sentient forests of the Verdant Wild, where nature and beast live as one.`,
		'Void Frontier': `A survivor from the mysterious Void Frontier, touched by energies from beyond.`
	};
	
	// Define class-specific narratives
	const classNarratives = {
		'Warrior': `A formidable fighter who has mastered the art of combat through rigorous training and battlefield experience.`,
		'Mage': `A scholar of the arcane arts who can bend reality through careful study and innate magical talent.`,
		'Rogue': `A master of stealth and precision who strikes from the shadows and disappears without a trace.`,
		'Paladin': `A holy knight who channels divine energy to protect allies and smite enemies with righteous fury.`,
		'Ranger': `A wilderness expert who has formed a deep bond with nature and excels at tracking and ranged combat.`,
		'Necromancer': `A practitioner of forbidden magic who commands the forces of death and decay.`,
		'Druid': `A guardian of natural balance who can harness the primal forces of the world and shapeshift at will.`,
		'Bard': `A charismatic performer whose music carries magic capable of inspiring allies and confounding foes.`,
		'Monk': `A disciplined martial artist who has achieved harmony between body, mind, and spirit.`,
		'Guardian': `A steadfast protector sworn to defend the innocent and uphold sacred oaths at any cost.`
	};
	
	// Define faction purposes
	const factionPurposes = {
		'Order of Light': `Sworn to the Order of Light, guardians of truth and justice across the realms.`,
		'Shadow Conclave': `A trusted agent of the Shadow Conclave, masters of espionage and keepers of secrets.`,
		'Eternal Vanguard': `Standing with the Eternal Vanguard, an ancient order dedicated to fighting cosmic threats.`,
		'Nature\'s Guardians': `One with Nature's Guardians, protectors of the wild places and ancient groves.`,
		'Arcane Society': `Member of the prestigious Arcane Society, dedicated to expanding magical knowledge.`,
		'Merchant Guild': `Carrying the seal of the Merchant Guild, facilitating trade and prosperity.`,
		'Astral Seekers': `Journeying with the Astral Seekers, explorers of planes and collectors of exotic artifacts.`
	};
	
	// Higher power/level means more accomplished character
	const accomplishmentLevel = Math.floor(powerLevel / 20) + Math.floor(level / 20);
	
	let accomplishments = '';
	
	switch(accomplishmentLevel) {
		case 0:
			accomplishments = `Still early in their journey, with much to learn and prove.`;
			break;
		case 1:
			accomplishments = `Known in local circles for completing several missions of importance.`;
			break;
		case 2:
			accomplishments = `Has earned regional recognition after overcoming significant challenges.`;
			break;
		case 3:
			accomplishments = `Their name is whispered with respect across multiple kingdoms.`;
			break;
		case 4:
			accomplishments = `Legends of their deeds have spread to distant lands.`;
			break;
		case 5:
		default:
			accomplishments = `A living legend whose exploits are celebrated in song and story throughout the world.`;
	}
	
	// Generate a character-specific quirk or detail
	const quirks = [
		`They never sleep more than four hours a night.`,
		`They collect small trinkets from each adventure.`,
		`They refuse to eat before battle, believing it brings bad luck.`,
		`They can communicate with a specific type of animal.`,
		`They always wear a memento from their homeland.`,
		`They speak with an accent from a far-off land.`,
		`They have an unusual phobia that they struggle to overcome.`,
		`They can predict weather changes with uncanny accuracy.`,
		`They brew unique potions as a hobby.`,
		`They keep a journal of every significant event in their life.`
	];
	
	const quirk = quirks[Math.floor(Math.random() * quirks.length)];
	
	// Assemble the lore
	return `${originStories[origin] || `From the lands of ${origin}`} ${classNarratives[charClass] || `A skilled adventurer of the ${charClass} tradition.`} ${factionPurposes[faction] || `Allied with the faction known as ${faction}.`} Channeling the power of ${affinity}, they have become a force to be reckoned with. ${accomplishments} ${quirk}`;
}

// Generate story arc for character
function generateStoryArc(attributes) {
	const { class: charClass, powerLevel, level, affinity } = attributes;
	
	// Define story arc templates based on power level
	const storyArcs = [
		{ // Power level 10-29
			title: "BTB Finance: Awakening",
			chapters: [
				"The Call to Adventure",
				"First Steps in BTB World",
				"Unexpected Allies in the Finance Realm",
				"Local Troubles in BTB Village",
				"Proving Worth to BTB Elders"
			]
		},
		{ // Power level 30-49
			title: "BTB Finance: Rising Challenges",
			chapters: [
				"Beyond the Familiar BTB Territory",
				"Growing Reputation in BTB Finance World",
				"Dangerous Enemies of the BTB Realm",
				"Hidden Talents for BTB Finance",
				"BTB Regional Crisis"
			]
		},
		{ // Power level 50-69
			title: "BTB Finance: Realm Defender",
			chapters: [
				"Answering the BTB Call",
				"Gathering Forces for BTB Finance",
				"Ancient BTB Secrets",
				"BTB Finance Kingdom's Champion",
				"Turning the Tide for BTB"
			]
		},
		{ // Power level 70-89
			title: "BTB Finance: Legend's Path",
			chapters: [
				"BTB Cosmic Awareness",
				"Trials of BTB Ascension",
				"Facing the BTB Finance Darkness",
				"BTB Realms Beyond",
				"Rewriting BTB Finance Destiny"
			]
		},
		{ // Power level 90-100
			title: "BTB Finance: Mythic Destiny",
			chapters: [
				"Transcending BTB Limitations",
				"BTB Finance Reality's Architect",
				"BTB Cosmic Balance",
				"The Final BTB Finance Challenge",
				"BTB Legacy Eternal"
			]
		}
	];
	
	// Select appropriate story arc based on power level
	const arcIndex = Math.min(4, Math.floor(powerLevel / 20));
	const arc = storyArcs[arcIndex];
	
	// Select current chapter based on level
	const chapterIndex = Math.min(4, Math.floor(level / 20));
	const currentChapter = arc.chapters[chapterIndex];
	
	// Generate next objective
	const objectives = [
		`Seek out the lost ${affinity} shrine to enhance their BTB Finance powers.`,
		`Confront the rising darkness in the nearby BTB Finance ${affinity}-touched lands.`,
		`Gather allies from the BTB ${affinity} practitioners guild.`,
		`Recover the ancient BTB Finance artifact that amplifies ${affinity} abilities.`,
		`Master the forbidden technique of BTB Finance ${affinity} manipulation.`,
		`Challenge the rogue ${charClass} who threatens the BTB Finance balance.`
	];
	
	const nextObjective = objectives[Math.floor(Math.random() * objectives.length)];
	
	return {
		title: arc.title,
		currentChapter: currentChapter,
		progress: `${chapterIndex + 1}/${arc.chapters.length}`,
		completedChapters: arc.chapters.slice(0, chapterIndex),
		currentObjective: nextObjective,
		nextChapters: arc.chapters.slice(chapterIndex + 1),
		btbFinanceSponsor: "Official BTB Finance Character Journey"
	};
}

// Generate special traits based on class and tier
function generateSpecialTraits(characterClass, tierName) {
	const specialTraits = [];
	const tier = tierName.toLowerCase();
	const tierLevel = ['starter', 'basic', 'standard', 'common', 'uncommon', 'rare', 'superior', 'epic', 'legendary', 'transcendent', 'celestial', 'divine', 'mythic', 'eternal', 'primordial'].indexOf(tier);
	
	// Number of special traits based on tier
	const numTraits = Math.min(3, Math.max(1, Math.floor(tierLevel / 3) + 1));
	
	const classTraits = {
		warrior: [
			"Unbreakable Will", "Battle Scars", "Weapons Master", 
			"Tactical Mind", "Berserker Rage", "Commanding Presence",
			"Steel Nerves", "Combat Reflexes", "Adrenaline Rush"
		],
		mage: [
			"Arcane Insight", "Spell Weaver", "Mana Battery", 
			"Elemental Affinity", "Ancient Knowledge", "Magic Resistance",
			"Eidetic Memory", "Ritual Master", "Enchanter's Touch"
		],
		rogue: [
			"Silent Steps", "Sixth Sense", "Poisoner", 
			"Lucky Streak", "Shadow Blend", "Quick Fingers",
			"Escape Artist", "Trapfinder", "Keen Eyes"
		],
		paladin: [
			"Divine Favor", "Aura of Protection", "Oathbound", 
			"Righteous Fury", "Healing Touch", "Undead Bane",
			"Truth Speaker", "Inspiring Presence", "Blessed Weapons"
		],
		ranger: [
			"Beast Friend", "Pathfinder", "Keen Senses", 
			"Natural Camouflage", "Weather Predictor", "Herbal Knowledge",
			"Swift Hunter", "Eagle Eye", "Terrain Specialist"
		],
		necromancer: [
			"Death Sense", "Soul Collector", "Undying", 
			"Fear Aura", "Blood Magic", "Spirit Speaker",
			"Pain Tolerance", "Plague Bearer", "Midnight Rituals"
		],
		druid: [
			"Weather Control", "Beast Speech", "Plant Growth", 
			"Shapechanger", "Natural Healing", "Seasonal Power",
			"Toxin Resistance", "Tree Stride", "Elemental Ally"
		],
		bard: [
			"Perfect Pitch", "Captivating Voice", "Loremaster", 
			"Instrumental Prodigy", "Emotional Influence", "Linguist",
			"Performance Artist", "Storyteller", "Empathic Sense"
		],
		monk: [
			"Inner Peace", "Ki Focus", "Meditation Master", 
			"Perfect Balance", "Iron Body", "Pressure Points",
			"Breath Control", "Vow Keeper", "Spiritual Awareness"
		],
		guardian: [
			"Oath of Protection", "Vigilant", "Unyielding", 
			"Shield Master", "Defensive Stance", "Loyal Heart",
			"Sentinel Senses", "Protector's Intuition", "Last Stand"
		]
	};
	
	// Normalize class name to lowercase for lookup
	const classLower = characterClass.toLowerCase();
	
	// Get class traits or default to warrior
	const availableTraits = classTraits[classLower] || classTraits.warrior;
	
	// Add universal traits for higher tiers
	const universalTraits = [
		"Destiny's Chosen", "Planar Awareness", "Ancient Bloodline",
		"Prophecy Subject", "Artifact Bond", "Divine Blessing",
		"Dimensional Insight", "Cosmic Awareness", "Time Sense"
	];
	
	// For higher tiers, add universal traits to the pool
	let traitPool = [...availableTraits];
	if (tierLevel >= 8) { // Legendary and above (8+ in new 15-tier system)
		traitPool = [...traitPool, ...universalTraits];
	}
	
	// Shuffle available traits and take the first numTraits
	const shuffled = [...traitPool].sort(() => 0.5 - Math.random());
	specialTraits.push(...shuffled.slice(0, numTraits));
	
	return specialTraits;
}

// Generate compatible items list
function generateCompatibleItems(attributes) {
	const { class: charClass, powerLevel, affinity } = attributes;
	
	// Base item compatibility by class
	const classItems = {
		warrior: ["Sword", "Shield", "Plate Armor", "War Banner", "Gauntlets"],
		mage: ["Staff", "Spellbook", "Robes", "Wand", "Crystal Orb"],
		rogue: ["Dagger", "Cloak", "Lockpicks", "Poison Vials", "Grappling Hook"],
		paladin: ["Warhammer", "Holy Symbol", "Heavy Armor", "Sacred Text", "Blessed Oil"],
		ranger: ["Bow", "Animal Companion", "Camouflage Cloak", "Survival Kit", "Tracking Tools"],
		necromancer: ["Skull Staff", "Ritual Dagger", "Soul Gem", "Dark Grimoire", "Bone Fetish"],
		druid: ["Totem", "Wildshape Charm", "Living Seedbag", "Nature Focus", "Herbal Pouch"],
		bard: ["Musical Instrument", "Enchanted Voice", "Costume Set", "Performance Focus", "Songbook"],
		monk: ["Fighting Wraps", "Meditation Beads", "Training Weights", "Herbal Tea Set", "Walking Staff"],
		guardian: ["Tower Shield", "War Horn", "Defensive Runes", "Sentinel Badge", "Reinforced Armor"]
	};
	
	// Affinity-based items
	const affinityItems = {
		Fire: ["Flame Crystal", "Phoenix Feather", "Dragon Scale", "Ember Sigil"],
		Water: ["Tidestone", "Siren's Pearl", "Coral Fragment", "Abyssal Focus"],
		Earth: ["Geode Core", "Mountain Root", "Petrified Wood", "Crystal Formation"],
		Air: ["Cloud Essence", "Wind Chime", "Feather Token", "Sky Shard"],
		Light: ["Solar Prism", "Dawn Essence", "Purified Crystal", "Truth Mirror"],
		Shadow: ["Void Fragment", "Umbral Ink", "Night Shard", "Eclipse Stone"],
		Nature: ["Living Seed", "Ancient Bark", "Wild Essence", "Growth Catalyst"],
		Arcane: ["Mana Crystal", "Spell Matrix", "Runic Tablet", "Enchanter's Focus"],
		Void: ["Starfall Fragment", "Cosmic Dust", "Dimensional Key", "Entropy Shard"],
		Lightning: ["Storm Core", "Charged Crystal", "Thunder Stone", "Conductor Coil"]
	};
	
	// Legendary items based on power level
	const legendaryItems = [
		"The Worldbreaker", "Infinity Gauntlet", "Soul Harvester",
		"Cosmic Keystone", "The Final Word", "Timeless Artifact",
		"Genesis Seed", "Reality Anchor", "Divine Testament",
		"Planar Compass", "Fate's Thread", "The Unmade"
	];
	
	// Build item compatibility list
	let compatibleItems = [];
	
	// Add class items
	compatibleItems = compatibleItems.concat(classItems[charClass.toLowerCase()] || []);
	
	// Add affinity items
	if (affinityItems[affinity]) {
		compatibleItems = compatibleItems.concat(affinityItems[affinity]);
	}
	
	// Add legendary items only for high power level characters
	if (powerLevel >= 80) {
		// Choose 1-2 legendary items
		const numLegendary = 1 + Math.floor(Math.random() * 2);
		const shuffledLegendary = [...legendaryItems].sort(() => 0.5 - Math.random());
		compatibleItems = compatibleItems.concat(shuffledLegendary.slice(0, numLegendary));
	}
	
	return compatibleItems;
}

main().catch(console.error);
