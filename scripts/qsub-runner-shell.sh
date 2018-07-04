#!/bin/bash 

#### ---- Current directory (DON'T CHANGE following two lines !!  ----
CURR_DIR=`cd $(dirname $0) && pwd`
echo $(pwd)

####################################
#### ---- ERROR definitions     ----
####################################
ERROR_GET_CONFIG_VALUE_ARGUMENTS_MISSING=99
ERROR_TOTAL_CORES_NOT_DIVISIBLE_BY_256=${ERROR_TOTAL_CORES_NOT_DIVISIBLE_BY_256:-81}
ERROR_WAIT_FOR_JOB_COMPLETE_MISSING_ARGS=${ERROR_WAIT_FOR_JOB_COMPLETE_MISSING_ARGS:-91}

####################################
#### ---- Cluster specificatons ----
####################################
configValue=""
function getConfigValue() {
    key=`echo $1|sed 's/=//g'`
    default=${2}
    file=${3:-auto_scripts.config}
    if [ "$1" == "" ]; then
        echo "getConfigValue: **** ERROR: needs to arguments: <Key> [ <default_value> [ <Config_file> ] ]"
        exit ${ERROR_GET_CONFIG_VALUE_ARGUMENTS_MISSING}
    else
        #configValue=`cat $file|grep "^$key"|sed 's/ //g' |cut -d'=' -f2`
        keyValue=`cat ${file}|grep "^${key}"`
        key=${keyValue%%=*}
        value=${keyValue##*=}
        echo "Key/Value: $key=$value"
        configValue=${value:-$default}
    fi
}

function loadErrorSpecifications() {
    getConfigValue "ERROR_TOTAL_CORES_NOT_DIVISIBLE_BY_256"
    ERROR_TOTAL_CORES_NOT_DIVISIBLE_BY_256=$configValue

    getConfigValue "ERROR_GET_CONFIG_VALUE_ARGUMENTS_MISSING"
    ERROR_GET_CONFIG_VALUE_ARGUMENTS_MISSING=$configValue
}
loadErrorSpecifications

##############################################
#### ---- Synopsis ----
#### arg1: <MPI_CORES>, e.g., 1800
#### arg2: <MPI_CMD>, e.g. pt2pt/osu_multi_lat
####      (the relative CMD path of PWD)
####      (or, absolute CMD path OK too)
##############################################
function usage() {
    echo "-----------------------------" 
    echo "#### ---- Synopsis ----"
    echo "-----------------------------" 
    echo "#### Usage: <MPI_CORES> <MPI_CMD> [ <WAIT_EACH_JOB_SECOND> [ <EXECUTION_MODE> ] ]"
    echo "####"
    echo "#### <MPI_CORES>:"
    echo "####      Number of CORES to use"
    echo "#### <MPI_CMD>:"
    echo "####      MPI exe binary command file"
    echo "#### <WAIT_EACH_JOB_SECOND>:"
    echo "####      default: zero (0) : No waiting between job submission!"
    echo "#### <EXECUTION_MODE>:"
    echo "####      0: GENERATE_PBS_ONLY"
    echo "####      1: GENERATE_PBS_AND_EXECUTE"
    echo "####      default: 0 (GENERATE_PBS_ONLY)"
    echo "#### e.g."
    echo "####    200 pt2pt/osu_bw 1"
    echo "####    200 pt2pt/osu_bw 120 1"
    echo "####    200 pt2pt/osu_multi_lat 120"
    echo "####    200 collective/osu_reduce_scatter "
    echo ""
}

if [ $# -lt 2 ]; then
    usage
    exit 1
fi

#### ---- Job submission wait time (to avoid submit too fast too many ---
WAIT_SECOND=0
if [ $# -ge 3 ]; then
    WAIT_SECOND=${3:-120}

fi

#############################
#### ---- EXECUTION MODE ---- 
#############################
GENERATE_PBS_ONLY=0
GENERATE_PBS_AND_EXECUTE=1
EXECUTION_MODE=${4:-$GENERATE_PBS_ONLY}

#### Default: 40 cores totally to use ####
#CORE_PER_NODE=40
getConfigValue "CORE_PER_NODE" 
CORE_PER_NODE=$configValue

####  ----- Cluster Queue ----- ####
#QUEUE=S30
getConfigValue "QUEUE" 
QUEUE=$configValue

###########################################
#### ---- (Mostly, don't chagne below) ----
###########################################

###########################################
#### ---- Initi: MPI_CORES and MPI_CMD ----
###########################################
TOTAL_CORES=${1:-$CORE_PER_NODE}
MPI_CMD=${2}

###########################################
#### ---- Qsub walltime setup   ----
###########################################
#qsub -q S30 -l nodes=2:ppn=40:walltime=01:00:00 runLatencyJob.sh 80
QSUB_WALLTIME_VERY_LONG="walltime=08:00:00"
QSUB_WALLTIME_LONG="walltime=06:00:00"
QSUB_WALLTIME_MEDIUM="walltime=04:00:00"
QSUB_WALLTIME_SHORT="walltime=01:00:00"
QSUB_WALLTIME_NORMAL="walltime=03:00:00"
function getQsubWalltimeRanges() {
    getConfigValue "QSUB_WALLTIME_VERY_LONG=" "$QSUB_WALLTIME_VERY_LONG"
    MPI_CMD_DEFAULT=$configValue

    getConfigValue "QSUB_WALLTIME_LONG=" "$QSUB_WALLTIME_LONG"
    QSUB_WALLTIME_LONG=$configValue

    getConfigValue "QSUB_WALLTIME_MEDIUM=" "$QSUB_WALLTIME_MEDIUM"
    QSUB_WALLTIME_MEDIUM=$configValue

    getConfigValue "QSUB_WALLTIME_SHORT=" "$QSUB_WALLTIME_SHORT"
    QSUB_WALLTIME_SHORT=$configValue

    getConfigValue "QSUB_WALLTIME_NORMAL=" "$QSUB_WALLTIME_NORMAL"
    QSUB_WALLTIME_NORMAL=$configValue
}
QSUB_WALLTIME=$QSUB_WALLTIME_NORMAL

###########################################
#### ---- Check Long Walltime list: ----
###########################################
#LONG_WALL_TIME_LIST="iallgatherv iscatterv osu_scatterv"

getConfigValue "LONG_WALL_TIME_LIST"
LONG_WALL_TIME_LIST=$configValue

#
## arg1: item: to be matched
## arg2: Given a list containing items to match arg1
#
MATCH_ITEM_FLAG=0
function matchItemInList() {
    MATCH_ITEM_FLAG=0
    ITEM=$1
    MATCH_ITEM_LIST=$2
    for str in ${MATCH_ITEM_LIST}; do
        if [[ "$1" = *"$str"* ]]; then
            MATCH_ITEM_FLAG=1
            break
        else
            continue
        fi
    done
}

#### for special handling of WALLTIME when seeing collective/iallgatherv ####

#### ---- setup Extra large cores ----
#CORE_BOUND_FOR_LONG_WALLTIME=1600
getConfigValue "CORE_BOUND_FOR_LONG_WALLTIME"
CORE_BOUND_FOR_LONG_WALLTIME=$configValue
if [ ${TOTAL_CORES} -gt ${CORE_BOUND_FOR_LONG_WALLTIME} ]; then
    matchItemInList "${MPI_CMD}" "${LONG_WALL_TIME_LIST}"
    if [ ${MATCH_ITEM_FLAG} -gt 0 ]; then
        QSUB_WALLTIME=${QSUB_WALLTIME_VERY_LONG}
    else
        QSUB_WALLTIME=${QSUB_WALLTIME_NORMAL}
    fi
fi

#### ---- setup smaller cores ----
CORE_BOUND_FOR_SMALL_WALLTIME=400
if [ ${TOTAL_CORES} -lt ${CORE_BOUND_FOR_SMALL_WALLTIME} ]; then
    QSUB_WALLTIME=${QSUB_WALLTIME_SHORT}
fi

#########################################
####  ----- Qsub list setup    ----- ####
#########################################

#### ---- Whether to use special FULL-Node (use all cores) allocation in PBS ----
#### (Note: this is how Penguin S30 behaviors in only allocating full node's all cores)
####
getConfigValue "FULL_NODE_CORES_ALLOCATION"
FULL_NODE_CORES_ALLOCATION=$configValue

QSUB_LIST=""
function generateQsubListParams() {
    QSUB_NODES=$(( TOTAL_CORES / CORE_PER_NODE ))
    tmp_cores=$(( QSUB_NODES * CORE_PER_NODE ))
    QSUB_REMAIN_CORES=$(( TOTAL_CORES - tmp_cores ))
    if [ $QSUB_NODES -lt 1 ]; then
        QSUB_NODES=1
        CORE_PER_NODE=$QSUB_REMAIN_CORES
        QSUB_REMAIN_CORES=0
    fi
    if [ $QSUB_REMAIN_CORES -lt 1 ]; then
        #QSUB_LIST="nodes=${QSUB_NODES}:ppn=${CORE_PER_NODE}:${QSUB_WALLTIME}"
        QSUB_LIST="nodes=${QSUB_NODES}:ppn=${CORE_PER_NODE}"
    else
        if [ $FULL_NODE_CORES_ALLOCATION -gt 0 ]; then
            QSUB_LIST="nodes=$(($QSUB_NODES + 1 )):ppn=${CORE_PER_NODE}"
        else
            #QSUB_LIST="nodes=${QSUB_NODES}:ppn=${CORE_PER_NODE}+1:ppn=${QSUB_REMAIN_CORES}"
            QSUB_LIST="nodes=${QSUB_NODES}:ppn=${CORE_PER_NODE}+1:ppn=${QSUB_REMAIN_CORES}"
        fi
    fi

}
generateQsubListParams
echo "QSUB_LIST= $QSUB_LIST"

####################################
#### ----- FFTW Specifics ----- ####
####################################
getConfigValue "CHECK_CORES_IS_POWER_OF_16"
CHECK_CORES_IS_POWER_OF_16=$configValue
function checkCoresPower16() {
    if [ ${CHECK_CORES_IS_POWER_OF_16} -eq 1 ]; then
        cores=$1
        whole=$(( cores / 16 * 16 ))
        if [ $cores -ne $whole ]; then
            echo "**** ERROR: checkCoresPower16:  TOTAL_CORES used NOT divisible by 16! Abort now!"
            exit  ${ERROR_TOTAL_CORES_NOT_DIVISIBLE_BY_256}
        else
            echo "---- STATUS: checkCoresPower16: TOTAL_CORES used is divisible by 16! OK to continue!"
        fi
    else
        echo "---- INFO: CHECK_CORES_IS_POWER_OF_16: 0 ==> No checking for Core Allocation is power of 16!"
    fi
}

####################################
#### ----- Generate qsub  ----- ####
####################################

#### ---- Directory for generated qsub files ----
TARGET_DIR=${CURR_DIR}/all-qsub/qsub-${TOTAL_CORES}
mkdir -p ${TARGET_DIR}

#### ---- Output Directory ----
OUTPUT_DIR=${CURR_DIR}/all-out/out-${TOTAL_CORES}
mkdir -p ${OUTPUT_DIR}

#### ---- qsub mpirun template file: ----
TEMPLATE_DIR=${CURR_DIR}/.
QSUB_MPIRUN_TEMPLATE=${TEMPLATE_DIR}/qsub-mpirun.template

#### ---- Generated qsub file preparation: ----
MPI_CMD_2_FILENAME=`echo $(basename ${MPI_CMD})|tr "/" "-"`
QSUB_FILE_INSTANTIATED="${TARGET_DIR}/${MPI_CMD_2_FILENAME}_${TOTAL_CORES}.sub"

#### ---- Generate MPI_OPTIONS: ----
#FFTW will be used in TI-17 to transpose a 64-bit 3-D matrix of size 
#     p x p x (67239936/p) = p x p x [(1026)*(65536)/p]
#using p = 8192, 16384, 32768, and 65536 MPI processes with the commands
#mpirun -np 8192 ${ABTP_APPDIR}/mpi/mpi-bench -v -v 8192x8192x8208
#mpirun -np 16384 ${ABTP_APPDIR}/mpi/mpi-bench -v -v 16384x16384x4104
#mpirun -np 32768 ${ABTP_APPDIR}/mpi/mpi-bench -v -v 32768x32768x2052
#mpirun -np 65536 ${ABTP_APPDIR}/mpi/mpi-bench -v -v 65536x65536x1026
#### ---- Check TOTAL_CORES divisible by 16: ----
checkCoresPower16 ${TOTAL_CORES}
FFTW_3RD_DIM=$(( (1026)*(65536)/TOTAL_CORES ))
MPI_OPTIONS="-v -v ${TOTAL_CORES}x${TOTAL_CORES}x${FFTW_3RD_DIM}"

#### ---- Generate qsub file: ----
cp ${QSUB_MPIRUN_TEMPLATE} ${QSUB_FILE_INSTANTIATED}
sed -i 's#%%QSUB_LIST%%#'"${QSUB_LIST}"'#g' ${QSUB_FILE_INSTANTIATED}
sed -i 's#%%MPI_CMD%%#'"${MPI_CMD}"'#g' ${QSUB_FILE_INSTANTIATED}
sed -i 's#%%MPI_OPTIONS%%#'"${MPI_OPTIONS}"'#g' ${QSUB_FILE_INSTANTIATED}
sed -i 's#%%MPI_CMD_2_FILENAME%%#'"${MPI_CMD_2_FILENAME}"'#g' ${QSUB_FILE_INSTANTIATED}
sed -i 's#%%TOTAL_CORES%%#'"${TOTAL_CORES}"'#g' ${QSUB_FILE_INSTANTIATED}
sed -i 's#%%QSUB_WALLTIME%%#'"${QSUB_WALLTIME}"'#g' ${QSUB_FILE_INSTANTIATED}
sed -i 's#%%OUTPUT_DIR%%#'"${OUTPUT_DIR}"'#g' ${QSUB_FILE_INSTANTIATED}

#### ---- Job ID file ----
JOB_ID_FILE="${OUTPUT_DIR}/${MPI_CMD_2_FILENAME}_${TOTAL_CORES}.job"

##### ==============================
##### ----  Run qsub -----
##### ==============================

echo "----> Generated Job for qsub: ${QSUB_FILE_INSTANTIATED}"
if [ ${EXECUTION_MODE} -gt 0 ]; then
    #### ---- go to the directory of qsub job file located ----
    #cd $(dirname ${QSUB_FILE_INSTANTIATED})
    ulimit -c 0
    ulimit -a

    TBEGIN=`echo "print time();" | perl`
    time JOBID=`qsub ${QSUB_FILE_INSTANTIATED} 2>&1 | tee ${JOB_ID_FILE}`
    TEND=`echo "print time();" | perl`
    echo "----> JobId_qsub=$JOBID"
    #### ---- space time before next auto submit job ---
    if [ ${WAIT_SECOND} -gt 1 ]; then
        sleep ${WAIT_SECOND}
    fi
else
    echo "---> Generate qsub job script only (not submit for exeuction!)"
fi

