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
function usage() {
    echo "---------------------------------------------------------------" 
    echo "----------------------- Synopsis/Usage ------------------------"
    echo "---------------------------------------------------------------" 
    echo " $0: <PROCESS_MODE> <EXECUTION_MODE> <MPI_CMD_LIST> \"<CORES_LIST>\" "
    echo ""
    echo " example: "
    echo "     $0 0 1 ./bin/xhpcg \"40\" "
    echo "     $0 0 1 ./bin/xhpcg \"400\" "
    echo "     $0 0 1 ./bin/xhpcg \"8000\" "
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
    echo "      \"./bin/xhpcg ./bin1/*.sh ./bin2/another_exe ./bin3/more_exe\" "
    echo "      default: \"$(pwd)/bin/xhpcg \" "
    echo " <CORES_LIST>:"
    echo "      Core numbers list - need double quote (\"...\") the entire list of cores"
    echo "      e.g."
    echo "      \"120 240 520 720 1000 1240 1520 1760 2000 2400\""
    echo "      default: \"40 \" "
    echo ""
}

###############################################
#### ---- ERROR DEFINITIONS (Don't Change) ----
###############################################
ERROR_WAIT_FOR_JOB_COMPLETE_MISSING_ARGS=1

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
GENERATE_PBS_ONLY=0
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
echo "=======>  EXECUTION LIST: Default for HPCG-3.0: ${CURR_DIR}/bin/xhpcg "
getConfigValue "MPI_CMD_LIST"
MPI_CMD_LIST=$configValue
if [[ $MPI_CMD_LIST =~ ^\/* ]]; then
    MPI_CMD_LIST=${3:-${MPI_CMD_LIST}}
else
    MPI_CMD_LIST=${3:-${CURR_DIR}/${MPI_CMD_LIST}}
fi


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
#CORES_LIST="2000 2200 2400 2600 2800 3000 3200 3400 3600 3800 4000"
#CORES_LIST="1040"
#CORES_LIST="1240 1520 1760 2520 3200 3600 4000"
####CORES_LIST="2520"
#CORES_LIST="3200"
#CORES_LIST="4000"
if [ $# -gt 3 ]; then
    shift 3
    CORES_LIST="${*}"
    echo "=======> CORES LIST: ${CORES_LIST} cores is provided! ............................"
else
    echo "=======> Use auto_scripts.conf file input with default 40 cores as CORES_LIST "
    getConfigValue "CORES_LIST"
    CORES_LIST="$configValue"
fi

echo "=======>  CORES LIST: ${CORES_LIST} cores is provided! ............................"

###############################################
###############################################
#### ---- CHANGE these below ----
###############################################
###############################################

###############################################
#### ---- Check EXE Path List existing:
###############################################
EXPANDED_PATH_LIST=""
#
function checkExePathListDirectory() {
    exePathList="`find $1`"
    if [ $? -gt 0 ] || [ "$exePathList" == "" ]  ; then
        echo "**** ERROR: Can't find some of EXE Binary files in the path list: ${1} ! Abort now!"
        exit ${ERROR_CAN_NOT_EXE_BINANRY} 
    fi
    for exePath in $exePathList; do
        if [ -d $exePath ]; then
            # it is an existing directory
            echo "--> $exePath is a directory"
            continue
        else
            # it is an existing file
            #if [ "$(dirname $exeExpPath)" == "." ]; then
            #    exeDir=${CURR_DIR}
            #else
            #    exeDir=$(dirname $exePath)
            #fi
            if [ -s ${exePath} ]; then
                echo "----- FOUND: EXE Binary file: ${exePath}"
                echo "-----   Full EXE :file path $(readlink -f ${exePath})"
                #EXPANDED_PATH_LIST="${EXPANDED_PATH_LIST} $(readlink -f ${exePath})"
                EXPANDED_PATH_LIST="${EXPANDED_PATH_LIST} ${exePath}"
            else
                echo "***** ERROR: Can't find EXE Binary file: ${exePath} ! Abort now!"
                exit ${ERROR_CAN_NOT_EXE_BINANRY} 
            fi
        fi
    done
}

#### ---- Executable binary files list: separated by blank space for multiple MPI_CMD items ----

checkExePathListDirectory "$MPI_CMD_LIST"
echo "=========> Fully Expanded EXE PATH LIST: "
EXE_PATH_LIST="${EXPANDED_PATH_LIST}"

echo "EXE_PATH_LIST=$EXE_PATH_LIST"

#############################
#### ---- TIME Spacer ---- 
#############################
#### ---- blank or zero means no time spacer amount (seconds) used ----
TIME_SPACER_DEFAULT=40
#TIME_SPACER_DEFAULT=90

#TIME_SPACER_DEFAULT=60
#### ---- Skip EXE files List: separated by blank space for multiple MPI_CMD items ----
#SKIP_MPI_CMD_LIST="osu_iallgather"
SKIP_MPI_CMD_LIST=""

############################################
############################################
#### ---- !! Don't change from here !!  ----
############################################
############################################

##################################
#### ---- Preapre directory:  ----
#### e.g. 
####    all-out: output directory
####    all-qsub: qusb JOB shell
##################################
#
function prepareDirectory() {
    tmp_DIR=$1 
    if [ -e ${tmp_DIR} ]; then
        backup_date=`date '+%Y_%m_%d_%H_%M'`
        mv ${tmp_DIR} ${tmp_DIR}_${backup_date}
        rm -rf ${tmp_DIR}/*
    else
        mkdir -p ${tmp_DIR}
    fi
}

#### ---- Time spacer configuration ----
#### ---- SPACER_PROGRESSIVE_RATE=20%
TIME_SPACER_DEFAULT=${TIME_SPACER_DEFAULT:-5}

TIME_SPACER_PROGRESS_RATE=0.2

TIME_SPACER=$TIME_SPACER_DEFAULT

TIME_SPACER_DELTA=$(echo "$TIME_SPACER_DEFAULT * $TIME_SPACER_PROGRESS_RATE" | bc)
TIME_SPACER_DELTA=${TIME_SPACER_DELTA%.*}
TIME_SPACER_DELTA=${TIME_SPACER_DELTA:-0}

#### ---- Change TIME_SPACER to zero(0) if no execution requested ----
if [ "${EXECUTION_MODE}" == "${GENERATE_PBS_ONLY}" ]; then
    TIME_SPACER_DEFAULT=0
    TIME_SPACER=0
fi

##################################
#### ---- Check Skip EXE List ----
##################################
SKIP_EXE_FLAG=0
#
function skipExe() {
    SKIP_EXE_FLAG=0
    for str in ${SKIP_MPI_CMD_LIST}; do
        if [[ "$1" = *"$str"* ]]; then
            SKIP_EXE_FLAG=1
            break
        else
            continue
        fi
    done
}

#####################################
#### ---- Check qsub compeletion ----
#####################################
IS_JOB_COMPLETED=0
#
function checkJobComplete() {
    JOB_ID=$1
    #### ---- check showq -c to see JOB_ID is compelted or not ----
    JOB_FOUND="`showq -c | grep ${JOB_ID}`" 
    if [ "$JOB_FOUND" != "" ]; then
        IS_JOB_COMPLETED=1
    else
        IS_JOB_COMPLETED=0
    fi
}

#####################################
#### ---- Wait qsub compeletion ----
#####################################
#
function waitForJobCompletion() {
    if [ "$1" == "" ]; then
        echo "**** ERROR: input arg JOB_ID empty! ****"
        exit ${ERROR_WAIT_FOR_JOB_COMPLETE_MISSING_ARGS}
    fi
    JOB_ID=$1
    WAIT_SECONDS=60
    WAIT_SECONDS_MULTIPLER=800
    WAIT_LIMIT=$(echo "$TIME_SPACER * $WAIT_SECONDS_MULTIPLER" | bc)
    WAIT_TOTAL_SECONDS=0
    IS_JOB_COMPLETED=0
    while [ ${IS_JOB_COMPLETED} -lt 1 ]; do
        checkJobComplete ${JOB_ID}
        if [ ${IS_JOB_COMPLETED} -gt 0 ]; then
            echo "+++++++++++++++++++++++++++++++++++++"
            echo "---- Job ID: ${JOB_ID} is completed!! "
            echo "+++++++++++++++++++++++++++++++++++++"
            break;
        else
            if [ $WAIT_TOTAL_SECONDS -gt  $WAIT_LIMIT ]; then
                echo "+++++++++++++++++++++++++++++++++++++"
                echo "**** Total wait time limit exceeded! "
                echo "---- Job ID: ${JOB_ID} !! "
                echo "+++++++++++++++++++++++++++++++++++++"
                exit ${ERROR_WAIT_FOR_JOB_COMPLETE_WAIT_LIMIT_EXCEEDED}
            else
                echo "---- Waiting for Job ID to compelte: ${JOB_ID} !! "
                sleep ${WAIT_SECONDS}
                WAIT_TOTAL_SECONDS=$(echo "$WAIT_SECONDS + $WAIT_TOTAL_SECONDS" | bc)
            fi
        fi
    done
}

#########################################################################################
#### ---- Move Some Specific Results files to all-out/out-<cores> directory together ----
#########################################################################################
#
function moveResultsToOutputDir() {
    sleep 15
    FILES_TO_MOVE_LIST="$1"
    TO_DIR="$2"
    for fileToMove in ${FILES_TO_MOVE_LIST}; do
        #mv bin/HPCG-Benchmark-3.0_*.yaml ${OUTPUT_DIR}
        #mv bin/hpcg_log_*.txt ${OUTPUT_DIR}
        if [ -e $fileToMove ]; then
            mv $fileToMove ${TO_DIR}
        else
            echo "***** ERROR: moveResultsToOutputDir(): Can't find source file to move: $fileToMove"
            exit ${ERROR_MOVE_RESULTS_CANNOT_FIND_FILES}
        fi
    done 
}
#######################################
#### ---- Execute EXE one-by-one ----
#######################################
echo "=======>  CORES LIST: ${CORES_LIST} will be used to generate MPI Runs ......................."

for TOTAL_CORES in ${CORES_LIST}; do

    #### ---- Directory for generated qsub files ----
    TARGET_DIR=${CURR_DIR}/all-qsub/qsub-${TOTAL_CORES}
    prepareDirectory ${TARGET_DIR}

    #### ---- Output Directory ----
    OUTPUT_DIR=${CURR_DIR}/all-out/out-${TOTAL_CORES}
    prepareDirectory ${OUTPUT_DIR}

    for MPI_CMD in ${EXE_PATH_LIST} ;do
        #### ---- Job ID file ----
        MPI_CMD_2_FILENAME=`echo $(basename ${MPI_CMD})|tr "/" "-"`

        #### ---- Skip some EXE binary files (when defined above) ----
        skipExe ${MPI_CMD}
        if [ $SKIP_EXE_FLAG -gt 0 ]; then
            #### ---- skip: osu_iallgather
            echo "skip MPI_CMD: $MPI_CMD ..."
            continue
        else
            echo "----> ${CURR_DIR}/qsub-runner-shell.sh ${TOTAL_CORES} ${MPI_CMD} ${TIME_SPACER} ${EXECUTION_MODE}"
            ${CURR_DIR}/qsub-runner-shell.sh $TOTAL_CORES ${MPI_CMD} ${TIME_SPACER} ${EXECUTION_MODE}

            ##############################
            #### ---- EXECUTION Mode ----
            ##############################
            if [ ${EXECUTION_MODE} -eq ${GENERATE_PBS_ONLY} ]; then
                continue
            fi

            ##############################
            #### ---- Processing Mode ----
            ##############################
            if [ "${PROCESS_MODE}" == "${PROCESS_SEQUENTIAL}" ]; then
                #### ---- One-by-One job submission model (per previous job completion) ----
                ## -- give some time for file I/O to creatre JOB_ID.job file --
                sleep 15
                JOB_ID_FILE="${OUTPUT_DIR}/${MPI_CMD_2_FILENAME}_${TOTAL_CORES}.job"
                if [ -s ${JOB_ID_FILE} ]; then
                    JOB_ID="`cat ${JOB_ID_FILE}`"
                    waitForJobCompletion ${JOB_ID}
                else
                    echo "*** JOB ID not found ! .... abort now"
                    exit ${ERROR_JOB_ID_FILE_NOT_FOUND}
                fi
    
                ########################################################################
                #### ---- Special Handling HPCG output files ----
                #### 1.) move YAML benchmark to directory: ../all-out/out-160/ directory
                #### 2.) move LOG text file to directory : ../all-out/out-160/ directory
                FILES_TO_MOVE="bin/HPCG-Benchmark-3.0_*.yaml bin/hpcg_log_*.txt"
                #### ---- wait for YAML files to close up ----
                moveResultsToOutputDir "${FILES_TO_MOVE}" ${OUTPUT_DIR}
                ########################################################################
            else
                #### ---- Wait some time before submitting next job ----
                if [ "$TIME_SPACER" != "" ] && [ $TIME_SPACER -gt 0 ]; then
                    TIME_SPACER=$(echo "$TIME_SPACER + $TIME_SPACER_DELTA" | bc)
                fi
            fi
        fi
    done
done
