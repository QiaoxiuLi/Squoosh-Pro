const inputs = new Map();
const outputs = new Map();
const modules = new Map();
const MAX_PIXELS = 200_000_000;
const MAX_CHUNK_BYTES = 262_144;

function fromBase64(value) {
  const binary = atob(value);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i += 1) bytes[i] = binary.charCodeAt(i);
  return bytes;
}

function toBase64(bytes) {
  let value = '';
  for (let offset = 0; offset < bytes.length; offset += 0x8000) {
    value += String.fromCharCode(...bytes.subarray(offset, Math.min(offset + 0x8000, bytes.length)));
  }
  return btoa(value);
}

async function emscriptenModule(name, script, wasm) {
  if (!modules.has(name)) {
    modules.set(name, import(script).then(({ default: factory }) => factory({
      locateFile: () => new URL(wasm, import.meta.url).href,
      print: () => {},
      printErr: () => {},
    })));
  }
  return modules.get(name);
}

async function oxipngModule() {
  if (!modules.has('oxipng')) {
    modules.set('oxipng', import('./codecs/squoosh_oxipng.js').then(async module => {
      await module.default(new URL('./codecs/squoosh_oxipng_bg.wasm', import.meta.url));
      return module;
    }));
  }
  return modules.get('oxipng');
}

function mozjpegOptions(input) {
  return {
    quality: input.quality ?? 75,
    baseline: input.baseline ?? false,
    arithmetic: false,
    progressive: input.progressive ?? true,
    optimize_coding: input.optimizeCoding ?? true,
    smoothing: input.smoothing ?? 0,
    color_space: input.colorSpace ?? 3,
    quant_table: input.quantTable ?? 3,
    trellis_multipass: input.trellisMultipass ?? false,
    trellis_opt_zero: input.trellisOptZero ?? false,
    trellis_opt_table: input.trellisOptTable ?? false,
    trellis_loops: input.trellisLoops ?? 1,
    auto_subsample: input.autoSubsample ?? true,
    chroma_subsample: input.chromaSubsample ?? 2,
    separate_chroma_quality: input.separateChromaQuality ?? false,
    chroma_quality: input.chromaQuality ?? input.quality ?? 75,
  };
}

function webpOptions(input) {
  return {
    quality: input.quality ?? 78, target_size: 0, target_PSNR: 0,
    method: input.method ?? 4, sns_strength: input.snsStrength ?? 50,
    filter_strength: input.filterStrength ?? 60, filter_sharpness: input.filterSharpness ?? 0,
    filter_type: 1, partitions: 0, segments: 4, pass: input.pass ?? 1,
    show_compressed: 0, preprocessing: 0, autofilter: 0, partition_limit: 0,
    alpha_compression: 1, alpha_filtering: 1, alpha_quality: input.alphaQuality ?? 100,
    lossless: input.lossless ? 1 : 0, exact: 0, image_hint: 0, emulate_jpeg_size: 0,
    thread_level: 0, low_memory: 0, near_lossless: input.nearLossless ?? 100,
    use_delta_palette: 0, use_sharp_yuv: input.sharpYUV ? 1 : 0,
  };
}

function avifOptions(input) {
  return {
    quality: input.quality ?? 50, qualityAlpha: input.alphaQuality ?? input.quality ?? 50,
    denoiseLevel: input.denoise ?? 0, tileRowsLog2: input.tileRowsLog2 ?? 0,
    tileColsLog2: input.tileColsLog2 ?? 0, speed: input.speed ?? 6,
    subsample: input.subsample ?? 0, chromaDeltaQ: input.chromaDeltaQ ?? false,
    sharpness: input.sharpness ?? 0, enableSharpYUV: input.sharpYUV ?? false,
    enableSharpDownsampling: input.sharpDownsampling ?? false,
    tune: input.tune ?? 0,
  };
}

window.SquooshPro = {
  capabilities() {
    return { schemaVersion: 1, codecs: ['mozjpeg', 'oxipng', 'webp', 'avif'], maxPixels: MAX_PIXELS, maxChunkBytes: MAX_CHUNK_BYTES };
  },

  async networkIsolationProbe() {
    try {
      await fetch('https://example.invalid/squoosh-pro-network-probe', { cache: 'no-store' });
      return false;
    } catch {
      return true;
    }
  },

  begin(requestID, width, height, codec, options, totalBytes) {
    if (!requestID || width < 1 || height < 1 || width * height > MAX_PIXELS || totalBytes !== width * height * 4) throw new Error('invalidRequest');
    inputs.set(requestID, { width, height, codec, options: options || {}, totalBytes, chunks: [], received: 0, cancelled: false });
    return true;
  },

  append(requestID, base64Chunk) {
    const entry = inputs.get(requestID);
    if (!entry || entry.cancelled) throw new Error('cancelled');
    const chunk = fromBase64(base64Chunk);
    if (chunk.length > MAX_CHUNK_BYTES || entry.received + chunk.length > entry.totalBytes) throw new Error('invalidRequest');
    entry.chunks.push(chunk);
    entry.received += chunk.length;
    return entry.received;
  },

  async encode(requestID) {
    const entry = inputs.get(requestID);
    if (!entry || entry.cancelled || entry.received !== entry.totalBytes) throw new Error('invalidRequest');
    const rgba = new Uint8Array(entry.totalBytes);
    let offset = 0;
    for (const chunk of entry.chunks) { rgba.set(chunk, offset); offset += chunk.length; }
    entry.chunks = [];
    let result;
    if (entry.codec === 'mozjpeg') {
      const module = await emscriptenModule('mozjpeg', './codecs/mozjpeg_enc.js', './codecs/mozjpeg_enc.wasm');
      result = module.encode(rgba, entry.width, entry.height, mozjpegOptions(entry.options));
    } else if (entry.codec === 'webp') {
      const module = await emscriptenModule('webp', './codecs/webp_enc.js', './codecs/webp_enc.wasm');
      result = module.encode(rgba, entry.width, entry.height, webpOptions(entry.options));
    } else if (entry.codec === 'avif') {
      const module = await emscriptenModule('avif', './codecs/avif_enc.js', './codecs/avif_enc.wasm');
      result = module.encode(rgba, entry.width, entry.height, avifOptions(entry.options));
    } else if (entry.codec === 'oxipng') {
      const module = await oxipngModule();
      result = module.optimise(new Uint8ClampedArray(rgba.buffer), entry.width, entry.height, entry.options.level ?? 2, entry.options.interlace ?? false);
    } else {
      throw new Error('unsupportedFormat');
    }
    if (!result || entry.cancelled) throw new Error(entry.cancelled ? 'cancelled' : 'encodeFailed');
    const bytes = new Uint8Array(result);
    outputs.set(requestID, bytes);
    inputs.delete(requestID);
    return { schemaVersion: 1, requestID, ok: true, byteLength: bytes.length, chunks: Math.ceil(bytes.length / MAX_CHUNK_BYTES) };
  },

  outputChunk(requestID, index) {
    const bytes = outputs.get(requestID);
    if (!bytes) throw new Error('invalidRequest');
    const start = index * MAX_CHUNK_BYTES;
    return toBase64(bytes.subarray(start, Math.min(start + MAX_CHUNK_BYTES, bytes.length)));
  },

  finish(requestID) {
    inputs.delete(requestID);
    outputs.delete(requestID);
    return true;
  },

  cancel(requestID) {
    const entry = inputs.get(requestID);
    if (entry) entry.cancelled = true;
    outputs.delete(requestID);
    return true;
  },
};
