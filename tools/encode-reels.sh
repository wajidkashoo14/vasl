#!/usr/bin/env bash
# One-off: build web-sized encodes + poster frames for the reels grid.
#
# Every source is a 16:9 landscape film, but they arrive mis-oriented two
# different ways:
#   1,4,5,10  stored correct (1920x1080) but carry a bogus "rotation -90"
#             displaymatrix, so ffmpeg's autorotate turns them on their side.
#             -noautorotate takes the stored pixels as they are.
#   2,3,6,7,8,9  stored as portrait with the pixels already turned, and no
#             metadata to say so. transpose=2 rotates them 90 CCW back.
# Everything lands at 1280x720, 30fps.
set -u
FF=$(python -c "import imageio_ffmpeg;print(imageio_ffmpeg.get_ffmpeg_exe())")
rm -rf reels/web reels/posters
mkdir -p reels/web reels/posters

FLAGGED="1 4 5 10"
TURNED="2 3 6 7 8 9"

# $1 = index, $2 = filter chain, $3 = optional input flag (must precede -i).
# -display_rotation 0 both ignores the bogus flag AND keeps it off the output,
# which plain -noautorotate does not — it copies the side data straight through
# and the browser turns the video anyway.
encode () {
  local i=$1 filter=$2 inopt=${3:-}
  "$FF" -hide_banner -loglevel error -y $inopt -i "reels/$i.mp4" \
    -vf "$filter" \
    -c:v libx264 -preset slow -crf 28 -pix_fmt yuv420p -movflags +faststart \
    -c:a aac -b:a 96k -ac 2 \
    "reels/web/$i.mp4"
  "$FF" -hide_banner -loglevel error -y -ss 1 -i "reels/web/$i.mp4" \
    -frames:v 1 -update 1 -q:v 5 "reels/posters/$i.jpg"
  echo "done $i -> $(du -m "reels/web/$i.mp4" | cut -f1)MB"
}

for i in $FLAGGED; do encode "$i" "scale=1280:-2,fps=30" "-display_rotation 0"; done
for i in $TURNED;  do encode "$i" "transpose=2,scale=1280:-2,fps=30"; done
echo "ALL DONE"
du -sm reels/web reels/posters
