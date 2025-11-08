const fs = require('fs');
const path = require('path');
const zlib = require('zlib');

function crc32(buf) {
	let table = crc32.table;
	if (!table) {
		table = new Uint32Array(256);
		for (let i = 0; i < 256; i++) {
			let c = i;
			for (let k = 0; k < 8; k++) {
				c = ((c & 1) ? (0xEDB88320 ^ (c >>> 1)) : (c >>> 1));
			}
			table[i] = c >>> 0;
		}
		crc32.table = table;
	}
	let crc = 0xffffffff;
	for (let i = 0; i < buf.length; i++) {
		crc = (crc >>> 8) ^ table[(crc ^ buf[i]) & 0xff];
	}
	return (crc ^ 0xffffffff) >>> 0;
}

// Create a 256x256 PNG solid color (blue) with RGBA
const w = 256, h = 256;
const pixel = [0, 120, 200, 255]; // RGBA
const row = Buffer.alloc(1 + w * 4); // filter byte + pixels
row[0] = 0; // no filter
for (let x = 0; x < w; x++) {
	const offset = 1 + x * 4;
	row[offset + 0] = pixel[0];
	row[offset + 1] = pixel[1];
	row[offset + 2] = pixel[2];
	row[offset + 3] = pixel[3];
}

const raw = Buffer.alloc(row.length * h);
for (let y = 0; y < h; y++) {
	row.copy(raw, y * row.length);
}

const idat = zlib.deflateSync(raw);

function pngChunk(type, data) {
	const len = Buffer.alloc(4);
	len.writeUInt32BE(data.length, 0);
	const chunk = Buffer.concat([Buffer.from(type, 'ascii'), data]);
	const crc = Buffer.alloc(4);
	crc.writeUInt32BE(crc32(chunk), 0);
	return Buffer.concat([len, chunk, crc]);
}

const sig = Buffer.from([0x89,0x50,0x4E,0x47,0x0D,0x0A,0x1A,0x0A]);
const ihdr = Buffer.alloc(13);
ihdr.writeUInt32BE(w, 0);
ihdr.writeUInt32BE(h, 4);
ihdr.writeUInt8(8, 8); // bit depth
ihdr.writeUInt8(6, 9); // color type RGBA
ihdr.writeUInt8(0, 10); // compression
ihdr.writeUInt8(0, 11); // filter
ihdr.writeUInt8(0, 12); // interlace

const chunks = [pngChunk('IHDR', ihdr), pngChunk('IDAT', idat), pngChunk('IEND', Buffer.alloc(0))];
const png = Buffer.concat([sig, ...chunks.map(c=>c)]);

// Build ICO with single PNG image
const iconDir = Buffer.alloc(6);
iconDir.writeUInt16LE(0, 0);
iconDir.writeUInt16LE(1, 2);
iconDir.writeUInt16LE(1, 4);

const entry = Buffer.alloc(16);
entry.writeUInt8(w >= 256 ? 0 : w, 0); // width (0 means 256)
entry.writeUInt8(h >= 256 ? 0 : h, 1); // height
entry.writeUInt8(0, 2); // color count
entry.writeUInt8(0, 3); // reserved
entry.writeUInt16LE(1, 4); // planes
entry.writeUInt16LE(32, 6); // bitcount
entry.writeUInt32LE(png.length, 8); // bytes in resource
entry.writeUInt32LE(6 + 16, 12); // offset

const out = Buffer.concat([iconDir, entry, png]);

const outPath = path.join(__dirname, '..', 'build');
if (!fs.existsSync(outPath)) fs.mkdirSync(outPath, { recursive: true });
fs.writeFileSync(path.join(outPath, 'icon.ico'), out);
console.log('Wrote build/icon.ico (' + out.length + ' bytes)');
