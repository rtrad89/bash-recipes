#!/bin/bash
mkdir -p ./temp_processed

for f in ./*.{mp4,wav,mp3}; do
    [ -e "$f" ] || continue
    TIMESTAMP=$(date +"%H:%M:%S.%3N")
    echo "[$TIMESTAMP] Processing: $f"
    
    # Logic: Remove silence -> Fade In -> Reverse -> Fade In (to act as Fade Out) -> Reverse
    ffmpeg -i "$f" -vn -af \
    "silenceremove=start_periods=1:start_threshold=-50dB, \
     areverse, silenceremove=start_periods=1:start_threshold=-50dB, areverse, \
     afade=t=in:st=0:d=1, \
     areverse, afade=t=in:st=0:d=12, areverse" \
    -ar 44100 -ac 2 -c:a pcm_s16le "./temp_processed/${f%.*}.wav" -y
done

ls -v ./temp_processed/*.wav | xargs -I {} echo "file '{}'" > join_list.txt
ffmpeg -f concat -safe 0 -i join_list.txt -c copy final_output.wav

