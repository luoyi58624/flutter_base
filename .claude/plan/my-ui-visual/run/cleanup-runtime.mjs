import fs from 'node:fs/promises';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
const run=path.dirname(fileURLToPath(import.meta.url));
const targets=['sdk','project','runtime','vite-cache'].map(n=>path.resolve(run,n));
const summary={removed:[],files:0,directories:0,links:0,bytes:0};
// 先核验全部顶层目标在本任务输出目录内；遍历时不跟随junction。
for(const p of targets){try{const actual=await fs.realpath(p);if(!actual.toLowerCase().startsWith(run.toLowerCase()+path.sep))throw Error('清理路径越界: '+actual);}catch(e){if(e.code!=='ENOENT')throw e;}}
async function removeOwned(p){
 if(!path.resolve(p).toLowerCase().startsWith(run.toLowerCase()+path.sep))throw Error('越界: '+p);
 let st;try{st=await fs.lstat(p);}catch(e){if(e.code==='ENOENT')return;throw e;}
 if(st.isSymbolicLink()){try{await fs.unlink(p);}catch(e){if(e.code==='EPERM')await fs.rmdir(p);else throw e;}summary.links++;return;}
 if(st.isDirectory()){for(const n of await fs.readdir(p))await removeOwned(path.join(p,n));await fs.rmdir(p);summary.directories++;}
 else{await fs.unlink(p);summary.files++;summary.bytes+=st.size;}
}
for(const p of targets){await removeOwned(p);summary.removed.push(p);}
await fs.writeFile(path.join(run,'cleanup-summary.json'),JSON.stringify(summary,null,2));
console.log(JSON.stringify(summary));
