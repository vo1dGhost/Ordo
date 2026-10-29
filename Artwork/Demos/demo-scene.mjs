// 无文字功能示意：浏览器预览与逐帧导出共用同一组矢量对象和时间轴。
export const palette = { background: '#0c0a09', window: '#1c1917', windowOpacity: .84 };
export const durations = { move: 3, resize: 3, snap: 6 };
export const clamp = x => Math.max(0, Math.min(1, x));
// 五次缓动使起止速度和加速度均为零，循环接缝处不会突然启停。
export const ease = x => { x = clamp(x); return x*x*x*(x*(x*6-15)+10); };
const ramp = (t,a,b) => ease((t-a)/(b-a));
const lerp = (a,b,p) => a.map((v,i) => v+(b[i]-v)*p);
const center = [195,105.5,570,285];
const layouts = [center,[100,58,380,190],[480,58,380,380],center];
const origins = [[450,250],[290,210],[660,230],[450,250]];
const choices = [[400,200],[365,210],[660,300]];

export function scene(kind, time) {
  const t = ((time % durations[kind])+durations[kind]) % durations[kind];
  if (kind !== 'snap') {
    const initial = kind === 'move' ? [230,150,400,240] : [205,120,380,230];
    const delta = kind === 'move' ? [110,-65,0,0] : [0,0,190,90];
    const p = ramp(t,.45,1.15)-ramp(t,1.55,2.25);
    const win = initial.map((v,i)=>v+delta[i]*p);
    const pointer = kind === 'move' ? [425+110*p,270-65*p] : [450+190*p,275+90*p];
    return { win, pointer, pressed:ramp(t,.2,.34)*(1-ramp(t,2.45,2.59)) };
  }
  const i = Math.floor(t/2), u = t-i*2;
  const pressed = ramp(u,.16,.28)*(1-ramp(u,.95,1.07));
  const selected = lerp(origins[i],choices[i],ramp(u,.35,.7));
  return {
    win:lerp(layouts[i],layouts[i+1],ramp(u,.95,1.15)),
    pointer:lerp(selected,origins[i+1],ramp(u,1.4,1.8)),
    pressed,
    preview:layouts[i+1], previewOpacity:ramp(u,.45,.7)*(1-ramp(u,.95,1.03)),
    origin:origins[i], markerOpacity:ramp(u,.28,.4)*(1-ramp(u,.95,1.03))
  };
}

const rounded = (r,attrs) => `<rect x="${r[0]}" y="${r[1]}" width="${r[2]}" height="${r[3]}" rx="14" ${attrs}/>`;
// 键帽符号使用矢量路径，无字体依赖，也不会混入标题或说明文字。
function symbol(type) {
  if(type==='shift') return '<path d="M -15 2 L 0 -13 L 15 2 H 7 V 14 H -7 V 2 Z"/>';
  if(type==='control') return '<path d="M -12 5 L 0 -8 L 12 5"/>';
  if(type==='option') return '<path d="M -15 -11 H -6 L 9 12 H 17 M 5 -11 H 17"/>';
  return '<path d="M -7 -7 H 7 V 7 H -7 Z M -7 -7 H -12 A 5 5 0 1 1 -7 -12 V -7 M 7 -7 V -12 A 5 5 0 1 1 12 -7 H 7 M 7 7 H 12 A 5 5 0 1 1 7 12 V 7 M -7 7 V 12 A 5 5 0 1 1 -12 7 H -7"/>';
}

export function svg(kind, time) {
  const s = scene(kind,time), p=s.pressed;
  const keys = {move:['shift','control'],resize:['shift','option'],snap:['control','command']}[kind];
  let content = `<rect width="960" height="540" fill="${palette.background}"/>`;
  content += rounded([s.win[0],s.win[1]+5,s.win[2],s.win[3]],'fill="#000" opacity=".28"');
  content += rounded(s.win,`fill="${palette.window}" fill-opacity="${palette.windowOpacity}" stroke="#49413c" stroke-opacity=".65" stroke-width=".8"`);
  if(s.previewOpacity) content+=rounded(s.preview,`fill="#fafaf9" fill-opacity="${.045*s.previewOpacity}" stroke="#a6a09b" stroke-opacity="${.7*s.previewOpacity}" stroke-width="1.2"`);
  if(s.markerOpacity) {
    // 固定起点的八瓣方向提示，不随鼠标移动。
    for(let i=0;i<8;i++) content+=`<path transform="translate(${s.origin}) rotate(${i*45})" d="M -2 -11 L -3 -17 Q 0 -19 3 -17 L 2 -11 Z" fill="#a6a09b" opacity="${s.markerOpacity*.75}"/>`;
  }
  content+=`<path transform="translate(${s.pointer}) scale(.78)" d="M 0 0 V 25 L 7 19 L 13 32 L 18 29 L 12 17 H 22 Z" fill="#fafaf9" stroke="#0c0a09" stroke-width="2" stroke-linejoin="round"/>`;
  keys.forEach((k,i)=>{
    const x=437+i*86, y=476+3*p, scale=1-.045*p;
    content+=`<g transform="translate(${x},${y}) scale(${scale})">`;
    content+='<rect x="-34" y="-30" width="68" height="64" rx="13" fill="#000"/>';
    content+='<rect x="-34" y="-32" width="68" height="64" rx="13" fill="#1c1917" stroke="#49413c" stroke-width="1"/>';
    content+=`<rect x="-34" y="-32" width="68" height="64" rx="13" fill="#e7e5e4" opacity="${p}"/>`;
    content+=`<g fill="none" stroke="${p>.5?'#1c1917':'#a6a09b'}" stroke-width="2.5" stroke-linejoin="round" stroke-linecap="round">${symbol(k)}</g></g>`;
  });
  return `<svg xmlns="http://www.w3.org/2000/svg" width="1920" height="1080" viewBox="0 0 960 540">${content}</svg>`;
}
