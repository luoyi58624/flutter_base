import fs from 'node:fs/promises';
import {createRequire} from 'node:module';
const root='D:/project/flutter/flutter_base',out=root+'/.claude/plan/my-ui-visual',run=out+'/run';
const require=createRequire('D:/project/html/my-ui/package.json'),{chromium}=require('playwright');
const browser=await chromium.launch({headless:true,executablePath:'C:/Program Files/Google/Chrome/Application/chrome.exe'});
const old=JSON.parse(await fs.readFile(out+'/web-metrics.json','utf8'));const metrics=old.metrics,failures=[];
const ids=['button','tag','switch','card','divider','loading','progress','skeleton'];
for(const width of [390,1440])for(const theme of ['light','dark']){
 const context=await browser.newContext({viewport:{width,height:900},deviceScaleFactor:1,reducedMotion:'reduce',colorScheme:theme});
 await context.addInitScript(mode=>{localStorage.setItem('my-ui:theme',JSON.stringify({mode}));localStorage.removeItem('my-ui:theme-render');},theme);
 const page=await context.newPage();page.setDefaultTimeout(10000);
 const errors=[];page.on('pageerror',e=>errors.push(String(e)));
 for(const id of ids){
  const key=id+'-'+width+'-'+theme;
  try{
   await page.goto('http://127.0.0.1:5189/@fs/'+run+'/fixture.html?component='+id+'&theme='+theme,{waitUntil:'domcontentloaded'});
   await page.waitForFunction(()=>window.visualReady);
   await page.evaluate(()=>document.fonts.ready);
   await page.screenshot({path:out+'/web-'+key+'.png',animations:'disabled'});
   metrics[key]=await page.evaluate(()=>{
    const rect=e=>{const r=e.getBoundingClientRect();return {x:r.x,y:r.y,width:r.width,height:r.height}};
    const nodes=[...document.querySelectorAll('[data-my-component],.my-tag-content,.my-surface-head,.my-loading-text,.my-progress-text,.my-avatar[data-my-skeleton],.my-title[data-my-skeleton],.my-line[data-my-skeleton],.my-skeleton-visual,.my-divider-label')].map(e=>{
     const s=getComputedStyle(e),a=getComputedStyle(e,'::after');
     return {component:e.getAttribute('data-my-component'),class:e.className.baseVal??e.className,text:e.textContent,rect:rect(e),styles:Object.fromEntries(['color','backgroundColor','borderRadius','borderTopWidth','borderColor','padding','gap','fontFamily','fontSize','fontWeight','lineHeight','opacity','boxShadow','transform','margin'].map(k=>[k,s[k]])),after:{width:a.width,height:a.height,left:a.left,top:a.top,background:a.backgroundColor,transform:a.transform}};
    });
    return {viewport:[innerWidth,innerHeight],dpr:devicePixelRatio,theme:document.documentElement.dataset.theme,bodyFont:getComputedStyle(document.body).fontFamily,tokens:Object.fromEntries(['background','card-background','primary','primary-text','fill','border','text','text-secondary','success','warning','danger'].map(k=>[k,getComputedStyle(document.documentElement).getPropertyValue('--'+k).trim()])),nodes};
   });
   console.log('web '+key);
  }catch(e){failures.push({key,error:String(e)})}
 }
 await context.close();
 await fs.writeFile(out+'/web-metrics.json',JSON.stringify({metrics,failures},null,2));
}
await browser.close();
console.log(JSON.stringify({captures:Object.keys(metrics).length,failures}));
