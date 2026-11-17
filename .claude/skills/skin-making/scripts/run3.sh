# Round 3 pipeline: bash run3.sh <out_dir> [robe k=v ...]
set -e
B="/c/Program Files/Blender Foundation/Blender 5.1/blender.exe"
O=$1; shift
mkdir -p $O
"$B" -b --disable-autoexec -P ss_blockout.py -- $O > $O/log_pieces.txt 2>&1
"$B" -b --disable-autoexec -P ss_robe.py -- $O "$@" > $O/log_robe.txt 2>&1
"$B" -b --disable-autoexec -P render_blockout.py -- $O > $O/log_render.txt 2>&1
"$B" -b --disable-autoexec -P pose_demo.py -- $O >> $O/log_render.txt 2>&1
"$B" -b --disable-autoexec -P gate_holes.py -- $O > $O/log_gate.txt 2>&1
"$B" -b --disable-autoexec -P gate_holes.py -- $O pose >> $O/log_gate.txt 2>&1
python gate_check.py $O
python gate_check.py $O pose
grep -h "OK\|DRAPED\|CLAMP\|ROBE verts\|Error\|Traceback" $O/log_*.txt
