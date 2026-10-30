import {createApp,h} from 'vue';
import {Button,Tag,Switch,Card,Divider,Loading,Progress,Skeleton} from '/packages/vue/index.ts';
import {applyTheme} from '/src/commons/theme/index.js';
const params=new URLSearchParams(location.search),id=params.get('component')||'button',mode=params.get('theme')||'light';
applyTheme({mode});
const c=(C,p={},text)=>h(C,p,text===undefined?undefined:{default:()=>text});
const row=(name,children,height=92)=>h('section',{class:'sample',style:{height:height+'px'},'data-row':name},[h('div',{class:'sample-label'},name),h('div',{class:'sample-body'},children)]);
const contents={
button:()=>[row('primary / outline / text',[c(Button,{},'Save 保存'),c(Button,{variant:'outline'},'Cancel'),c(Button,{variant:'text'},'More')]),row('icons / selected / round',[c(Button,{variant:'icon',icon:'heart',selected:true,label:'Favorite'}),c(Button,{variant:'bare',icon:'sun',label:'Theme'}),c(Button,{variant:'round',icon:'arrow-right',label:'Next'})]),row('disabled',[c(Button,{disabled:true},'Disabled'),c(Button,{disabled:true,variant:'outline'},'Disabled')]),row('loading',[c(Button,{loading:true},'Saving'),c(Button,{loading:true,variant:'outline'},'Saving')])],
tag:()=>[row('display tones: blue / green / orange',[c(Tag,{},'Blue 蓝'),c(Tag,{tone:'green'},'Green'),c(Tag,{tone:'orange'},'Orange')]),row('display tones: red / gray',[c(Tag,{tone:'red'},'Red'),c(Tag,{tone:'gray'},'Gray')]),row('selectable: off / on',[c(Tag,{modelValue:false},'Option'),c(Tag,{modelValue:true},'Selected')]),row('disabled: off / on',[c(Tag,{modelValue:false,disabled:true},'Option'),c(Tag,{modelValue:true,disabled:true},'Selected')])],
switch:()=>[row('off / on',[c(Switch,{modelValue:false,label:'Off'}),c(Switch,{modelValue:true,label:'On'})]),row('disabled: off / on',[c(Switch,{modelValue:false,label:'Off',disabled:true}),c(Switch,{modelValue:true,label:'On',disabled:true})])],
card:()=>[row('default card',[c(Card,{title:'Card 标题',description:'Description / 说明',sample:'01'},h('div',{style:{height:'48px'}},'Body 内容'))],242),row('interactive card',[c(Card,{title:'Open',interactive:true},h('div',{style:{height:'48px'}},'Open card'))],180)],
divider:()=>[row('solid',[c(Divider)],100),row('center label',[c(Divider,{},'Divider 分割')],100),row('start dashed',[c(Divider,{align:'start',dashed:true},'Start')],100),row('end label',[c(Divider,{align:'end'},'End')],100),row('vertical',[h('span','Left'),c(Divider,{vertical:true}),h('span','Right')],80)],
loading:()=>[row('small 16 / medium 24 / large 32',[c(Loading,{size:'small'}),c(Loading),c(Loading,{size:'large'})]),row('with label',[c(Loading,{},'Loading 加载中')])],
progress:()=>[row('line 40 / buffer 70',[c(Progress,{value:40,buffer:70})],76),row('line success',[c(Progress,{value:100,status:'success'})],76),row('line warning',[c(Progress,{value:60,status:'warning'})],76),row('line error',[c(Progress,{value:30,status:'error'})],76),row('line indeterminate',[c(Progress)],76),row('circle 40 / success / error',[c(Progress,{value:40,type:'circle',buffer:70}),c(Progress,{value:100,type:'circle',status:'success'}),c(Progress,{value:30,type:'circle',status:'error'})],148),row('circle indeterminate / hidden readout',[c(Progress,{type:'circle'}),c(Progress,{value:60,type:'circle',showText:false})],148)],
'progress-sizes':()=>[40,64,96,128].map(size=>row('circle size '+size+' / success / error',['success','error'].map(status=>c(Progress,{value:100,type:'circle',status,style:{'--progress-size':size+'px'}})),176)),
skeleton:()=>[row('default: 3 rows',[c(Skeleton)],176),row('avatar: 3 rows',[c(Skeleton,{avatar:true})],176),row('2 rows',[c(Skeleton,{rows:2})],152),row('loaded content',[c(Skeleton,{loading:false},'Loaded 内容已就绪')],80)]
};
createApp({render:()=>h('div',{id:'stage'},[h('div',{class:'run-title'},id[0].toUpperCase()+id.slice(1)),h('div',{class:'run-meta'},mode+' / '+innerWidth+' logical px / DPR 1'),h('main',contents[id]())])}).mount('#app');
window.visualReady=true;
