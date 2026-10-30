import fs from 'node:fs/promises';
import http from 'node:http';
import path from 'node:path';
import {createRequire} from 'node:module';
const out='D:/project/flutter/flutter_base/.claude/plan/my-ui-visual/round2';
const req=createRequire('D:/project/html/my-ui/package.json'),{chromium}=req('playwright');
const server=http.createServer(async(req,res)=>{try{const name=decodeURIComponent(new URL(req.url,'http://localhost').pathname).slice(1)||'index.html';if(path.basename(name)!==name)throw Error('outside gallery');const bytes=await fs.readFile(path.join(out,name));res.setHeader('Content-Type',name.endsWith('.png')?'image/png':name.endsWith('.html')?'text/html; charset=utf-8':'application/json');res.end(bytes);}catch{res.writeHead(404);res.end();}});
await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));
let browser;
const failures=[],errors=[];
let pairs=0;
try{
 browser=await chromium.launch({headless:true,executablePath:'C:/Program Files/Google/Chrome/Application/chrome.exe',timeout:15000});
 const page=await browser.newPage();
 page.on('pageerror',e=>errors.push(String(e)));
 await page.goto('http://127.0.0.1:'+server.address().port+'/index.html',{waitUntil:'load',timeout:15000});
 for(const id of ['loading','progress','progress-sizes','button','tag','card','divider','skeleton','switch'])for(const width of ['390','1440'])for(const theme of ['light','dark']){
  await page.selectOption('#component',id);await page.selectOption('#width',width);await page.selectOption('#theme',theme);
  const states=['button','tag','card','switch'].includes(id)&&((width==='390'&&theme==='light')||(width==='1440'&&theme==='dark'))?['','focus','hover','pressed']:[''];
  for(const state of states){await page.selectOption('#state',state);const result=await page.evaluate(async()=>{const imgs=[document.getElementById('web'),document.getElementById('flutter')];await Promise.all(imgs.map(im=>im.decode()));return imgs.map(im=>({file:im.getAttribute('src'),width:im.naturalWidth,height:im.naturalHeight}));});if(result.some(im=>im.width!==Number(width)||im.height!==900))failures.push({id,width,theme,state,result});pairs++;}
 }
 await page.click('#zoom');
 if(!await page.locator('body').evaluate(e=>e.classList.contains('actual')))failures.push('zoom control');
}finally{if(browser)await browser.close();await new Promise(resolve=>server.close(resolve));}
const result={pairs,failures,pageErrors:errors};
await fs.writeFile(out+'/gallery-validation.json',JSON.stringify(result,null,2));
console.log(JSON.stringify(result));
if(failures.length||errors.length)process.exitCode=1;
