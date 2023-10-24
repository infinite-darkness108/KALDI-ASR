#!/usr/bin/env bash

# THIS SCRIPT IS DEPRECATED, see ../train_rnn.py

# Copyright 2012-2015  Johns Hopkins University (Author: Daniel Povey).
#           2013  Xiaohui Zhang
#           2013  Guoguo Chen
#           2014  Vimal Manohar
#           2014-2015  Vijayaditya Peddinti
# Apache 2.0.

# Terminology:
# sample - one input-output tuple, which is an input sequence and output sequence for LSTM
# frame  - one output label and the input context used to compute it

# Begin configuration section.
cmd=run.pl
num_epochs=10      # Number of epochs of training;
                   # the number of iterations is worked out from this.
initial_effective_lrate=0.0003
final_effective_lrate=0.00003
num_jobs_initial=1 # Number of neural net jobs to run in parallel at the start of training
num_jobs_final=8   # Number of neural net jobs to run in parallel at the end of training
prior_subset_size=20000 # 20k samples per job, for computing priors.
num_jobs_compute_prior=10 # these are single-threaded, run on CPU.
get_egs_stage=0    # can be used for rerunning after partial
online_ivector_dir=
presoftmax_prior_scale_power=-0.25  # we haven't yet used pre-softmax prior scaling in the LSTM model
remove_egs=true  # set to false to disable removing egs after training is done.

max_models_combine=20 # The "max_models_combine" is the maximum number of models we give
  # to the final 'combine' stage, but these models will themselves be averages of
  # iteration-number ranges.

shuffle_buffer_size=5000 # This "buffer_size" variable controls randomization of the samples
                # on each iter.  You could set it to 0 or to a large value for complete
                # randomization, but this would both consume memory and cause spikes in
                # disk I/O.  Smaller is easier on disk and memory but less random.  It's
                # not a huge deal though, as samples are anyway randomized right at the start.
                # (the point of this is to get data in different minibatches on different iterations,
                # since in the preconditioning method, 2 samples in the same minibatch can
                # affect each others' gradients.

add_layers_period=2 # by default, add new layers every 2 iterations.
stage=-6
exit_stage=-100 # you can set this to terminate the training early.  Exits before running this stage

# count space-separated fields in splice_indexes to get num-hidden-layers.
splice_indexes="-2,-1,0,1,2 0 0"
# Format : layer<hidden_layer>/<frame_indices>....layer<hidden_layer>/<frame_indices> "
# note: hidden layers which are composed of one or more components,
# so hidden layer indexing is different from component count

# LSTM parameters
num_lstm_layers=1
cell_dim=1024  # dimension of the LSTM cell
hidden_dim=1024  # the dimension of the fully connected hidden layer outputs
recurrent_projection_dim=256
non_recurrent_projection_dim=256
norm_based_clipping=true  # if true norm_based_clipping is used.
                          # In norm-based clipping the activation Jacobian matrix
                          # for the recurrent connections in the network is clipped
                          # to ensure that the individual row-norm (l2) does not increase
                          # beyond the clipping_threshold.
                          # If false, element-wise clipping is used.
clipping_threshold=30     # if norm_based_clipping is true this would be the maximum value of the row l2-norm,
                          # else this is the max-absolute value of each element in Jacobian.
chunk_width=20  # number of output labels in the sequence used to train an LSTM
                # Caution: if you double this you should halve --samples-per-iter.
chunk_left_context=40  # number of steps used in the estimation of LSTM state before prediction of the first label
chunk_right_context=0  # number of steps used in the estimation of LSTM state before prediction of the first label (usually used in bi-directional LSTM case)
label_delay=5  # the lstm output is used to predict the label with the specified delay
lstm_delay=" -1 "  # the delay to be used in the recurrence of lstms
                         # "-1 -2 -3" means the a three layer stacked LSTM would use recurrence connections with
                         # delays -1, -2 and -3 at layer1 lstm, layer2 lstm and layer3 lstm respectively
                         # "[-1,1] [-2,2] [-3,3]" means a three layer stacked bi-directional LSTM would use recurrence
                         # connections with delay -1 for the forward, 1 for the backward at layer1,
                         # -2 for the forward, 2 for the backward at layer2, and so on at layer3
num_bptt_steps=    # this variable counts the number of time steps to back-propagate from the last label in the chunk
                   # it is usually same as chunk_width


# nnet3-train options
shrink=0.99  # this parameter would be used to scale the parameter matrices
shrink_threshold=0.15  # a value less than 0.25 that we compare the mean of
                       # 'deriv-avg' for sigmoid components with, and if it's
                       # less, we shrink.
max_param_change=2.0  # max param change per minibatch
num_chunk_per_minibatch=100  # number of sequences to be processed in parallel every mini-batch

samples_per_iter=20000 # this is really the number of egs in each archive.  Each eg has
                       # 'chunk_width' frames in it-- for chunk_width=20, this value (20k)
                       # is equivalent to the 400k number that we use as a default in
                       # regular DNN training.
momentum=0.5    # e.g. 0.5.  Note: we implemented it in such a way that
                # it doesn't increase the effective learning rate.
use_gpu=true    # if true, we run on GPU.
cleanup=true
egs_dir=
max_lda_jobs=10  # use no more than 10 jobs for the LDA accumulation.
lda_opts=
egs_opts=
transform_dir=     # If supplied, this dir used instead of alidir to find transforms.
cmvn_opts=  # will be passed to get_lda.sh and get_egs.sh, if supplied.
            # only relevant for "raw" features, not lda.
feat_type=raw  # or set to 'lda' to use LDA features.
align_cmd=              # The cmd that is passed to steps/nnet2/align.sh
align_use_gpu=          # Passed to use_gpu in steps/nnet2/align.sh [yes/no]
realign_times=          # List of times on which we realign.  Each time is
                        # floating point number strictly between 0 and 1, which
                        # will be multiplied by the num-iters to get an iteration
                        # number.
num_jobs_align=30       # Number of jobs for realignment

rand_prune=4.0 # speeds up LDA.

# End configuration section.

trap 'for pid in $(jobs -pr); do kill -KILL $pid; done' INT QUIT TERM

echo "$0: THIS SCRIPT IS DEPRECATED"
echo "$0 $@"  # Print the command line for logging

if [ -f path.sh ]; then . ./path.sh; fi
. parse_options.sh || exit 1;

if [ $# != 4 ]; then
  echo "Usage: $0 [opts] <data> <lang> <ali-dir> <exp-dir>"
  echo " e.g.: $0 data/train data/lang exp/tri3_ali exp/tri4_nnet"
  echo ""
  echo "Main options (for others, see top of script file)"
  echo "  --config <config-file>                           # config file containing options"
  echo "  --cmd (utils/run.pl|utils/queue.pl <queue opts>) # how to run jobs."
  echo "  --num-epochs <#epochs|10>                        # Number of epochs of training"
  echo "  --initial-effective-lrate <lrate|0.0003>         # effective learning rate at start of training."
  echo "  --final-effective-lrate <lrate|0.00003>          # effective learning rate at end of training."
  echo "                                                   # data, 0.00025 for large data"
  echo "  --momentum <momentum|0.5>                        # Momentum constant: note, this is "
  echo "                                                   # implemented in such a way that it doesn't"
  echo "                                                   # increase the effective learning rate."
  echo "  --num-jobs-initial <num-jobs|1>                  # Number of parallel jobs to use for neural net training, at the start."
  echo "  --num-jobs-final <num-jobs|8>                    # Number of parallel jobs to use for neural net training, at the end"
  echo "  --num-threads <num-threads|16>                   # Number of parallel threads per job, for CPU-based training (will affect"
  echo "                                                   # results as well as speed; may interact with batch size; if you increase"
  echo "                                                   # this, you may want to decrease the batch size."
  echo "  --parallel-opts <opts|\"--num-threads 16 --mem 1G\">      # extra options to pass to e.g. queue.pl for processes that"
  echo "                                                   # use multiple threads... note, you might have to reduce --mem"
  echo "                                                   # versus your defaults, because it gets multiplied by the --num-threads argument."
  echo "  --splice-indexes <string|\"-2,-1,0,1,2 0 0\"> "
  echo "                                                   # Frame indices used for each splice layer."
  echo "                                                   # Format : <frame_indices> .... <frame_indices> "
  echo "                                                   # the number of fields determines the number of LSTM and non-recurrent layers"
  echo "                                                   # also see the --num-lstm-layers option"
  echo "                                                   # (note: we splice processed, typically 40-dimensional frames"
  echo "  --lda-dim <dim|''>                               # Dimension to reduce spliced features to with LDA"
  echo "  --realign-epochs <list-of-epochs|''>             # A list of space-separated epoch indices the beginning of which"
  echo "                                                   # realignment is to be done"
  echo "  --align-cmd (utils/run.pl|utils/queue.pl <queue opts>) # passed to align.sh"
  echo "  --align-use-gpu (yes/no)                         # specify is gpu is to be used for realignment"
  echo "  --num-jobs-align <#njobs|30>                     # Number of jobs to perform realignment"
  echo "  --stage <stage|-4>                               # Used to run a partially-completed training process from somewhere in"
  echo "                                                   # the middle."

  echo " ################### LSTM options ###################### "
  echo "  --num-lstm-layers <int|3>                        # number of LSTM layers"
  echo "  --cell-dim   <int|1024>                          # dimension of the LSTM cell"
  echo "  --hidden-dim      <int|1024>                     # the dimension of the fully connected hidden layer outputs"
  echo "  --recurrent-projection-dim  <int|256>            # the output dimension of the recurrent-projection-matrix"
  echo "  --non-recurrent-projection-dim  <int|256>        # the output dimension of the non-recurrent-projection-matrix"
  echo "  --chunk-left-context <int|40>                    # number of time-steps used in the estimation of the first LSTM state"
  echo "  --chunk-width <int|20>                           # number of output labels in the sequence used to train an LSTM"
  echo "                                                   # Caution: if you double this you should halve --samples-per-iter."
  echo "  --norm-based-clipping <bool|true>                # if true norm_based_clipping is used."
  echo "                                                   # In norm-based clipping the activation Jacobian matrix"
  echo "                                                   # for the recurrent connections in the network is clipped"
  echo "                                                   # to ensure that the individual row-norm (l2) does not increase"
  echo "                                                   # beyond the clipping_threshold."
  echo "                                                   # If false, element-wise clipping is used."
  echo "  --num-bptt-steps <int|>                          # this variable counts the number of time steps to back-propagate from the last label in the chunk"
  echo "                                                   # it defaults to chunk_width"
  echo "  --label-delay <int|5>                            # the lstm output is used to predict the label with the specified delay"

  echo "  --lstm-delay <str|\" -1 -2 -3 \">                # the delay to be used in the recurrence of lstms"
  echo "                                                   # \"-1 -2 -3\" means the a three layer stacked LSTM would use recurrence connections with "
  echo "                                                   # delays -1, -2 and -3 at layer1 lstm, layer2 lstm and layer3 lstm respectively"
  echo "  --clipping-threshold <int|30>                    # if norm_based_clipping is true this would be the maximum value of the row l2-norm,"
  echo "                                                   # else this is the max-absolute value of each element in Jacobian."

  echo " ################### LSTM specific training options ###################### "
  echo "  --num-chunks-per-minibatch <minibatch-size|100>  # Number of sequences to be processed in parallel in a minibatch"
  echo "  --samples-per-iter <#samples|20000>              # Number of egs in each archive of data.  This times --chunk-width is"
  echo "                                                   # the number of frames processed per iteration"
  echo "  --shrink <shrink|0.99>                           # if non-zero this parameter will be used to scale the parameter matrices"
  echo "  --shrink-threshold <threshold|0.15>              # a threshold (should be between 0.0 and 0.25) that controls when to"
  echo "                                                   # do parameter shrinking."
  echo " for more options see the script"
  exit 1;
fi

data=$1
lang=$2
alidir=$3
dir=$4

if [ ! -z "$realign_times" ]; then
  [ -z "$align_cmd" ] && echo "$0: realign_times specified but align_cmd not specified" && exit 1
  [ -z "$align_use_gpu" ] && echo "$0: realign_times specified but align_use_gpu not specified" && exit 1
fi

# Check some files.
for f in $data/feats.scp $lang/L.fst $alidir/ali.1.gz $alidir/final.mdl $alidir/tree; do
  [ ! -f $f ] && echo "$0: no such file $f" && exit 1;
done


# Set some variables.
num_leaves=`tree-info $alidir/tree 2>/dev/null | grep num-pdfs | awk '{print $2}'` || exit 1
[ -z $num_leaves ] && echo "\$num_leaves is unset" && exit 1
[ "$num_leaves" -eq "0" ] && echo "\$num_leaves is 0" && exit 1

nj=`cat $alidir/num_jobs` || exit 1;  # number of jobs in alignment dir...
# in this dir we'll have just one job.
sdata=$data/split$nj
utils/split_data.sh $data $nj

mkdir -p $dir/log
echo $nj > $dir/num_jobs
cp $alidir/tree $dir

utils/lang/check_phones_compatible.sh $lang/phones.txt $alidir/phones.txt || exit 1;
cp $lang/phones.txt $dir || exit 1;
# First work out the feature and iVector dimension, needed for tdnn config creation.
case $feat_type in
  raw) feat_dim=$(feat-to-dim --print-args=false scp:$data/feats.scp -) || \
      { echo "$0: Error getting feature dim"; exit 1; }
    ;;
  lda)  [ ! -f $alidir/final.mat ] && echo "$0: With --feat-type lda option, expect $alidir/final.mat to exist."
   # get num-rows in lda matrix, which is the lda feature dim.
   feat_dim=$(matrix-dim --print-args=false $alidir/final.mat | cut -f 1)
    ;;
  *)
   echo "$0: Bad --feat-type '$feat_type';"; exit 1;
esac
if [ -z "$online_ivector_dir" ]; then
  ivector_dim=0
else
  ivector_dim=$(feat-to-dim scp:$online_ivector_dir/ivector_online.scp -) || exit 1;
fi


if [ $stage -le -5 ]; then
  echo "$0: creating neural net configs";

  # create the config files for nnet initialization
  # note an additional space is added to splice_indexes to
  # avoid issues with the python ArgParser which can have
  # issues with negative arguments (due to minus sign)
  config_extra_opts=()
  [ ! -z "$lstm_delay" ] && config_extra_opts+=(--lstm-delay "$lstm_delay")

  steps/nnet3/lstm/make_configs.py  "${config_extra_opts[@]}" \
    --splice-indexes "$splice_indexes " \
    --num-lstm-layers $num_lstm_layers \
    --feat-dim $feat_dim \
    --ivector-dim $ivector_dim \
    --cell-dim $cell_dim \
    --hidden-dim $hidden_dim \
    --recurrent-projection-dim $recurrent_projection_dim \
    --non-recurrent-projection-dim $non_recurrent_projection_dim \
    --norm-based-clipping $norm_based_clipping \
    --clipping-threshold $clipping_threshold \
    --num-targets $num_leaves \
    --label-delay $label_delay \
   $dir/configs || exit 1;
  # Initialize as "raw" nnet, prior to training the LDA-like preconditioning
  # matrix.  This first config just does any initial splicing that we do;
  # we do this as it's a convenient way to get the stats for the 'lda-like'
  # transform.
  $cmd $dir/log/nnet_init.log \
    nnet3-init --srand=-2 $dir/configs/init.config $dir/init.raw || exit 1;
fi
# sourcing the "vars" below sets
# model_left_context=(something)
# model_right_context=(something)
# num_hidden_layers=(something)
. $dir/configs/vars || exit 1;
left_context=$((chunk_left_context + model_left_context))
right_context=$((chunk_right_context + model_right_context))
context_opts="--left-context=$left_context --right-context=$right_context"

! [ "$num_hidden_layers" -gt 0 ] && echo \
 "$0: Expected num_hidden_layers to be defined" && exit 1;

[ -z "$transform_dir" ] && transform_dir=$alidir

if [ $stage -le -4 ] && [ -z "$egs_dir" ]; then
  extra_opts=()
  [ ! -z "$cmvn_opts" ] && extra_opts+=(--cmvn-opts "$cmvn_opts")
  [ ! -z "$feat_type" ] && extra_opts+=(--feat-type $feat_type)
  [ ! -z "$online_ivector_dir" ] && extra_opts+=(--online-ivector-dir $online_ivector_dir)
  extra_opts+=(--transform-dir $transform_dir)
  extra_opts+=(--left-context $left_context)
  extra_opts+=(--right-context $right_context)
fi
