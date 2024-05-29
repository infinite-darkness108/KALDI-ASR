#!/bin/bash

# THREE MUSTS - 1. data/local/dict/lexicon.txt     2. wav/$spk_id/$utt_id.wav     3. ./text utt_id /t transliterated_text


## ## ## ##  BUILD ASR IN TEN STEPS  ## ## ## ##


#### 0. All initializations

step1=0
step2=0
step3=0
step4=0
step5=0
step6=0
step7=1
step8=1
step9=1
step10=1

feat_nj=2
train_nj=2
decode_nj=2

train_monophone=0
train_triphone=1
train_dnn=1
train_ldamllt=1
train_lstm=1
train_blstm=1

test_monophone=0
test_triphone=1
test_dnn=1
test_ldamllt=1
test_lstm=1
test_blstm=1

train_dir=data/train
test_dir=data/test

lang_dir=data/lang_bigram

graph_dir=graph
decode_dir=decode

exp=exp_FG

spk_dir=/home/ananth/Downloads/SSN_TDSC/data/mild

# Get transliterated 'text' with utt_id file and wav files stored speaker wise, ready. 


#### 1. Prepare utt, Trans and split Text and Trans to Train and Test directories

if [ $step1 == 1 ]; then
total_lines=$(wc -l < text)

num_lines_80=$((total_lines * 80 / 100))
num_lines_20=$((total_lines - num_lines_80))

shuf text > shuffled_text

mkdir -p data/train
mkdir -p data/test

head -n $num_lines_80 shuffled_text > data/train/text
tail -n $num_lines_20 shuffled_text > data/test/text

rm shuffled_text

basepath=`pwd`
cat $basepath/data/train/text | awk '{first = $1; $1 = ""; print $0;}' > $basepath/data/train/trans

awk '{print $1}' data/test/text > data/test/utt
awk '{print $1}' data/train/text > data/train/utt

echo "                   (1/10) Successfully prepared utt, trans and text into Train-Test                	        "

fi



#### 2. Split wav files and create scp into train and test accordingly

if [ $step2 == 1 ]; then

mkdir -p ./wav/train
mkdir -p ./wav/test

for x in train test; do
while IFS=$'\t' read -r utt_id _; do
    # Extract speaker name from utt_id
    speaker=$(echo "$utt_id" | sed 's/[0-9].*//')
    # Check if speaker directory exists
    if [ ! -d "wav/$x/$speaker/" ]; then
        mkdir -p "wav/$x/$speaker/"
    fi
    # Copy corresponding .wav file to wav/$x/speaker_name/
    cp "$spk_dir/$speaker/audio/$utt_id.wav" "wav/$x/$speaker/"
done < "data/$x/utt"
done

for x in train test; do
# Directory containing the .wav files
directory="./wav/$x"

# Output file name
output_file="./data/$x/wav.scp"

# Remove existing output file
rm -f "$output_file"

# Find all .wav files recursively in the directory
find "$directory" -type f -name "*.wav" | while read -r file_path; do
    # Get the file name
    file_name=$(basename "$file_path")
    file_name_without_extension="${file_name%.*}"
    # Print the file name (without extension) and path to the output file
    echo -e "$file_name_without_extension\t$file_path" >> "$output_file"
done
done

echo "                   (2/10) Successfully split wav files into Train-Test                	        "

fi




#### 3. Prepare lexicon.txt, nonsilence_phones.txt in local/dict

if [ $step3 == 1 ]; then


echo "sil" >> ./data/local/dict/optional_silence.txt

echo "sil" >> ./data/local/dict/silence_phones.txt

# Initialize an array to store unique phonemes
declare -A unique_phonemes

# Read the lexicon.txt file line by line
while IFS=$'\t' read -r word phonemes; do
    # Split the phonemes into an array
    IFS=' ' read -r -a phoneme_array <<< "$phonemes"
    
    # Iterate over the phonemes and store them as keys in the associative array
    for phoneme in "${phoneme_array[@]}"; do
        unique_phonemes["$phoneme"]=1
    done
done < ./data/local/dict/lexicon.txt

# Print the unique phonemes
for phoneme in "${!unique_phonemes[@]}"; do
    echo "$phoneme" >> ./data/local/dict/nonsilence_phones.txt
done

sort -o ./data/local/dict/nonsilence_phones.txt ./data/local/dict/nonsilence_phones.txt
grep -v "sil" ./data/local/dict/nonsilence_phones.txt > temp.txt && mv temp.txt ./data/local/dict/nonsilence_phones.txt

echo "                   (3/10) Successfully prepared ./data/local/dict                	        "

fi



#### 4. Prepare spk, utt2spk, spk2utt for Train and Test directories

if [ $step4 == 1 ]; then


cat ./data/train/utt | cut -c 1-3 > ./data/train/spk
paste ./data/train/utt ./data/train/spk > ./data/train/utt2spk
./utils/utt2spk_to_spk2utt.pl ./data/train/utt2spk > ./data/train/spk2utt

cat ./data/test/utt | cut -c 1-3 > ./data/test/spk
paste ./data/test/utt ./data/test/spk > ./data/test/utt2spk
./utils/utt2spk_to_spk2utt.pl ./data/test/utt2spk > ./data/test/spk2utt


echo "                   (4/10) Succesfully prepared spk,utt2spk,spk2utt                	        "

fi



#### 5. Create n gram language model (train/text and local/dict are enough)


if [ $step5 == 1 ]; then


kaldi_root_dir='/home/ananth/kaldi'
basepath=`pwd`


#*******************************************************************************#
#Creating input to the LM training

cat $basepath/data/train/text | awk '{first = $1; $1 = ""; print $0; }' > $basepath/data/train/trans

while read line

do
echo "<s> $line </s>" >> $basepath/data/train/lm_train.txt
done <$basepath/data/train/trans

#*******************************************************************************#

lm_arpa_path=$basepath/data/local/lm

train_dict=dict
train_lang=lang_bigram
train_folder=train

n_gram=3 # This specifies bigram or trigram. for bigram set n_gram=2 for tri_gram set n_gram=3

echo ============================================================================
echo "                   Creating  n-gram LM               	        "
echo ============================================================================

rm -rf $basepath/data/local/$train_dict/lexiconp.txt $basepath/data/local/$train_lang $basepath/data/local/tmp_$train_lang $basepath/data/$train_lang
mkdir $basepath/data/local/tmp_$train_lang

utils/prepare_lang.sh --num-sil-states 3 data/local/$train_dict '!SIL' data/local/$train_lang data/$train_lang

$kaldi_root_dir/tools/irstlm/bin/build-lm.sh -i $basepath/data/$train_folder/lm_train.txt -n $n_gram -o $basepath/data/local/tmp_$train_lang/lm_phone_bg.ilm.gz

gunzip -c $basepath/data/local/tmp_$train_lang/lm_phone_bg.ilm.gz | utils/find_arpa_oovs.pl data/$train_lang/words.txt  > data/local/tmp_$train_lang/oov.txt

gunzip -c $basepath/data/local/tmp_$train_lang/lm_phone_bg.ilm.gz | grep -v '<s> <s>' | grep -v '<s> </s>' | grep -v '</s> </s>' | grep -v 'SIL' | $kaldi_root_dir/src/lmbin/arpa2fst - | fstprint | utils/remove_oovs.pl data/local/tmp_$train_lang/oov.txt | utils/eps2disambig.pl | utils/s2eps.pl | fstcompile --isymbols=data/$train_lang/words.txt --osymbols=data/$train_lang/words.txt --keep_isymbols=false --keep_osymbols=false | fstrmepsilon > data/$train_lang/G.fst 
$kaldi_root_dir/src/fstbin/fstisstochastic data/$train_lang/G.fst 


fi




#### 6. MFCC Feature extraction and get CMVN statistics

if [ $step6 == 1 ]; then

echo ============================================================================
echo "         MFCC Feature Extration & CMVN for Training               "
echo ============================================================================

mfccdir=mfcc

for x in train test; do 
        utils/fix_data_dir.sh data/$x;
	steps/make_mfcc.sh --cmd "$train_cmd" --nj "$feat_nj" data/$x $exp/make_mfcc/$x $mfccdir || exit 1;
 	steps/compute_cmvn_stats.sh data/$x $exp/make_mfcc/$x $mfccdir || exit 1;
	utils/validate_data_dir.sh data/$x;
done

fi



#### 7. Train GMM-HMMs, DNN-HMM, LDA-MLLT, LSTM, BLSTM models

if [ $step7 == 1 ]; then

if [ $train_monophone == 1 ]; then

echo ============================================================================
echo "                   MonoPhone Training                	        "
echo ============================================================================

steps/train_mono.sh  --nj "$train_nj" --cmd "$train_cmd" $train_dir $lang_dir $exp/mono || exit 1; 

fi


if [ $train_triphone == 1 ]; then


echo ============================================================================
echo "                      Tri-phone Training                    "
echo ============================================================================

steps/align_si.sh --boost-silence 1.25 --nj "$train_nj" --cmd "$train_cmd" $train_dir $lang_dir $exp/mono $exp/mono_ali || exit 1; 

for sen in 2000; do 
for gauss in 8; do 
gauss=$(($sen * $gauss)) 

echo "========================="
echo " Sen = $sen  Gauss = $gauss"
echo "========================="

steps/train_deltas.sh --cmd "$train_cmd" $sen $gauss $train_dir $lang_dir $exp/mono_ali $exp/tri_8_$sen || exit 1; 
done;done

fi

if [ $train_dnn == 1 ]; then

echo ============================================================================
echo "                    DNN Hybrid Training                   "
echo ============================================================================

steps/align_si.sh --nj "$train_nj" --cmd "$train_cmd" $train_dir $lang_dir $exp/tri_8_2000 $exp/tri_8_2000_ali || exit 1;

# DNN hybrid system training parameters

 steps/nnet2/train_tanh.sh --mix-up 5000 --initial-learning-rate 0.015 \
 --final-learning-rate 0.002 --num-hidden-layers 3 --minibatch-size 128 --hidden-layer-dim 256 \
 --num-jobs-nnet "$train_nj" --cmd "$train_cmd" --num-epochs 15 \
  $train_dir $lang_dir $exp/tri_8_2000_ali $exp/DNN_tri_8_2000_aligned_layer3_nodes256
  
fi

if [ $train_ldamllt == 1 ]; then

echo ============================================================================
echo "                    LDA-MLLT training                    "
echo ============================================================================

steps/train_lda_mllt.sh 2500 15000  data/train data/lang_bigram exp_FG/tri_8_2000_ali exp_FG/ldamllt

fi

if [ $train_lstm == 1 ]; then

echo ============================================================================
echo "                    LSTM training                    "
echo ============================================================================

#create_configs.sh is first 305 lines of train.sh
mkdir ./exp_FG/LSTM
./steps/nnet3/lstm/create_configs.sh data/train data/lang_bigram exp_FG/tri_8_2000_ali exp_FG/LSTM
mv exp_FG/LSTM/configs/layer1.config exp_FG/LSTM/configs/final.config
./steps/nnet3/train_rnn.py --feat-dir data/train --dir exp_FG/LSTM --ali-dir exp_FG/tri_8_2000_ali --lang data/lang_bigram --cmd utils/run.pl --use-gpu false --trainer.optimization.num-jobs-final 2

fi

if [ $train_blstm == 1  ]; then

echo ============================================================================
echo "                    BLSTM training                    "
echo ============================================================================

rm -r ./data-fbank
rm -r ./exp_FG/blstm4i
./local/nnet/run_blstm.sh

fi

fi




#### 8. Test all the models on unseen data

if [ $step8 == 1 ]; then

if [ $test_monophone == 1 ]; then

echo ============================================================================
echo "                   MonoPhone Testing             	        "
echo ============================================================================

utils/mkgraph.sh --mono $lang_dir $exp/mono $exp/mono/$graph_dir || exit 1;
steps/decode.sh --nj "$decode_nj" --cmd "$decode_cmd" $exp/mono/$graph_dir $test_dir $exp/mono/$decode_dir || exit 1;
cat ./exp_FG/mono/decode/wer_*|grep "WER" | sort -n

fi

if [ $test_triphone == 1 ]; then

echo ============================================================================
echo "                  Tri-phone  Decoding                     "
echo ============================================================================

for sen in 2000; do  

echo "========================="
echo " Sen = $sen "
echo "========================="

utils/mkgraph.sh $lang_dir $exp/tri_8_$sen $exp/tri_8_$sen/$graph_dir || exit 1;
steps/decode.sh --nj "$decode_nj" --cmd "$decode_cmd"  $exp/tri_8_$sen/$graph_dir $test_dir $exp/tri_8_$sen/$decode_dir || exit 1;
done
cat ./exp_FG/tri_8_2000/decode/wer_*|grep "WER" | sort -n

fi

if [ $test_dnn == 1 ]; then

echo ============================================================================
echo "                    DNN Hybrid Testing                    "
echo ============================================================================
205
steps/nnet2/decode.sh --cmd "$decode_cmd" --nj "$decode_nj" \
 $exp/tri_8_2000/$graph_dir $test_dir \
  $exp/DNN_tri_8_2000_aligned_layer3_nodes256/$decode_dir | tee $exp/DNN_tri_8_2000_aligned_layer3_nodes256/$decode_dir/decode.log
./local/score.sh data/test exp_FG/tri_8_2000/graph exp_FG/DNN_tri_8_2000_aligned_layer3_nodes256/decode
cat ./exp_FG/DNN_tri_8_2000_aligned_layer3_nodes256/decode/wer_*|grep "WER" | sort -n

fi

if [ $test_ldamllt == 1 ]; then

echo ============================================================================
echo "                    LDA-MLLT testing                    "
echo ============================================================================

utils/mkgraph.sh data/lang_bigram exp_FG/ldamllt exp_FG/ldamllt
steps/decode.sh --nj 2 --cmd run.pl exp_FG/ldamllt data/test exp_FG/ldamllt/decode
cat ./exp_FG/ldamllt/decode/wer_*|grep "WER" | sort -n

fi

if [ $test_lstm == 1 ]; then

echo ============================================================================
echo "                    LSTM testing                    "
echo ============================================================================

utils/mkgraph.sh data/lang_bigram exp_FG/LSTM exp_FG/LSTM
steps/nnet3/decode.sh --nj 2 --cmd run.pl exp_FG/LSTM data/test exp_FG/LSTM/decode
cat ./exp_FG/LSTM/decode/wer_*|grep "WER" | sort -n

fi

if [ $test_blstm == 1 ]; then

echo ============================================================================
echo "                    BLSTM testing                    "
echo ============================================================================

#Decode (reuse HCLG graph)
utils/mkgraph.sh data/lang_bigram exp_FG/blstm4i exp_FG/blstm4i
steps/nnet/decode.sh --nj 2 --cmd run.pl --config conf/decode_dnn.config --acwt 0.1 \
exp_FG/blstm4i data-fbank/test exp_FG/blstm4i/decode || exit 1;
cat ./exp_FG/blstm4i/decode/wer_*|grep "WER" | sort -n

fi


fi




#### 9. Saving all model decodings

if [ $step9 == 1 ]; then

grep -h -Ev '^(#|nnet|LOG|apply|gmm|add|latgen-faster-mapped|copy)' exp_FG/mono/decode/log/decode*.log > exp_$xyz/output_MONO.tx

grep -h -Ev '^(#|nnet|LOG|apply|gmm|add|latgen|copy)' exp_FG/tri_8_2000/decode/log/decode*.log > exp_$xyz/output_TRI.txt

grep -h -Ev '^(#|nnet|LOG|apply|gmm|add|latgen|copy)' exp_FG/DNN_tri_8_2000_aligned_layer3_nodes256/decode/log/decode*.log > exp_$xyz/output_DNN.txt

grep -h -Ev '^(#|nnet|LOG|apply|gmm|add|latgen|copy)' exp_FG/ldamllt/decode/log/decode*.log > exp_$xyz/output_MLLT.txt

grep -h -Ev '^(#|nnet|LOG|apply|gmm|add|latgen|copy)' exp_FG/LSTM/decode/log/decode*.log > exp_$xyz/output_LSTM.txt

grep -h -Ev '^(#|nnet|LOG|apply|gmm|add|latgen|copy)' exp_FG/blstm4i/decode/log/decode*.log > exp_$xyz/output_BLSTM.txt

fi




#### 10. Store all the WER results

if [ $step10 == 1 ]; then

for x in exp_FG/*/decode*; do [ -d $x ] && grep WER $x/wer_* | utils/best_wer.sh; done >results.txt

fi


# to get per spk results
# /home/ananth/kaldi/egs/UASPEECH/s5/local1/score.sh data-fbank/test/ exp_FG/blstm4i/  exp_FG/blstm4i/decode/
