import json, os
from PIL import Image, ImageChops, ImageStat, ImageDraw, ImageFont
out=r'D:\project\flutter\flutter_base\.claude\plan\my-ui-visual'
heights={'button':470,'tag':470,'switch':310,'card':570,'divider':650,'loading':310,'progress':880,'skeleton':760}
font=ImageFont.truetype(r'C:\Windows\Fonts\arial.ttf',16)
stats={}
for name,height in heights.items():
 for width in [390,1440]:
  for theme in ['light','dark']:
   key=f'{name}-{width}-{theme}'
   a=Image.open(os.path.join(out,'web-'+key+'.png')).convert('RGB')
   b=Image.open(os.path.join(out,'flutter-'+key+'.png')).convert('RGB')
   assert a.size==b.size==(width,900), (key,a.size,b.size)
   cw=min(width,780)
   sheet=Image.new('RGB',(cw*2,height+32),'#dedfe3')
   draw=ImageDraw.Draw(sheet)
   draw.text((12,7),'Web example Vue | '+key,fill='#111111',font=font)
   draw.text((cw+12,7),'Flutter tester | '+key,fill='#111111',font=font)
   sheet.paste(a.crop((0,0,cw,height)),(0,32));sheet.paste(b.crop((0,0,cw,height)),(cw,32))
   sheet.save(os.path.join(out,'compare-'+key+'.png'))
   box=(24,120,min(width-24,744),height)
   diff=ImageChops.difference(a.crop(box),b.crop(box))
   pix=list(diff.getdata())
   stats[key]={'crop':box,'mae_rgb':round(sum(ImageStat.Stat(diff).mean)/3,3),'changed_gt_16_percent':round(sum(max(p)>16 for p in pix)*100/len(pix),3)}
with open(os.path.join(out,'pixel-comparison.json'),'w') as f:json.dump(stats,f,indent=2)
print('32 source pairs verified; 32 comparison sheets saved')

for name in ['button','tag','switch','card']:
 for width,theme in [(390,'light'),(1440,'dark')]:
  for state in ['focus','hover','pressed']:
   key=f'{name}-{width}-{theme}-{state}'
   a=Image.open(os.path.join(out,'web-state-'+key+'.png')).convert('RGB')
   b=Image.open(os.path.join(out,'flutter-state-'+key+'.png')).convert('RGB')
   cw=min(width,780);height=heights[name]
   sheet=Image.new('RGB',(cw*2,height+32),'#dedfe3');draw=ImageDraw.Draw(sheet)
   draw.text((12,7),'Web | '+key,fill='#111111',font=font);draw.text((cw+12,7),'Flutter | '+key,fill='#111111',font=font)
   sheet.paste(a.crop((0,0,cw,height)),(0,32));sheet.paste(b.crop((0,0,cw,height)),(cw,32))
   sheet.save(os.path.join(out,'compare-state-'+key+'.png'))
print('24 state comparison sheets saved')
