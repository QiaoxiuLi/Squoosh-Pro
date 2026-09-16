import { createRequire } from 'node:module';
import { readFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';

const vendor = new URL('../vendor/', import.meta.url);
globalThis.__dirname = fileURLToPath(vendor);
globalThis.require = createRequire(import.meta.url);

async function loadEmscripten(script, wasm) {
  const [{ default: factory }, wasmBinary] = await Promise.all([import(new URL(script, vendor)), readFile(new URL(wasm, vendor))]);
  return factory({ wasmBinary, print: () => {}, printErr: () => {} });
}

const modules = {
  mozjpeg: await loadEmscripten('mozjpeg_node_enc.js', 'mozjpeg_node_enc.wasm'),
  webp: await loadEmscripten('webp_node_enc.js', 'webp_node_enc.wasm'),
  avif: await loadEmscripten('avif_node_enc.js', 'avif_node_enc.wasm'),
};
const oxipng = await import(new URL('squoosh_oxipng.js', vendor));
await oxipng.default(await readFile(new URL('squoosh_oxipng_bg.wasm', vendor)));

function pixels(width, height) {
  const rgba = new Uint8Array(width * height * 4);
  for (let offset = 0; offset < rgba.length; offset += 4) {
    const pixel = offset >>> 2;
    rgba[offset] = pixel % 251;
    rgba[offset + 1] = Math.floor(pixel / width) % 241;
    rgba[offset + 2] = (pixel * 7) % 239;
    rgba[offset + 3] = 255;
  }
  return rgba;
}

function encode(codec, rgba, width, height) {
  if (codec === 'mozjpeg') return modules.mozjpeg.encode(rgba, width, height, {
    quality: 55, baseline: false, arithmetic: false, progressive: true, optimize_coding: true,
    smoothing: 0, color_space: 3, quant_table: 3, trellis_multipass: false,
    trellis_opt_zero: false, trellis_opt_table: false, trellis_loops: 1,
    auto_subsample: true, chroma_subsample: 2, separate_chroma_quality: false, chroma_quality: 55,
  });
  if (codec === 'webp') return modules.webp.encode(rgba, width, height, {
    quality: 55, target_size: 0, target_PSNR: 0, method: 0, sns_strength: 50,
    filter_strength: 20, filter_sharpness: 0, filter_type: 1, partitions: 0, segments: 4,
    pass: 1, show_compressed: 0, preprocessing: 0, autofilter: 0, partition_limit: 0,
    alpha_compression: 1, alpha_filtering: 1, alpha_quality: 100, lossless: 0, exact: 0,
    image_hint: 0, emulate_jpeg_size: 0, thread_level: 0, low_memory: 1,
    near_lossless: 100, use_delta_palette: 0, use_sharp_yuv: 0,
  });
  if (codec === 'avif') return modules.avif.encode(rgba, width, height, {
    quality: 35, qualityAlpha: 35, denoiseLevel: 0, tileRowsLog2: 2, tileColsLog2: 2,
    speed: 10, subsample: 1, chromaDeltaQ: false, sharpness: 0, enableSharpYUV: false,
    enableSharpDownsampling: false, tune: 0,
  });
  return oxipng.optimise(new Uint8ClampedArray(rgba.buffer), width, height, 0, false);
}

const selectedCodecs = (process.env.SQUOOSH_SCALE_CODECS || 'mozjpeg,webp,avif,oxipng').split(',');
const selectedSizes = process.env.SQUOOSH_SCALE_SIZE === 'cycle' ? [] : (process.env.SQUOOSH_SCALE_SIZE === '48mp' ? [[8000, 6000]] : (process.env.SQUOOSH_SCALE_SIZE === '12mp' ? [[4000, 3000]] : [[4000, 3000], [8000, 6000]]));
for (const [width, height] of selectedSizes) {
  const rgba = pixels(width, height);
  for (const codec of selectedCodecs) {
    const started = performance.now();
    const result = encode(codec, rgba, width, height);
    if (!result || result.length < 16) throw new Error(`${codec} failed at ${width}x${height}`);
    console.log(JSON.stringify({ codec, width, height, bytes: result.length, elapsedMs: Math.round(performance.now() - started), rssMB: Math.round(process.memoryUsage().rss / 1048576) }));
  }
}

if (process.env.SQUOOSH_SKIP_CYCLE !== '1') {
  const small = pixels(400, 300);
  const before = process.memoryUsage().rss;
  for (let index = 0; index < 100; index += 1) encode(['mozjpeg', 'webp', 'avif', 'oxipng'][index % 4], small, 400, 300);
  const afterFirst = process.memoryUsage().rss;
  for (let index = 0; index < 100; index += 1) encode(['mozjpeg', 'webp', 'avif', 'oxipng'][index % 4], small, 400, 300);
  const afterSecond = process.memoryUsage().rss;
  console.log(JSON.stringify({ operation: 'two-100-file-cycles', beforeMB: Math.round(before / 1048576), afterFirstMB: Math.round(afterFirst / 1048576), afterSecondMB: Math.round(afterSecond / 1048576), secondCycleGrowthMB: Math.round((afterSecond - afterFirst) / 1048576) }));
}
