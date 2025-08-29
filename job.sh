#!/bin/bash
#SBATCH --job-name=cycleGAN           # Job name
#SBATCH --nodes=2                      # Number of nodes
#SBATCH --ntasks-per-node=1            # Number of tasks (one per GPU per node)
#SBATCH --gres=gpu:2                   # Number of GPUs on each node
#SBATCH --cpus-per-task=10             # Number of CPU cores per task
#SBATCH --partition=gpu                # GPU partition
#SBATCH --output=logs_%j.out           # Output log file
#SBATCH --error=logs_%j.err            # Error log file
#SBATCH --time=00:20:00                # Time limit

# Define variables for distributed setup
nodes_array=($(scontrol show hostnames $SLURM_JOB_NODELIST))  # Get all node hostnames
head_node=${nodes_array[0]}  # The first node is the head node
head_node_ip=$(srun --nodes=1 --ntasks=1 -w "$head_node" hostname --ip-address)  # Get the IP of the head node

# Log node information for debugging
echo "===================================="
echo "SLURM Job Information"
echo "===================================="
echo "Job Name: $SLURM_JOB_NAME"
echo "Number of Nodes: $SLURM_NNODES"
echo "Number of GPUs per Node: $SLURM_GPUS_ON_NODE"
echo "Nodes Array: ${nodes_array[@]}"  # Log all the nodes in the array
echo "Head Node: $head_node"
echo "Head Node IP: $head_node_ip"
echo "===================================="

# Set environment variables for PyTorch distributed training
export MASTER_ADDR=$head_node_ip   # Set the master node IP address
export MASTER_PORT=29900           # Any available port
export WORLD_SIZE=$(($SLURM_NNODES * $SLURM_GPUS_ON_NODE))
export RANK=$SLURM_PROCID          # Rank of the current process
export LOGLEVEL=INFO               # Log level for debugging
export OMP_NUM_THREADS=${SLURM_CPUS_PER_TASK}
export NCCL_IB_DISABLE=0
export NCCL_DEBUG=INFO
export NCCL_NET_GDR_LEVEL=2

# Log environment variables for debugging
echo "===================================="
echo "Distributed Setup"
echo "===================================="
echo "MASTER_ADDR: $MASTER_ADDR"
echo "MASTER_PORT: $MASTER_PORT"
echo "WORLD_SIZE: $WORLD_SIZE"
echo "RANK: $RANK"
echo "NCCL_IB_DISABLE: $NCCL_IB_DISABLE"
echo "NCCL_DEBUG: $NCCL_DEBUG"

if [ "$NCCL_IB_DISABLE" == "1" ]; then
    echo "Connectio MODE : Using Ethernet (InfiniBand disabled)"
else
    echo "Connectio MODE : Using InfiniBand (NCCL_IB_ENABLE)"
fi

echo "===================================="

source /home/omjadhav/ankush/medical_project/pytorch-CycleGAN-and-pix2pix/.venv/bin/activate  # Activate the virtual environment

# Run the PyTorch script with torchrun
echo "===================================="
echo "Starting Distributed Training with torchrun"
echo "===================================="
srun torchrun \
    --nnodes=$SLURM_NNODES \
    --nproc-per-node=2 \
    --rdzv-id=10 \
    --rdzv-backend=c10d \
    --rdzv-endpoint=$MASTER_ADDR:$MASTER_PORT \
    train.py \
    --dataroot datasets/EYE \
    --name retinasim \
    --model cycle_gan \
    --batch_size 32 \
    --preprocess resize_and_crop \
    --load_size 286 \
    --crop_size 256 \
    --netG resnet_9blocks \
    --netD basic \
    --n_epochs 500 \
    --n_epochs_decay 500

# Log the completion of the job
echo "===================================="
echo "Training Completed"
echo "===================================="
