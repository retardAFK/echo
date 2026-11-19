// Mixing bench measure (spec S-012, T-147). Opens the web build with "?mix",
// taps the Web Audio output before the speakers and prints, for each moment
// of the bench (game/bench/mix_bench.gd), the peak and RMS level in dBFS.
//
//   godot --headless --export-release "Web" build/web/index.html
//   (cd build/web && python3 -m http.server 8765) &
//   NODE_PATH=$(npm root -g) node tools/web/measure_mix.js http://localhost:8765/index.html?mix
const { chromium } = require('playwright');

const url = process.argv[2] || 'http://localhost:8765/index.html?mix';

(async () => {
  const browser = await chromium.launch({ args: ['--autoplay-policy=no-user-gesture-required'] });
  const page = await browser.newPage();
  await page.addInitScript(() => {
    // Every connection to the speakers goes through one tap per audio context.
    const taps = new Map();
    const connect = AudioNode.prototype.connect;
    AudioNode.prototype.connect = function (dest, ...rest) {
      if (!(dest instanceof AudioDestinationNode)) {
        return connect.call(this, dest, ...rest);
      }
      let tap = taps.get(dest.context);
      if (!tap) {
        const ctx = dest.context;
        tap = ctx.createGain();
        connect.call(tap, dest);
        const meter = ctx.createScriptProcessor(1024, 2, 2);
        window.echoMix = { stats: {} };
        meter.onaudioprocess = (e) => {
          const scene = window.echoMixScene || 'none';
          const s = window.echoMix.stats[scene] || (window.echoMix.stats[scene] = { peak: 0, sum: 0, n: 0, blocks: [] });
          let blockSum = 0;
          for (let c = 0; c < e.inputBuffer.numberOfChannels; c++) {
            const data = e.inputBuffer.getChannelData(c);
            for (let i = 0; i < data.length; i++) {
              s.peak = Math.max(s.peak, Math.abs(data[i]));
              blockSum += data[i] * data[i];
            }
            s.n += data.length;
          }
          s.sum += blockSum;
          s.blocks.push(Math.sqrt(blockSum / (e.inputBuffer.numberOfChannels * e.inputBuffer.length)));
        };
        connect.call(tap, meter);
        connect.call(meter, dest); // Pulled by the speakers; it outputs silence.
        taps.set(ctx, tap);
      }
      return connect.call(this, tap, ...rest);
    };
  });
  await page.goto(url);
  const start = Date.now();
  while (Date.now() - start < 300000 && (await page.evaluate(() => window.echoMixScene)) !== 'done') {
    await page.waitForTimeout(1000);
  }
  const results = await page.evaluate(() => {
    const db = (v) => (v > 0 ? +(20 * Math.log10(v)).toFixed(1) : -120);
    const out = {};
    for (const [scene, s] of Object.entries(window.echoMix ? window.echoMix.stats : {})) {
      const sorted = s.blocks.slice().sort((a, b) => a - b);
      out[scene] = {
        peak_dbfs: db(s.peak),
        rms_dbfs: db(Math.sqrt(s.sum / Math.max(s.n, 1))),
        loud_rms_dbfs: db(sorted[Math.floor(sorted.length * 0.95)] || 0),
      };
    }
    return out;
  });
  console.log(JSON.stringify(results, null, 1));
  await browser.close();
})();
