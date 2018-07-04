#!/bin/bash 

#### ---- Current directory (DON'T CHANGE following two lines !!  ----
CURR_DIR=`cd $(dirname $0) && pwd`
echo $(pwd)

#### ---- Executable binary files list: separated by blank space for multiple MPI_CMD items ----
EXE_DIR=${CURR_DIR}

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

###############################################
#### ---- Synopsis ----
#### Note:
####     MPI_CMD and MPI_CMD_LIST are interchange.
###############################################
getConfigValue "MPI_CMD_DEFAULT"
MPI_CMD_DEFAULT=$configValue

echo "$0: ---->  MPI_CMD_DEFAULT=$MPI_CMD_DEFAULT"

#MPI_CMD_DEFAULT=./FFTW/ABTP/app/fftw/mpi/mpi-bench
#MPI_CMD_DEFAULT=./bin/xhpcg

function usage() {
    echo "---------------------------------------------------------------" 
    echo "----------------------- Synopsis/Usage ------------------------"
    echo "---------------------------------------------------------------" 
    echo " $0: <PROCESS_MODE> <EXECUTION_MODE> <MPI_CMD_LIST> \"<CORES_LIST>\" "
    echo ""
    echo " example: "
    echo "     $0 0 1 ${MPI_CMD_DEFAULT} \"40\" "
    echo "     $0 0 1 ${MPI_CMD_DEFAULT} \"400\" "
    echo "     $0 0 1 ${MPI_CMD_DEFAULT} \"8000\" "
    echo "     $0 0 1 ${MPI_CMD_DEFAULT} \"8000\" "
    echo ""
    echo " <PROCESS_MODE>:"
    echo "      0: PROCESS_SEQUENTIAL"
    echo "      1: PROCESS_MULTIPLE"
    echo "      default: 0 (PROCESS_SEQUENTIAL)"
    echo " <EXECUTION_MODE>:"
    echo "      0: GENERATE_PBS_ONLY"
    echo "      1: GENERATE_PBS_AND_EXECUTE"
    echo "      default: 0 (GENERATE_PBS_ONLY)"
    echo " <MPI_CMD_LIST>:"
    echo "      MPI EXE Binary file path"
    echo "      EXE binary paths list - need double quote (\"...\") the entire list of EXE paths "
    echo "      e.g."
    echo "      \"${MPI_CMD_DEFAULT} ./bin1/*.sh ./bin2/another_exe ./bin3/more_exe\" "
    echo "      default: \"$(pwd)/bin/xhpcg \" "
    echo " <CORES_LIST>:"
    echo "      Core numbers list - need double quote (\"...\") the entire list of cores"
    echo "      e.g."
    echo "      \"120 240 520 720 1000 1240 1520 1760 2000 2400\""
    echo "      default: \"40 \" "
    echo ""
}

if [ $# -lt 4 ]; then
    usage $*
    exit ${ERROR_WAIT_FOR_JOB_COMPLETE_MISSING_ARGS}
fi

#############################
#### ---- PROCESS MODE:  ----
#############################
PROCESS_SEQUENTIAL="SEQUENTIAL"
PROCESS_MULTIPLE="MULTIPLE"

#### ---- Default Processing Mode (Sequential) ----
PROCESS_MODE=${1:-$PROCESS_SEQUENTIAL}

#############################
#### ---- EXECUTION MODE ---- 
#############################
GENERATE_PBSONLY=0
GENERATE_PBS_AND_EXECUTE=1
#### (default: 1: GENERATE_PBS_AND_EXECUT)
#EXECUTION_MODE=${GENERATE_PBS_ONLY}
echo "=======>  EXECUTION MODE: Default=0: GENERATE_PBS_ONLY"
EXECUTION_MODE=${2:-$GENERATE_PBS_ONLY}

#############################
#### ---- EXECUTION LIST ---- 
#############################
#MPI_CMD_LIST="${CURR_DIR}/collective/*"
#MPI_CMD_LIST="${CURR_DIR}/bin/xhpcg"
#MPI_CMD_LIST=${3:-${CURR_DIR}/bin/xhpcg}
MPI_CMD_LIST=${3}
echo "=======>  EXECUTION LIST: Command line args for MPI_CMD_LIST: ${MPI_CMD_LIST}"

getConfigValue "MPI_CMD_LIST"
MPI_CMD_LIST=$configValue

if [[ $MPI_CMD_LIST =~ ^\/* ]]; then
    echo "No conversion to full path needed, MPI_CMD_LIST=$MPI_CMD_LIST"
else
    MPI_CMD_LIST=${CURR_DIR}/${MPI_CMD_LIST}
fi
echo "$0: ----> MPI_CMD_LIST (after converting to full path) =$MPI_CMD_LIST"

#############################
#### ---- CORES LIST ---- 
#############################
#### ---- Note: S30 scheduler need FULL node's cores application when using more than one node! ---
#CORES_LIST="4520 5040 6000 6520 7000 7520 8000"
#CORES_LIST="16 32 80"
#CORES_LIST="120 240 520 720 1000 1240 1520 1760 2000 2400"
#CORES_LIST="16 32 80 120 240 520 720 1000 1240 1520 1760 2000 2400 2800 3200 3600 4000"
#CORES_LIST="400 440 480 520 600 720 840 1000 1240 1520 1720"
#CORES_LIST="2000"

if [ $# -gt 3 ]; then
    shift 3
    CORES_LIST="${*}"
    echo "=======> CORES LIST: ${CORES_LIST} cores is provided! ............................"
else
    echo "=======> Use auto_scripts.conf file input with default 40 cores as CORES_LIST "
    getConfigValue "CORES_LIST"
    CORES_LIST="$configValue"
fi

#############################
#### ---- MAIN ---- 
#############################
mydate=`date '+%Y_%m_%d_%H_%M'`
#"./run-EXE-all-cores.sh 0 1 ./bin/xhpcg \"7200\""
#nohup ./run-EXE-all-cores.sh 2>&1 > nohup.out_$mydate &

LOG_FILE="nohup.out_$mydate"
#nohup ./run-EXE-all-cores.sh ${PROCESS_MODE} ${EXECUTION_MODE} ${MPI_CMD_LIST} ${CORES_LIST} 2>&1 > nohup.out_$mydate &
nohup ./run-EXE-all-cores.sh ${PROCESS_MODE} ${EXECUTION_MODE} ${MPI_CMD_LIST} ${CORES_LIST} 2>&1 > ${LOG_FILE} &

echo "======> Please check log file using: tail -f ${LOG_FILE}"
