"""基于真实 DOM、RenderBox 和 PNG 生成 round 2 度量，不用像素平均误差替代验收。"""
import json, math, hashlib
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
out = Path(r'D:\project\flutter\flutter_base\.claude\plan\my-ui-visual\round2')
old = out.parent
web = json.loads((out/'web-metrics.json').read_text('utf-8'))
flutter = json.loads((out/'flutter-metrics.json').read_text('utf-8'))
baselines = json.loads((out/'web-baselines.json').read_text('utf-8'))
assert len(web['metrics']) == len(flutter) == 36
assert web['failures'] == []
web = web['metrics']
summary = {'dpr': 1, 'loading': {}, 'progress': {}, 'button': {}, 'tag': {}, 'card': {}, 'skeletonLoaded': {}}
def center(r):
    return (r['x']+r['width']/2, r['y']+r['height']/2)
def distance(a, b):
    return math.hypot(a[0]-b[0], a[1]-b[1])
for width in [390, 1440]:
    for theme in ['light', 'dark']:
        suffix = f'{width}-{theme}'
        fl = flutter['loading-'+suffix]
        summary['loading'][suffix] = []
        for i, (name, size) in enumerate([('small',16),('medium',24),('large',32)]):
            g, frame = fl['glyphs'][i], fl['positions'][name]
            assert g['width'] == g['height'] == size
            delta = distance(center(g), center(frame))
            assert delta < 1e-6
            summary['loading'][suffix].append({'size':size,'glyph':g,'frame':frame,'centerDistance':delta})
        fc = flutter['progress-sizes-'+suffix]
        wc = web['progress-sizes-'+suffix]['glyphs']
        circles = []
        for i, (name, frame) in enumerate(fc['positions'].items()):
            size = float(name.split('-')[0])
            g = fc['glyphs'][i]
            wg = wc[i*2+1]['rect']
            assert abs(g['width']-size*.28) < 1e-6
            assert abs(g['height']-size*.28) < 1e-6
            delta = distance(center(g), center(frame))
            assert delta < 1e-6
            circles.append({'sample':name,'expected':size*.28,'flutter':g,'web':wg,'centerDistance':delta,'widthDelta':g['width']-wg['width']})
        standard = flutter['progress-'+suffix]['glyphs']
        assert all(abs(g['width']-expected)<1e-6 and abs(g['height']-expected)<1e-6 for g,expected in zip(standard,[18,18,26.88,26.88]))
        summary['progress'][suffix] = {'circleSizes':circles,'standardGlyphs':standard}
        fw = flutter['button-'+suffix]
        button = []
        used = {}
        for node in web['button-'+suffix]['nodes']:
            if node['component'] != 'Button' or node['text'] not in ['Save 保存','Cancel']:
                continue
            ident = 'primary' if node['text']=='Save 保存' else 'outline'
            fp = fw['positions'][ident]
            tx = next(x for x in fw['texts'] if x['text']==node['text'])
            base = next(x for x in baselines[suffix] if x['text']==node['text'])
            assert max(abs(x) for x in base['probeDelta'].values()) == 0
            button.append({'text':node['text'],'webWidth':node['rect']['width'],'flutterWidth':fp['width'],'widthDelta':fp['width']-node['rect']['width'],'webBaseline':base['baseline'],'flutterBaseline':tx['baseline'],'baselineDelta':tx['baseline']-base['baseline']})
        summary['button'][suffix] = button
        tagWeb = next(n for n in web['tag-'+suffix]['nodes'] if n['component']=='Tag' and n['text']=='Blue 蓝')['rect']
        tagFlutter = flutter['tag-'+suffix]['positions']['blue']
        summary['tag'][suffix] = {'web':tagWeb,'flutter':tagFlutter,'widthDelta':tagFlutter['width']-tagWeb['width']}
        cardWeb = next(n for n in web['card-'+suffix]['nodes'] if n['class']=='my-card')['rect']
        cardFlutter = flutter['card-'+suffix]['positions']['default']
        summary['card'][suffix] = {'web':cardWeb,'flutter':cardFlutter,'heightDelta':cardFlutter['height']-cardWeb['height']}
        skeletonWeb = next(n for n in web['skeleton-'+suffix]['nodes'] if n['component']=='Skeleton' and n['text']=='Loaded 内容已就绪')['rect']
        skeletonFlutter = flutter['skeleton-'+suffix]['positions']['loaded']
        summary['skeletonLoaded'][suffix] = {'web':skeletonWeb,'flutter':skeletonFlutter,'heightDelta':skeletonFlutter['height']-skeletonWeb['height']}
coverage = {}
for theme in ['light','dark']:
    coverage[theme] = {}
    for side in ['web','flutter']:
        im = Image.open(out/f'{side}-loading-390-{theme}.png').convert('RGB')
        result = []
        for name, rect in list(flutter[f'loading-390-{theme}']['positions'].items())[:3]:
            x,y,s = round(rect['x']),round(rect['y']),round(rect['width'])
            crop = im.crop((x,y,x+s,y+s))
            points = [(xx,yy) for yy in range(s) for xx in range(s) if (max(crop.getpixel((xx,yy)))<120 if theme=='light' else min(crop.getpixel((xx,yy)))>150)]
            bbox = [min(p[0] for p in points),min(p[1] for p in points),max(p[0] for p in points),max(p[1] for p in points)]
            result.append({'sample':name,'frameSize':s,'inkBoundsInclusive':bbox,'inkWidth':bbox[2]-bbox[0]+1,'inkHeight':bbox[3]-bbox[1]+1})
        coverage[theme][side] = result
assert coverage['light']['web'][-1]['inkBoundsInclusive'] == coverage['light']['flutter'][-1]['inkBoundsInclusive'] == [2,2,29,29]
(out/'glyph-pixel-coverage.json').write_text(json.dumps(coverage,ensure_ascii=False,indent=2),'utf-8')
summary['inkCoverage'] = coverage
font = ImageFont.truetype(r'C:\Windows\Fonts\arial.ttf',16)
for kind, box in [('loading',(84,116,124,156)),('progress',(146,554,182,590))]:
    # Progress 的实际裁剪位置由 glyph 记录确定，避免依赖页面标签高度。
    if kind=='progress':
        g=flutter['progress-390-light']['glyphs'][2]
        box=(math.floor(g['x'])-4,math.floor(g['y'])-4,math.ceil(g['x']+g['width'])+4,math.ceil(g['y']+g['height'])+4)
    source=[('Web',out/f'web-{kind}-390-light.png'),('Before',old/f'flutter-{kind}-390-light.png'),('After',out/f'flutter-{kind}-390-light.png')]
    cw,ch=(box[2]-box[0])*6,(box[3]-box[1])*6
    sheet=Image.new('RGB',(cw*3,ch+32),'#dedfe3')
    draw=ImageDraw.Draw(sheet)
    for i,(title,file) in enumerate(source):
        draw.text((cw*i+8,6),title,fill='#111111',font=font)
        with Image.open(file) as im:
            sheet.paste(im.convert('RGB').crop(box).resize((cw,ch),Image.NEAREST),(cw*i,32))
    sheet.save(out/f'fix-proof-{kind}.png')
(out/'measured-summary.json').write_text(json.dumps(summary,ensure_ascii=False,indent=2),'utf-8')
manifest=[]
for file in sorted(out.glob('*.png')):
    with Image.open(file) as im:
        im.verify()
    with Image.open(file) as im:
        size=im.size
    manifest.append({'file':file.name,'width':size[0],'height':size[1],'sha256':hashlib.sha256(file.read_bytes()).hexdigest()})
(out/'screenshot-manifest.json').write_text(json.dumps(manifest,indent=2),'utf-8')
print(json.dumps({'pngCount':len(manifest),'loading32Ink':coverage['light'],'button':summary['button']['390-light'],'card':summary['card'],'skeletonLoaded':summary['skeletonLoaded']['390-light']},ensure_ascii=False,indent=2))
