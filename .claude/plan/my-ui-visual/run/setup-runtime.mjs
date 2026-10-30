// 仅在本验收目录创建隔离缓存；原SDK、真源、依赖声明保持只读。
import fs from 'node:fs/promises';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
const run=path.dirname(fileURLToPath(import.meta.url)),root=path.resolve(run,'../../../..');
const original='D:/app/fvm/versions/stable',sdk=run+'/sdk',project=run+'/project';
const link=async(a,b)=>{try{await fs.symlink(a,b,'junction')}catch(e){if(e.code!=='EEXIST')throw e}};
await fs.mkdir(sdk+'/bin/cache',{recursive:true});
for(const e of await fs.readdir(original,{withFileTypes:true})){
 if(e.name==='bin')continue;
 if(e.isDirectory())await link(original+'/'+e.name,sdk+'/'+e.name);
 else await fs.copyFile(original+'/'+e.name,sdk+'/'+e.name);
}
for(const e of await fs.readdir(original+'/bin/cache',{withFileTypes:true})){
 if(e.name.includes('lock')||e.name.includes('.old'))continue;
 if(e.isDirectory())await link(original+'/bin/cache/'+e.name,sdk+'/bin/cache/'+e.name);
 else await fs.copyFile(original+'/bin/cache/'+e.name,sdk+'/bin/cache/'+e.name);
}
await link(original+'/bin/internal',sdk+'/bin/internal');
await fs.mkdir(project+'/.dart_tool',{recursive:true});
for(const f of ['pubspec.yaml','pubspec.lock','analysis_options.yaml'])await fs.copyFile(root+'/'+f,project+'/'+f);
await link(root+'/lib',project+'/lib');
const cfg=JSON.parse(await fs.readFile(root+'/.dart_tool/package_config.json','utf8'));
cfg.packages.find(p=>p.name==='flutter_base').rootUri='../';
await fs.writeFile(project+'/.dart_tool/package_config.json',JSON.stringify(cfg,null,2));
await fs.copyFile(root+'/.dart_tool/package_graph.json',project+'/.dart_tool/package_graph.json');
for(const p of ['runtime/local','runtime/roaming'])await fs.mkdir(run+'/'+p,{recursive:true});
console.log('ISOLATED_RUNTIME_READY');
