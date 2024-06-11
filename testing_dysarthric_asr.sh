#!/bin/bash



input_wav_path="ASR_test_data/FDH/test/S1_1_1.wav"









source cmd.sh
source path.sh

rm -rf ./mfcc
rm -rf ./wav_test

mkdir -p test_one
mkdir -p wav_test

last_part=$(echo "$input_wav_path" | rev | cut -d'/' -f1 | rev)
base_name=$(basename "$last_part" .wav)
spk=$(echo "$input_wav_path" | cut -d'/' -f2)

sox "$input_wav_path" "wav_test/$base_name.wav"          # This is done becuase the .wav file was actually in sphere (.sph) format. 
echo "$base_name wav_test/$base_name.wav" > test_one/wav.scp
echo "$base_name" > test_one/utt
echo "$spk" > test_one/spk
paste test_one/utt test_one/spk > test_one/utt2spk
paste test_one/spk test_one/utt > test_one/spk2utt


#feature extraction for test cases

steps/make_mfcc.sh --cmd "run.pl" --nj 1 test_one models/asr/kaldi_dysarthria/exp_FDH/make_mfcc/test mfcc
steps/compute_cmvn_stats.sh test_one models/asr/kaldi_dysarthria/exp_FDH/make_mfcc/test mfcc

#decode using monophone GMM-HMM

steps/decode.sh --nj "1" --cmd "run.pl" models/asr/kaldi_dysarthria/exp_FDH/mono/graph test_one models/asr/kaldi_dysarthria/exp_FDH/mono/decode

#Store the decoded result

grep -h -Ev '^(#|nnet|LOG|apply|gmm|add|latgen-faster-mapped|copy|WARNING)' models/asr/kaldi_dysarthria/exp_FDH/mono/decode/log/decode.1.log > output_MONO.txt

cat output_MONO.txt


