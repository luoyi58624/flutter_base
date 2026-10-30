from PIL import Image
import json,os
out=r'D:\project\flutter\flutter_base\.claude\plan\my-ui-visual'
r={}
for side in ['web','flutter']:
 im=Image.open(os.path.join(out,side+'-loading-390-light.png')).convert('RGB');box=(88,120,120,152);crop=im.crop(box);pts=[(x,y)for y in range(32)for x in range(32)if max(crop.getpixel((x,y)))<120];r[side]={'dark_stroke_coverage_local_inclusive':[min(x for x,y in pts),min(y for x,y in pts),max(x for x,y in pts),max(y for x,y in pts)]}
print(json.dumps(r));open(os.path.join(out,'glyph-pixel-coverage.json'),'w').write(json.dumps(r,indent=2))
