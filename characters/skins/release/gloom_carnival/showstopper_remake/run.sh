# Remake blockout pipeline: bash run.sh <out_dir> [skirt k=v ...]
set -e
B="/c/Program Files/Blender Foundation/Blender 5.1/blender.exe"
O=$1; shift
mkdir -p $O
"$B" -b --disable-autoexec -P ss_blockout.py -- $O > $O/log_pieces.txt 2>&1
"$B" -b --disable-autoexec -P remake_skirt.py -- $O "$@" > $O/log_skirt.txt 2>&1
"$B" -b --disable-autoexec -P ../showstopper_tails/ss_finish.py -- $O > $O/log_finish.txt 2>&1
"$B" -b --disable-autoexec -P render_blockout.py -- $O > $O/log_render.txt 2>&1
"$B" -b --disable-autoexec -P render_blockout.py -- $O flat >> $O/log_render.txt 2>&1
python -c "
from PIL import Image
for m in ('lit','flat'):
    ims=[Image.open('$O/%s_%s.png'%(m,v)) for v in ['front','three_quarter','side','back']]
    s=Image.new('RGB',(sum(i.width for i in ims),ims[0].height));x=0
    for i in ims: s.paste(i,(x,0)); x+=i.width
    s.thumbnail((2400,800)); s.save('$O/sheet_%s.png'%m)"
grep -h "OK\|DRAPED" $O/log_*.txt
