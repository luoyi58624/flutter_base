import fs from 'node:fs/promises';import{createRequire}from'node:module';
const req=createRequire('D:/project/html/my-ui/package.json'),{chromium}=req('playwright');
const out='D:/project/flutter/flutter_base/.claude/plan/my-ui-visual';
const results=JSON.parse(await fs.readFile(out+'/web-metrics.json','utf8'));
const browser=await chromium.launch({headless:true,executablePath:'C:/Program Files/Google/Chrome/Application/chrome.exe'});
for(const width of[390,1440])for(const theme of['light','dark']){
 const ctx=await browser.newContext({viewport:{width,height:900},deviceScaleFactor:1,reducedMotion:'reduce'});
 await ctx.addInitScript(mode=>localStorage.setItem('my-ui:theme',JSON.stringify({mode})),theme);
 const page=await ctx.newPage();page.setDefaultTimeout(10000);
 await page.goto('http://127.0.0.1:5189/#/example/scenarios',{waitUntil:'domcontentloaded'});
 await page.getByRole('button',{name:'重新加载',exact:true}).waitFor();
 await page.clock.install();
 await page.clock.pauseAt(new Date(Date.now()+100));
 await page.getByRole('button',{name:'重新加载',exact:true}).click();
 await page.locator('[data-my-component="Loading"]').first().waitFor();
 await page.locator('[data-my-component="Loading"]').first().scrollIntoViewIfNeeded();
 for(const id of['loading','skeleton']){
  const key='example-'+id+'-'+width+'-'+theme;
  await page.screenshot({path:out+'/'+key+'.png',animations:'disabled'});
  results.metrics[key]={url:page.url(),state:'reloadFeed真实点击；850ms恢复计时器由Playwright Clock暂停',count:await page.locator('[data-my-component="'+id[0].toUpperCase()+id.slice(1)+'"]').count(),errors:[]};
  results.failures=results.failures.filter(x=>x.key!==key);
  console.log(key);
 }
 await ctx.close();
 await fs.writeFile(out+'/web-metrics.json',JSON.stringify(results,null,2));
}await browser.close();