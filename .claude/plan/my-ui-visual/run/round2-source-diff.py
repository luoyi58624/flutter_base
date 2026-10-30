import json,difflib,pathlib
r=pathlib.Path(r'D:\project\flutter\flutter_base');out=r/'.claude/plan/my-ui-visual/round2';old=json.loads((out/'source-before.json').read_text('utf-8'));lines=[];old['test/my_ui/glyph_size_test.dart']=''
for p,s in old.items():
 now=(r/p).read_text('utf-8');lines.extend(difflib.unified_diff(s.splitlines(True),now.splitlines(True),fromfile=p+' before',tofile=p+' after'))
(out/'source-changes.diff').write_text(''.join(lines),encoding='utf-8');print(''.join(lines))
