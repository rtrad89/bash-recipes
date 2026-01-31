#!/bin/bash
set -e
# Prepare the WAV
mkdir -p ./temp_processed ./combined
touch errors.log

if (( $(find temp_processed -type f -iname "*.wav" | wc -l) > 0)); then
    echo "Trimmed files are found, skipping trimming..."
else
    echo '************************************'
    echo '***********TRIMMING STAGE***********'
    echo '************************************'
    for f in ./*.{mp3,m4a,mp4}; do
        [ -e "$f" ] || continue
        TIMESTAMP=$(date +"%H:%M:%S.%3N")
        echo "[$TIMESTAMP] Trimming: $f"
        
        # Logic: Remove silence -> Fade In -> Reverse -> Fade In (to act as Fade Out) -> Reverse
        ffmpeg -i "$f" -vn -af \
        "silenceremove=start_periods=1:start_threshold=-50dB, \
        areverse, silenceremove=start_periods=1:start_threshold=-50dB, areverse" \
        -ar 44100 -ac 2 -c:a pcm_s16le -y "./temp_processed/${f%.*}.wav" >/dev/null 2>errors.log
    done
fi

# 1. Get your files in a natural order
echo '************************************'
echo '***********SPLICING STAGE***********'
echo '************************************'
echo 'Building the files array...'
mapfile -t FILES < <(ls -v ./temp_processed/*.wav)

# 2. Initialize the master with the first file
echo "Starting with ${FILES[0]}"
cp "${FILES[0]}" ./combined/master.wav

# 3. Loop through the rest starting from the second file
for (( i=1; i<${#FILES[@]}; i++ )); do
    TIMESTAMP=$(date +"%H:%M:%S.%3N")
    echo "[$TIMESTAMP] Splicing ${FILES[$i]} into master..."
    
    # Crossfade the current master and the next file
    # d=10 is 10 second crossfade, c1/c2=exp is exponential (sounds most natural)
	ffmpeg \
	-i ./combined/master.wav \
	-i "${FILES[$i]}" \
	-filter_complex "acrossfade=d=10:c1=tri:c2=tri" \
	-y ./combined/master_next.wav >/dev/null 2>errors.log
    
    # Move the result to master for the next iteration
    mv ./combined/master_next.wav ./combined/master.wav
done

# 4. Final conversion to MP3
echo '************************************'
echo '**********FINAL CONVERSION**********'
echo '************************************'
echo 'Encoding the final file as final_output.mp3...'
ffmpeg -i ./combined/master.wav -codec:a libmp3lame -q:a 0 ./combined/final_output.mp3 >/dev/null 2>errors.log

echo '**************ALL DONE**************'
