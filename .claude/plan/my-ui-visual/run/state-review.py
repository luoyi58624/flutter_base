import os
from PIL import Image, ImageDraw, ImageFont
out=r'D:\project\flutter\flutter_base\.claude\plan\my-ui-visual'
font=ImageFont.truetype(r'C:\Windows\Fonts\arial.ttf',16)
for name,top,bottom in [('button',108,174),('tag',292,346),('switch',108,162),('card',350,480)]:
 for width,theme in [(390,'light'),(1440,'dark')]:
  cw=min(width,780);rh=bottom-top+32
  sheet=Image.new('RGB',(cw*2,rh*3),'#dedfe3');draw=ImageDraw.Draw(sheet)
  for i,state in enumerate(['focus','hover','pressed']):
   y=i*rh;key=f'{name}-{width}-{theme}-{state}'
   draw.text((12,y+7),'Web '+key,fill='#111111',font=font)
   draw.text((cw+12,y+7),'Flutter '+key,fill='#111111',font=font)
   for j,side in enumerate(['web','flutter']):
    im=Image.open(os.path.join(out,side+'-state-'+key+'.png')).convert('RGB')
    sheet.paste(im.crop((0,top,cw,bottom)),(j*cw,y+32))
  sheet.save(os.path.join(out,f'states-review-{name}-{width}-{theme}.png'))
print('8 state review sheets saved')
