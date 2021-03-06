#!/bin/bash
#
# Script to send job to BIWI clusters using qsub.
# Usage: qsub run_on_host.sh model models.breast_cycle_gan_graph flags/cyclegan.json

# Adjust line '-l hostname=xxxxx' before running.
# The script also requires changing the paths of the CUDA and python environments
# and the code to the local equivalents of your machines.
# Author: Christian F. Baumgartner (c.f.baumgartner@gmail.com)

## SET THE FOLLOWING VARIABLES ACCORDING TO YOUR SYSTEM ##
#user="$USER"
user=oskopek
BASE_HOME=/scratch_net/biwidl100/$user
CUDA_HOME=$BASE_HOME/cuda/cuda-9.0
PROJECT_HOME=$BASE_HOME/mammography
BASE_HOME_J=/scratch_net/biwidl104/$USER
VIRTUAL_ENV_PATH=$BASE_HOME_J/mammography/venv

timestamp="$(date '+%Y_%m_%d-%H_%M_%S_%s')"
exp_name="${1:-BreastCycleGan-$timestamp}"
masks="${2:-True}"
icnr="${3:-False}"
upsample_method="${4:-conv2d_transpose}"
loss_identity_lambda="${5:-0.0}"
checkpoint_hook_steps="${6:-25000}"
spectral_norm="${7:-False}"

## SGE Variables:
#
## otherwise the default shell would be used
#$ -S /bin/bash
#
## <= 2h is short queue, <= 24h is middle queue, <= 120h is long queue
#$ -l h_rt=24:00:00

## the maximum memory usage of this job, (below 4G does not make much sense)
#$ -l h_vmem=50G  # Less RAM is required for evaluating than for training

# Host and gpu settings
#$ -l gpu
##$ -l hostname=biwirender08   ## <-------------- Comment in or out to force a specific machine

## stderr and stdout are merged together to stdout
#$ -j y
#
# logging directory. preferably on your scratch
#$ -o /scratch_net/biwidl100/$USER/logs/  ## <---------------- CHANGE TO MATCH YOUR SYSTEM
#
## send mail on job's end and abort
##$ -m a ## Mails are disabled

## LOCAL PATHS
# I think .bashrc is not executed on the remote host if you use qsub, so you need to set all the paths
# and environment variables before exectuting the python code.

# cuda paths
export PATH=$CUDA_HOME/bin:$PATH
export LD_LIBRARY_PATH=$CUDA_HOME/lib64:$CUDA_HOME/extras/CUPTI/lib64:$LD_LIBRARY_PATH

# for pyenv
export PATH="$HOME/.pyenv/bin:$PATH"
eval "$(pyenv init -)"
eval "$(pyenv virtualenv-init -)"

export SGE_GPU_ALL="$(ls -rt /tmp/lock-gpu*/info.txt | xargs grep -h  $(whoami) | awk '{print $2}' | paste -sd "," -)"
export SGE_GPU=$(echo $SGE_GPU_ALL |rev|cut -d, -f1|rev) # USE LAST GPU by request time.
# NOTE: Use $SGE_GPU_ALL for multi GPU jobs
echo "SGE gpu=$SGE_GPU_ALL available"
echo "SGE gpu=$SGE_GPU allocated in this use"
export CUDA_VISIBLE_DEVICES="$SGE_GPU"
echo "Running on gpu: $CUDA_VISIBLE_DEVICES"

# activate virtual environment
source $VIRTUAL_ENV_PATH/bin/activate

## EXECUTION OF PYTHON CODE:
echo "Hostname is: `hostname`"
echo "Run model:"
cd $PROJECT_HOME
base_path="/scratch_net/biwidl100/$user/transformed/small_all_256x204_final"
exec $VIRTUAL_ENV_PATH/bin/python -m models.breast_cycle_gan.train --height 256 --width 204 --image_x_file "$base_path"/healthy.train.tfrecord --image_y_file "$base_path"/cancer.train.tfrecord --include_masks="$masks" --train_log_dir="data_out/$exp_name" --use_icnr="$icnr" --upsample_method="$upsample_method" --loss_identity_lambda="$loss_identity_lambda" --checkpoint_hook_steps="$checkpoint_hook_steps" --use_spectral_norm="$spectral_norm"
