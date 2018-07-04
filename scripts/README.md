# How to run the benchmark scripts

# Scripts Calling hierarchy
```
run-daemon-all.sh
    --> run-EXE-all-cores.sh 
        --> qsub-runner-shell.sh
```

# Files using "qsub-mpirun.template"
* __Don't change the template file__ unless you know what you are doing!
* The template file is used to generate "actual MPI run command" to run by the script below.
```
qsub-runner-shell.sh
```

# __Usage__
```
---------------------------------------------------------------
----------------------- Synopsis/Usage ------------------------
---------------------------------------------------------------
 ./run-daemon-all.sh: <PROCESS_MODE> <EXECUTION_MODE> <MPI_CMD_LIST> "<CORES_LIST>" 

 example: 
     ./run-daemon-all.sh 0 1 ../test/mpi-bench "40 80" 
     ./run-daemon-all.sh 0 1 ../test/mpi-bench "200 400" 
     ./run-daemon-all.sh 0 1 ../test/mpi-bench "2000 4000" 
     ./run-daemon-all.sh 0 1 ../test/mpi-bench "4000 8000" 

 <PROCESS_MODE>:
      0: PROCESS_SEQUENTIAL
      1: PROCESS_MULTIPLE
      default: 0 (PROCESS_SEQUENTIAL)
 <EXECUTION_MODE>:
      0: GENERATE_PBS_ONLY
      1: GENERATE_PBS_AND_EXECUTE
      default: 0 (GENERATE_PBS_ONLY)
 <MPI_CMD_LIST>:
      MPI EXE Binary file path
      EXE binary paths list - need double quote ("...") the entire list of EXE paths 
      e.g.
      "../test/mpi-bench ./bin1/*.sh ./bin2/another_exe ./bin3/more_exe" 
      default: "/mnt/ntfs/tmp/Micro-Benchmarks20180402141231/benchmark_scripts/bin/xhpcg " 
 <CORES_LIST>:
      Core numbers list - need double quote ("...") the entire list of cores
      e.g.
      "120 240 520 720 1000 1240 1520 1760 2000 2400"
      default: "40 " 

```
# Customization: Files useing "auto_script.config"
```
qsub-runner-shell.sh
run-daemon-all.sh
run-EXE-all-cores.sh
```
## Example: "auto_script.config"
```
############################################
#### (Change this per project customization!!)
############################################
#### ----- Long Walltime jobs to ignore ---- 
#### (to exclude for auto submit)
LONG_WALL_TIME_LIST="iallgatherv iscatterv osu_scatterv"
#### ----- MPI CMD Default ----- ####
MPI_CMD_DEFAULT=../test/mpi-bench
#### ----- MPI CMD List ----- ####
MPI_CMD_LIST=../test/mpi-bench

############################################
#### (Change this per cluster customization!!)
############################################
#### Default: 40 cores totally to use ####
CORE_PER_NODE=40
####  ----- Cluster Queue ----- ####
QUEUE=S30
####  ----- Core Allocation Mode ----- ####
FULL_NODE_CORES_ALLOCATION=1

############################################
#### (Change this per cluster customization!!)
#### (Only if necessary)
############################################
#### ----- Walltime Limits ---- ####
QSUB_WALLTIME_WEEK_LONG="walltime=144:00:00"
QSUB_WALLTIME_SUPER_LONG="walltime=72:00:00"
QSUB_WALLTIME_EXTREME_LONG="walltime=36:00:00"
QSUB_WALLTIME_EXTRA_LONG="walltime=12:00:00"
QSUB_WALLTIME_VERY_LONG="walltime=08:00:00"
QSUB_WALLTIME_LONG="walltime=06:00:00"
QSUB_WALLTIME_MEDIUM="walltime=04:00:00"
QSUB_WALLTIME_NORMAL="walltime=03:00:00"
QSUB_WALLTIME_SHORT="walltime=01:00:00"

#### ---- setup Extra large cores ----
CORE_BOUND_FOR_LONG_WALLTIME=3200

####################################
#### (NOT to change this !!)
####################################
#### ---- ERROR definitions     ----
ERROR_WAIT_FOR_JOB_COMPLETE_MISSING_ARGS=1
ERROR_TOTAL_CORES_NOT_DIVISIBLE_BY_256=91
ERROR_GET_CONFIG_VALUE_ARGUMENTS_MISSING=92
``` 
