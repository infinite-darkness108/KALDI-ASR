#!/bin/bash

train_cmd=run.pl
decode_cmd=run.pl

feat_nj=10
train_nj=10
decode_nj=10

reduce_lexicon=0
extract_mfcc=1
proper_format=1

train_monophone=1
train_triphone=1
train_dnn=1
train_ldamllt=1
train_lstm=1
train_blstm=1

test_monophone=1
test_triphone=1
test_dnn=1
test_ldamllt=1
test_lstm=1
test_blstm=1


if [ $proper_format == 1 ]; then

touch text
mkdir data
mkdir data/train
mkdir data/test
touch ./data/train/text
touch ./data/test/text
touch ./data/train/utt
touch ./data/test/utt
mkdir data/local
mkdir wav
mkdir wav/train
mkdir wav/test
mkdir data/local/dict
touch ./data/train/wav.scp
touch ./data/test/wav.scp
touch ./data/local/dict/nonsilence_phones.txt
touch ./data/local/dict/silence_phones.txt
touch ./data/local/dict/optional_silence.txt
complete_text_file_path="/media/speech/hdd-2tb/datasets/SSN_TDSC/documents/complete_text"
directory_of_speakers="/media/speech/hdd-2tb/datasets/SSN_TDSC/data/control"
ref_spkr="FC01"


python KD.py "$directory_of_speakers" "$complete_text_file_path" "$ref_spkr"

cat ./data/train/utt | cut -c 1-4 > ./data/train/spk
paste ./data/train/utt ./data/train/spk > ./data/train/utt2spk
./utils/utt2spk_to_spk2utt.pl ./data/train/utt2spk > ./data/train/spk2utt

cat ./data/test/utt | cut -c 1-4 > ./data/test/spk
paste ./data/test/utt ./data/test/spk > ./data/test/utt2spk
./utils/utt2spk_to_spk2utt.pl ./data/test/utt2spk > ./data/test/spk2utt

./Create_ngram_LM.sh
fi

#clear


#================================================
#      Set Directories
#================================================

train_dir=data/train
test_dir=data/test


lang_dir=data/lang_bigram

graph_dir=graph
decode_dir=decode

exp=exp_FG


if [ $extract_mfcc == 1 ]; then

#====================================================
echo ============================================================================
echo "         MFCC Feature Extration & CMVN for Training               "
echo ============================================================================
#extract MFCC features and perfrom CMVN

mfccdir=mfcc

for x in train test; do 
        utils/fix_data_dir.sh data/$x;
	steps/make_mfcc.sh --cmd "$train_cmd" --nj "$feat_nj" data/$x $exp/make_mfcc/$x $mfccdir || exit 1;
 	steps/compute_cmvn_stats.sh data/$x $exp/make_mfcc/$x $mfccdir || exit 1;
	utils/validate_data_dir.sh data/$x;
done

fi





if [ $train_monophone == 1 ]; then

echo ============================================================================
echo "                   MonoPhone Training                	        "
echo ============================================================================

fi




if [ $train_triphone == 1 ]; then

steps/train_mono.sh  --nj "$train_nj" --cmd "$train_cmd" $train_dir $lang_dir $exp/mono || exit 1; 

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

./local/nnet/run_blstm.sh

fi

if [ $reduce_lexicon == 1 ]; then

python3 reduce_lexicon.py
./Create_ngram_LM.sh
utils/fix_data_dir.sh  data/train
utils/fix_data_dir.sh  data/test
steps/make_mfcc.sh  --nj 10  data/train  exp_FG/make_mfcc/train  mfcc
steps/make_mfcc.sh  --nj 10  data/test  exp_FG/make_mfcc/test  mfcc
steps/compute_cmvn_stats.sh  data/train  exp_FG/make_mfcc/train mfcc
steps/compute_cmvn_stats.sh  data/test  exp_FG/make_mfcc/test mfcc
utils/validate_data_dir.sh  data/train
utils/validate_data_dir.sh  data/test

fi

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
steps/decode.sh --nj 10 --cmd run.pl exp_FG/ldamllt data/test exp_FG/ldamllt/decode
cat ./exp_FG/ldamllt/decode/wer_*|grep "WER" | sort -n

fi

if [ $test_lstm == 1 ]; then

echo ============================================================================
echo "                    LSTM testing                    "
echo ============================================================================

utils/mkgraph.sh data/lang_bigram exp_FG/LSTM exp_FG/LSTM
steps/nnet3/decode.sh --nj 10 --cmd run.pl exp_FG/LSTM data/test exp_FG/LSTM/decode
cat ./exp_FG/LSTM/decode/wer_*|grep "WER" | sort -n

fi

if [ $test_blstm == 1 ]; then

echo ============================================================================
echo "                    BLSTM testing                    "
echo ============================================================================

#Decode (reuse HCLG graph)
utils/mkgraph.sh data/lang_bigram exp_FG/blstm4i exp_FG/blstm4i
steps/nnet/decode.sh --nj 10 --cmd run.pl --config conf/decode_dnn.config --acwt 0.1 \
exp_FG/blstm4i data-fbank/test exp_FG/blstm4i/decode || exit 1;
cat ./exp_FG/blstm4i/decode/wer_*|grep "WER" | sort -n

fi

# Getting results [see RESULTS file]
for x in exp_FG/*/decode*; do [ -d $x ] && grep WER $x/wer_* | utils/best_wer.sh; done >results.txt
