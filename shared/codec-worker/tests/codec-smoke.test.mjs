import assert from 'node:assert/strict';
import { createRequire } from 'node:module';
import { readFile } from 'node:fs/promises';
import test from 'node:test';
import { fileURLToPath } from 'node:url';

const vendor = new URL('../vendor/', import.meta.url);
globalThis.__dirname = fileURLToPath(vendor);
globalThis.require = createRequire(import.meta.url);
const width = 100;
const height = 100;
const rgba = new Uint8Array(width * height * 4);
for (let y = 0; y < height; y += 1) {
  for (let x = 0; x < width; x += 1) {
    const offset = (y * width + x) * 4;
    rgba[offset] = Math.round((x / width) * 255);
    rgba[offset + 1] = Math.round((y / height) * 255);
    rgba[offset + 2] = (x * 13 + y * 7) % 255;
    rgba[offset + 3] = 255;
  }
}

async function loadEmscripten(script, wasm) {
  const [{ default: factory }, wasmBinary] = await Promise.all([
    import(new URL(script, vendor)),
    readFile(new URL(wasm, vendor)),
  ]);
  return factory({ wasmBinary, print: () => {}, printErr: () => {} });
}

test('MozJPEG encodes generated RGBA', async () => {
  const module = await loadEmscripten('mozjpeg_node_enc.js', 'mozjpeg_node_enc.wasm');
  const result = module.encode(rgba, width, height, {
    quality: 75, baseline: false, arithmetic: false, progressive: true,
    optimize_coding: true, smoothing: 0, color_space: 3, quant_table: 3,
    trellis_multipass: false, trellis_opt_zero: false, trellis_opt_table: false,
    trellis_loops: 1, auto_subsample: true, chroma_subsample: 2,
    separate_chroma_quality: false, chroma_quality: 75,
  });
  assert.ok(result.length > 100);
  assert.deepEqual(Array.from(result.subarray(0, 3)), [0xff, 0xd8, 0xff]);
});

test('WebP encodes generated RGBA', async () => {
  const module = await loadEmscripten('webp_node_enc.js', 'webp_node_enc.wasm');
  const result = module.encode(rgba, width, height, {
    quality: 78, target_size: 0, target_PSNR: 0, method: 4, sns_strength: 50,
    filter_strength: 60, filter_sharpness: 0, filter_type: 1, partitions: 0,
    segments: 4, pass: 1, show_compressed: 0, preprocessing: 0, autofilter: 0,
    partition_limit: 0, alpha_compression: 1, alpha_filtering: 1, alpha_quality: 100,
    lossless: 0, exact: 0, image_hint: 0, emulate_jpeg_size: 0, thread_level: 0,
    low_memory: 0, near_lossless: 100, use_delta_palette: 0, use_sharp_yuv: 0,
  });
  assert.ok(result.length > 100);
  assert.equal(Buffer.from(result.subarray(0, 4)).toString('ascii'), 'RIFF');
  assert.equal(Buffer.from(result.subarray(8, 12)).toString('ascii'), 'WEBP');
});

test('AVIF encodes generated RGBA', async () => {
  const module = await loadEmscripten('avif_node_enc.js', 'avif_node_enc.wasm');
  const result = module.encode(rgba, width, height, {
    quality: 50, qualityAlpha: 50, denoiseLevel: 0, tileRowsLog2: 0,
    tileColsLog2: 0, speed: 6, subsample: 0, chromaDeltaQ: false,
    sharpness: 0, enableSharpYUV: false, enableSharpDownsampling: false, tune: 0,
  });
  assert.ok(result.length > 100);
  assert.equal(Buffer.from(result.subarray(4, 8)).toString('ascii'), 'ftyp');
});

test('OxiPNG encodes generated RGBA', async () => {
  const [{ default: init, optimise }, wasmBinary] = await Promise.all([
    import(new URL('squoosh_oxipng.js', vendor)),
    readFile(new URL('squoosh_oxipng_bg.wasm', vendor)),
  ]);
  await init(wasmBinary);
  const result = optimise(new Uint8ClampedArray(rgba.buffer), width, height, 2, false);
  assert.ok(result.length > 100);
  assert.deepEqual(Array.from(result.subarray(0, 8)), [137, 80, 78, 71, 13, 10, 26, 10]);
});
