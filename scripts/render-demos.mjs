// 只重建 README 演示资源，不操作 App、Keynote、系统权限或真实窗口。
import fs from 'node:fs/promises';
import path from 'node:path';
import { createRequire } from 'node:module';
import { spawn } from 'node:child_process';
import { once } from 'node:events';
import { crc32 } from 'node:zlib';
import { fileURLToPath } from 'node:url';
import { svg, scene, durations, palette } from '../Artwork/Demos/demo-scene.mjs';

const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const out=path.resolve(process.argv[2] || path.join(root,'build/DemoRender'));
await fs.mkdir(out,{recursive:true});
// 使用已有的图像工具，不安装包、不改变项目依赖。可用 NODE_PATH 指向其他安装位置。
const require=createRequire(import.meta.url);
let sharp;
try { sharp=require('sharp'); }
catch { sharp=createRequire(path.join(process.env.HOME,'.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/'))('sharp'); }
const report={palette, fps:60, videos:{}};
for(const kind of Object.keys(durations)) {
  const count=durations[kind]*60;
  const ff=spawn('ffmpeg',['-v','error','-y','-f','rawvideo','-pix_fmt','rgba','-s','1920x1080','-r','60','-i','pipe:0','-an','-c:v','apng','-pix_fmt','rgb24','-plays','0','-f','apng',path.join(out,`${kind}.apng`)],{stdio:['pipe','inherit','inherit']});
  const done=once(ff,'close');
  for(let i=0;i<count;i++) {
    const frame=Buffer.from(svg(kind,i/60));
    const raw=await sharp(frame).ensureAlpha().raw().toBuffer();
    if(!ff.stdin.write(raw)) await once(ff.stdin,'drain');
  }
  ff.stdin.end();
  const [code]=await done;
  if(code!==0) throw new Error(`${kind}: 编码失败 ${code}`);
  // FFmpeg 的 APNG 编码器不会自动写 sRGB 标记，直接补充标准 PNG 色彩块。
  const filename=path.join(out,`${kind}.apng`), encoded=await fs.readFile(filename);
  const color=Buffer.alloc(13); color.writeUInt32BE(1,0); color.write('sRGB',4); color[8]=0;
  color.writeUInt32BE(crc32(color.subarray(4,9)),9);
  await fs.writeFile(filename,Buffer.concat([encoded.subarray(0,33),color,encoded.subarray(33)]));
  for(const t of [0,.6,1,1.8,2.5]) await sharp(Buffer.from(svg(kind,t))).png().toFile(path.join(out,`${kind}-${t}.png`));
  report.videos[kind]={frames:count,duration:durations[kind],loopStateMatches:JSON.stringify(scene(kind,0))===JSON.stringify(scene(kind,durations[kind]))};
  console.log(`${kind}: ${count} 帧，${durations[kind]} 秒`);
}
await fs.writeFile(path.join(out,'render-report.json'),JSON.stringify(report,null,2));
