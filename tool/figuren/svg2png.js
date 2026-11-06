// node svg2png.js file.svg... -> file.png next to it (size from svg width/height)
const {chromium}=require('playwright');const fs=require('fs');
(async()=>{const b=await chromium.launch();const p=await b.newPage();
for(const f of process.argv.slice(2)){const s=fs.readFileSync(f,'utf8');
const w=+s.match(/width="([\d.]+)"/)[1],h=+s.match(/height="([\d.]+)"/)[1];
await p.setViewportSize({width:Math.round(w),height:Math.round(h)});
await p.setContent(`<html><body style="margin:0;background:transparent">${s}</body></html>`);
await p.screenshot({path:f.replace(/\.svg$/,'.png'),omitBackground:true,clip:{x:0,y:0,width:Math.round(w),height:Math.round(h)}});}
await b.close();})();
