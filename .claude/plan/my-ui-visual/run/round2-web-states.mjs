import fs from 'node:fs/promises';import{createRequire}from'node:module';
const req=createRequire('D:/project/html/my-ui/package.json'),{chromium}=req('playwright'),out='D:/project/flutter/flutter_base/.claude/plan/my-ui-visual/round2';
const browser=await chromium.launch({headless:true,executablePath:'C:/Program Files/Google/Chrome/Application/chrome.exe'});
const results={};
for(const [width,theme] of[[390,'light'],[1440,'dark']]){
 const ctx=await browser.newContext({viewport:{width,height:900},deviceScaleFactor:1,reducedMotion:'reduce'});
 const page=await ctx.newPage();page.setDefaultTimeout(10000);
 for(const id of['button','tag','switch','card']){
  await page.goto('http://127.0.0.1:5189/@fs/'+'D:/project/flutter/flutter_base/.claude/plan/my-ui-visual/run/round2-fixture.html?component='+id+'&theme='+theme,{waitUntil:'domcontentloaded'});
  await page.waitForFunction(()=>window.visualReady);
  const sel={button:'button[data-my-button]',tag:'button.my-is-selectable[data-my-tag]',switch:'input[data-my-switch]',card:'.my-tappable-card[data-my-card]'}[id];
  const target=page.locator(sel).first();
  await page.keyboard.press('Tab');await target.focus();
  for(const state of['focus','hover','pressed']){
   if(state==='hover'){await target.evaluate(e=>e.blur());await target.hover()}
   if(state==='pressed')await page.mouse.down();
   const key=id+'-'+width+'-'+theme+'-'+state;
   await page.screenshot({path:out+'/web-state-'+key+'.png',animations:'disabled'});
   results[key]=await target.evaluate(e=>{const s=getComputedStyle(e),r=e.getBoundingClientRect();return {background:s.backgroundColor,transform:s.transform,outline:s.outline,outlineOffset:s.outlineOffset,rect:{x:r.x,y:r.y,width:r.width,height:r.height},focusVisible:e.matches(':focus-visible'),pressed:e.hasAttribute('data-my-pressed')||e.matches(':active')}});
  }
  await page.mouse.up();await page.mouse.move(1,1);
  console.log('states '+id+'-'+width+'-'+theme);
 }
 await ctx.close();
}
await fs.writeFile(out+'/web-state-metrics.json',JSON.stringify(results,null,2));await browser.close();
