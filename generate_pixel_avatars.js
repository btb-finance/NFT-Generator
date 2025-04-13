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
const editionSize = 10000;

const outputDir = path.join(__dirname, 'pixel_output');
const imagesDir = path.join(outputDir, 'images');
const metadataDir = path.join(outputDir, 'metadata');

// Set to track generated avatar hashes for uniqueness
const generatedHashes = new Set();

// Define the 10-tier rarity system with specific quantities
const rarityTiers = [
	{ name: 'Mythic', quantity: 100 },     // Top 100 - Most valuable
	{ name: 'Divine', quantity: 400 },     // Next 400
	{ name: 'Celestial', quantity: 500 },  // Next 500
	{ name: 'Legendary', quantity: 1000 }, // Next 1000
	{ name: 'Epic', quantity: 1500 },     // Next 1500
	{ name: 'Rare', quantity: 1500 },     // Next 1500
	{ name: 'Uncommon', quantity: 2000 },  // Next 2000
	{ name: 'Common', quantity: 2000 },   // Next 2000
	{ name: 'Basic', quantity: 1000 }    // Last 1000
];

// Character power level ranges by tier
const powerRanges = {
	'Mythic': { min: 90, max: 100 },
	'Divine': { min: 80, max: 89 },
	'Celestial': { min: 70, max: 79 },
	'Legendary': { min: 60, max: 69 },
	'Epic': { min: 50, max: 59 },
	'Rare': { min: 40, max: 49 },
	'Uncommon': { min: 30, max: 39 },
	'Common': { min: 20, max: 29 },
	'Basic': { min: 10, max: 19 }
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

function calculateRarityScore(traits) {
	let score = 0;
	
	// Special combinations worth a lot of points
	if (traits.headwear === 'crown' && traits.pet === 'alien') score += 50;
	if (traits.eyeColor === '#FFFF99' && traits.faceAccessory === 'mask') score += 40;
	if (traits.clothing === 'armor' && traits.item === 'sword') score += 35;
	
	// Medium-value combinations
	if (traits.backgroundPattern === 'stars' && traits.pet === 'robot') score += 25;
	if (traits.headwear === 'helmet' && traits.item === 'shield') score += 20;
	if (traits.clothing === 'hoodie' && traits.pet === 'bird') score += 15;
	
	// Individual trait values
	// Headwear
	if (traits.headwear === 'crown') score += 15;
	else if (traits.headwear === 'helmet') score += 10;
	else if (traits.headwear === 'bandana') score += 8;
	else if (traits.headwear === 'cap') score += 5;
	
	// Pets
	if (traits.pet === 'alien') score += 18;
	else if (traits.pet === 'robot') score += 12;
	else if (traits.pet === 'bird') score += 8;
	
	// Items
	if (traits.item === 'sword') score += 12;
	else if (traits.item === 'shield') score += 10;
	else if (traits.item === 'book') score += 8;
	else if (traits.item === 'gadget') score += 7;
	else if (traits.item === 'drink') score += 5;
	
	// Background pattern
	if (traits.backgroundPattern === 'stars') score += 7;
	else if (traits.backgroundPattern === 'grid') score += 5;
	else if (traits.backgroundPattern === 'dots') score += 4;
	else if (traits.backgroundPattern === 'stripes') score += 3;
	
	// Face accessories
	if (traits.faceAccessory === 'mask') score += 10;
	else if (traits.faceAccessory === 'piercings') score += 8;
	else if (traits.faceAccessory === 'scars') score += 6;
	else if (traits.faceAccessory === 'war paint') score += 5;
	
	// Neck accessories
	if (traits.neckAccessory === 'chain') score += 7;
	else if (traits.neckAccessory === 'scarf') score += 5;
	else if (traits.neckAccessory === 'tie') score += 3;
	
	// Color combinations
	if (traits.bodyColor === '#330066' && traits.eyeColor === '#FFFF99') score += 12;
	if (traits.clothingColor === '#663300' && traits.mouthColor === '#FFCCFF') score += 10;
	
	// Add some randomness (but not too much)
	score += Math.random() * 5;
	
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

	// Background pattern type
	const bgPatterns = ['none', 'stars', 'stripes', 'dots', 'grid'];
	const bgPattern = bgPatterns[Math.floor(Math.random()*bgPatterns.length)];
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

	// --- Decide conditional traits early ---
	const headwears = ['none', 'cap', 'crown', 'helmet', 'bandana'];
	const headwear = headwears[Math.floor(Math.random()*headwears.length)];
	traits.headwear = headwear;

	const faceAccessories = ['none', 'mask', 'piercings', 'scars', 'war paint'];
	const faceAccessory = faceAccessories[Math.floor(Math.random()*faceAccessories.length)];
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


	// Neck accessories (centered below head)
	const neckAccessories = ['none', 'chain', 'tie', 'scarf'];
	const neckAccessory = neckAccessories[Math.floor(Math.random()*neckAccessories.length)];
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


	// Clothing (centered on body)
	const clothes = ['hoodie', 'jacket', 'armor', 'dress', 't-shirt'];
	const clothing = clothes[Math.floor(Math.random()*clothes.length)];
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


	// Handheld items (near hands)
	const items = ['none', 'sword', 'shield', 'drink', 'book', 'gadget'];
	const item = items[Math.floor(Math.random()*items.length)];
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


	// Pets (near feet)
	const pets = ['none', 'bird', 'robot', 'alien'];
	const pet = pets[Math.floor(Math.random()*pets.length)];
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
	const tierLevel = ['basic', 'common', 'uncommon', 'rare', 'epic', 'legendary', 'celestial', 'divine', 'mythic'].indexOf(tier);
	
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
			mythic: "Titan's Fury",
			divine: "Blade Storm",
			celestial: "Heroic Strike",
			legendary: "Crushing Blow",
			epic: "Mighty Swing",
			rare: "Power Attack",
			uncommon: "Cleave",
			common: "Heavy Strike",
			basic: "Basic Slash"
		},
		mage: {
			mythic: "Arcane Singularity",
			divine: "Meteor Shower",
			celestial: "Astral Beam",
			legendary: "Elemental Mastery",
			epic: "Fireball",
			rare: "Frost Nova",
			uncommon: "Arcane Missiles",
			common: "Magic Bolt",
			basic: "Spark"
		},
		rogue: {
			mythic: "Shadow Dance",
			divine: "Phantom Strike",
			celestial: "Thousand Cuts",
			legendary: "Deathmark",
			epic: "Backstab",
			rare: "Venomous Strike",
			uncommon: "Stealth Attack",
			common: "Quick Slice",
			basic: "Sneak"
		},
		paladin: {
			mythic: "Divine Intervention",
			divine: "Holy Wrath",
			celestial: "Sacred Shield",
			legendary: "Righteous Fury",
			epic: "Holy Light",
			rare: "Divine Protection",
			uncommon: "Blessed Strike",
			common: "Healing Touch",
			basic: "Minor Heal"
		},
		ranger: {
			mythic: "Arrow Storm",
			divine: "Piercing Shot",
			celestial: "Multishot",
			legendary: "Hawk's Eye",
			epic: "Aimed Shot",
			rare: "Trueshot",
			uncommon: "Quick Shot",
			common: "Steady Shot",
			basic: "Simple Shot"
		},
		necromancer: {
			mythic: "Army of the Dead",
			divine: "Soul Harvest",
			celestial: "Death Wave",
			legendary: "Bone Armor",
			epic: "Raise Dead",
			rare: "Life Drain",
			uncommon: "Curse",
			common: "Shadow Bolt",
			basic: "Bone Spike"
		},
		druid: {
			mythic: "Force of Nature",
			divine: "Celestial Alignment",
			celestial: "Starfall",
			legendary: "Wild Growth",
			epic: "Shapeshift",
			rare: "Entangling Roots",
			uncommon: "Healing Seed",
			common: "Thorns",
			basic: "Nature's Touch"
		},
		bard: {
			mythic: "Symphony of Destruction",
			divine: "Captivating Performance",
			celestial: "Harmonious Melody",
			legendary: "Inspiring Anthem",
			epic: "Battle Hymn",
			rare: "Healing Song",
			uncommon: "Soothing Tune",
			common: "Minor Chord",
			basic: "Simple Note"
		},
		monk: {
			mythic: "Transcendence",
			divine: "Spirit Burst",
			celestial: "Flying Dragon",
			legendary: "Inner Peace",
			epic: "Flying Kick",
			rare: "Chi Wave",
			uncommon: "Focused Strike",
			common: "Palm Strike",
			basic: "Jab"
		},
		guardian: {
			mythic: "Eternal Vigilance",
			divine: "Guardian's Shield",
			celestial: "Protective Aura",
			legendary: "Stalwart Defense",
			epic: "Defensive Stance",
			rare: "Shield Wall",
			uncommon: "Taunt",
			common: "Block",
			basic: "Defend"
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
	
	// Array to hold all NFTs for rarity calculation
	const nftCollection = [];
	
	console.log("Generating NFTs...");
	
	// First pass: Generate all NFTs and calculate rarity scores
	for (let i = 1; i <= editionSize; i++) {
		const canvas = createCanvas(width, height);
		const ctx = canvas.getContext('2d');

		let traits;
		let traitsHash;
		let uniqueFound = false;
		let attempts = 0;
		const maxAttempts = 10;
		
		while (!uniqueFound && attempts < maxAttempts) {
			traits = drawAvatar(ctx); // First pass without tier
			
			// Create a hash of the traits to check for uniqueness
			traitsHash = crypto.createHash('sha256')
				.update(JSON.stringify(traits))
				.digest('hex');
			
			if (!generatedHashes.has(traitsHash)) {
				uniqueFound = true;
				generatedHashes.add(traitsHash);
			} else {
				// Clear canvas for next attempt
				ctx.clearRect(0, 0, width, height);
				attempts++;
				duplicatesAvoided++;
			}
		}
		
		if (!uniqueFound) {
			console.warn(`Warning: Could not find unique avatar after ${maxAttempts} attempts for #${i}. Using last generated.`);
		}

		// Calculate rarity score
		const rarityScore = calculateRarityScore(traits);

		const tempMetadata = {
			name: `Pixel Avatar #${i}`,
			description: "A unique procedurally generated pixel art avatar from BTB Finance",
			image: `${i}.png`,
			edition: i,
			rarityScore: rarityScore,
			attributes: Object.entries(traits).map(([trait_type, value]) => ({
				trait_type,
				value
			}))
		};
		
		// Add to collection for rarity ranking
		nftCollection.push({
			id: i,
			canvas: canvas,
			ctx: ctx,
			metadata: tempMetadata,
			rarityScore: rarityScore
		});

		if (i % 100 === 0 || i === editionSize) {
			console.log(`Generated avatar ${i}/${editionSize} - Duplicates avoided: ${duplicatesAvoided}`);
		} else if (i % 10 === 0) {
			process.stdout.write('.');
		}
	}
	
	console.log("\nAssigning rarity tiers...");
	
	// Sort collection by rarity score (highest first)
	nftCollection.sort((a, b) => b.rarityScore - a.rarityScore);
	
	// Assign tiers based on rank
	let currentIndex = 0;
	const rarityStats = {};
	
	// Initialize stats object
	rarityTiers.forEach(tier => {
		rarityStats[tier.name] = { count: 0, totalValue: 0 };
	});
	
	// Apply tiers to each NFT
	for (let i = 0; i < rarityTiers.length; i++) {
		const tier = rarityTiers[i];
		const endIndex = Math.min(currentIndex + tier.quantity, nftCollection.length);
		
		console.log(`Assigning ${tier.name} tier to NFTs ranked ${currentIndex+1} to ${endIndex}...`);
		
		for (let j = currentIndex; j < endIndex; j++) {
			const nft = nftCollection[j];
			const tierName = tier.name;
			
			// IMPORTANT: Redraw the avatar with the tier information to include visual elements
			const canvas = createCanvas(width, height);
			const ctx = canvas.getContext('2d');
			const updatedTraits = drawAvatar(ctx, tierName);
			
			// Save the updated image
		const buffer = canvas.toBuffer('image/png');
			const imageName = `${nft.id}.png`;
		fs.writeFileSync(path.join(imagesDir, imageName), buffer);

			// Add rarity information to metadata
			nft.metadata.rarity = tierName;
			nft.metadata.rarityRank = j + 1;

			// Generate additional character attributes
			const characterAttributes = generateCharacterAttributes(nft.metadata.attributes.reduce((acc, attr) => {
				acc[attr.trait_type] = attr.value;
				return acc;
			}, {}), tierName);
			
			// Merge the updated traits from the redrawn avatar
			Object.assign(nft.metadata.attributes, updatedTraits);
			
			// Add character attributes to metadata
			nft.metadata.class = characterAttributes.class;
			nft.metadata.origin = characterAttributes.origin;
			nft.metadata.powerLevel = characterAttributes.powerLevel;
			nft.metadata.level = characterAttributes.level;
			nft.metadata.experiencePoints = characterAttributes.experiencePoints;
			nft.metadata.characterId = characterAttributes.characterId;
			nft.metadata.evolutionTier = characterAttributes.evolutionTier;
			nft.metadata.potentialEvolutions = characterAttributes.potentialEvolutions;
			nft.metadata.maxLevel = characterAttributes.maxLevel;
			nft.metadata.badges = characterAttributes.badges;
			nft.metadata.affinity = updatedTraits.affinity || characterAttributes.affinity;
			nft.metadata.faction = characterAttributes.faction;
			nft.metadata.stats = characterAttributes.stats;
			nft.metadata.specialAbility = characterAttributes.specialAbility;
			nft.metadata.secondaryAbilities = characterAttributes.secondaryAbilities;
			nft.metadata.generation = characterAttributes.generation;
			nft.metadata.mintDate = characterAttributes.mintDate;
			nft.metadata.lastUpgraded = characterAttributes.lastUpgraded;
			
			// Add premium metadata features
			nft.metadata.uniqueHash = crypto.createHash('sha256').update(`${nft.id}-${Date.now()}`).digest('hex');
			nft.metadata.collection = "BTB Finance Pixel Avatars";
			nft.metadata.universe = "BTB Finance Pixel Realm";
			nft.metadata.publisher = "BTB Finance";
			nft.metadata.sponsor = "BTB Finance";
			nft.metadata.lore = generateCharacterLore(characterAttributes);
			nft.metadata.tradeable = true;
			nft.metadata.storyArc = generateStoryArc(characterAttributes);
			nft.metadata.specialTraits = generateSpecialTraits(characterAttributes.class, tierName);
			nft.metadata.itemCompatibility = generateCompatibleItems(characterAttributes);
			nft.metadata.btbTokenId = `BTB-${tierName.toUpperCase()}-${nft.id.toString().padStart(5, '0')}`;
			nft.metadata.btbFinanceCompatible = true;
			
			// Add new properties to attributes
			nft.metadata.attributes.push({
				trait_type: "Rarity Tier",
				value: tierName
			});
			
			nft.metadata.attributes.push({
				trait_type: "Class",
				value: characterAttributes.class
			});
			
			nft.metadata.attributes.push({
				trait_type: "Origin",
				value: characterAttributes.origin
			});
			
			nft.metadata.attributes.push({
				trait_type: "Power Level",
				value: characterAttributes.powerLevel.toString()
			});
			
			nft.metadata.attributes.push({
				trait_type: "Level",
				value: characterAttributes.level.toString()
			});
			
			nft.metadata.attributes.push({
				trait_type: "Affinity",
				value: updatedTraits.affinity || characterAttributes.affinity
			});
			
			nft.metadata.attributes.push({
				trait_type: "Faction",
				value: characterAttributes.faction
			});
			
			nft.metadata.attributes.push({
				trait_type: "Evolution Tier",
				value: characterAttributes.evolutionTier.toString()
			});
			
			nft.metadata.attributes.push({
				trait_type: "Special Ability",
				value: characterAttributes.specialAbility
			});
			
			// Add badges as separate attributes
			characterAttributes.badges.forEach(badge => {
				nft.metadata.attributes.push({
					trait_type: "Badge",
					value: badge
				});
			});
			
			// Save final metadata
			fs.writeFileSync(
				path.join(metadataDir, `${nft.id}.json`),
				JSON.stringify(nft.metadata, null, 2)
			);
			
			// Update stats
			rarityStats[tierName].count++;
			rarityStats[tierName].totalValue += 1; // Assuming a default price of 1 ETH
		}
		
		currentIndex = endIndex;
	}
	
	// Output rarity distribution
	console.log("\nRarity distribution:");
	
	rarityTiers.forEach(tier => {
		const stats = rarityStats[tier.name];
		console.log(`${tier.name}: ${stats.count} NFTs`);
	});
	
	console.log(`\nGeneration complete!`);
	console.log(`Most valuable NFT: Pixel Avatar #${nftCollection[0].id} (Rank #1) - ${rarityTiers[0].name}`);
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
	const tierLevel = ['basic', 'common', 'uncommon', 'rare', 'epic', 'legendary', 'celestial', 'divine', 'mythic'].indexOf(tier);
	
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
	if (tierLevel >= 6) { // Legendary and above
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
