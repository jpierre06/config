#!/bin/bash

date >> /home/jupyter/execucao_script.log

if lspci -vnn | grep NVIDIA > /dev/null 2>&1; then
  # Nvidia card found, need to check if driver is up
  if ! nvidia-smi > /dev/null 2>&1; then
    echo "Installing driver"
    /opt/deeplearning/install-driver.sh
  fi
fi

/opt/conda/bin/conda init

echo "/opt/conda/etc/profile.d/conda.sh">> ~/.bashrc
yes | /opt/conda/bin/conda create --name environment python=3.7

/opt/conda/bin/conda activate environment
/opt/conda/bin/conda install -c anaconda xlrd
/opt/conda/bin/conda install -c anaconda openpyxl
/opt/conda/bin/conda install -c conda-forge pandas-gbq


pip install -U papermill>=2.2.2
#pip install pandasql
pip install curl
sudo pip3 install openpyxl==2.6.4
python -m pip install xlrd==1.2.0

readonly INPUT_NOTEBOOK_GCS_FILE=$(curl http://metadata.google.internal/computeMetadata/v1/instance/attributes/input_notebook -H "Metadata-Flavor: Google")
readonly OUTPUT_NOTEBOOK_GCS_FOLDER=$(curl http://metadata.google.internal/computeMetadata/v1/instance/attributes/output_notebook -H "Metadata-Flavor: Google")
readonly PARAMETERS_GCS_FILE=$(curl --fail http://metadata.google.internal/computeMetadata/v1/instance/attributes/parameters_file -H "Metadata-Flavor: Google")

readonly TEMPORARY_NOTEBOOK_FOLDER="/tmp/notebook"
mkdir "${TEMPORARY_NOTEBOOK_FOLDER}"

readonly OUTPUT_NOTEBOOK_NAME=$(basename ${INPUT_NOTEBOOK_GCS_FILE})
readonly OUTPUT_NOTEBOOK_CLEAN_NAME="${OUTPUT_NOTEBOOK_NAME%.ipynb}-clean"
readonly TEMPORARY_NOTEBOOK_PATH="${OUTPUT_NOTEBOOK_GCS_FOLDER}/${OUTPUT_NOTEBOOK_NAME}"
# For backward compitability.
readonly LEGACY_NOTEBOOK_PATH="${TEMPORARY_NOTEBOOK_FOLDER}/notebook.ipynb"

PAPERMILL_EXIT_CODE=0
if [[ -z "${PARAMETERS_GCS_FILE}" ]]; then
	
	echo "#################### Arquivo notebook_executor_start.sh - Inicio CONDICIONAL if [[ -z \"${PARAMETERS_GCS_FILE}\" ]]; then #################### "

  echo "No input parameters present"
  /opt/conda/bin/papermill	 ${INPUT_NOTEBOOK_GCS_FILE} ${TEMPORARY_NOTEBOOK_PATH} --log-output || PAPERMILL_EXIT_CODE=1
  PAPERMILL_RESULTS=$?
  echo "#################### Arquivo notebook_executor_start.sh - imprimindo VARIAVEL PAPERMILL_RESULTS: ${PAPERMILL_RESULTS} #################### "
else
	echo "#################### Arquivo notebook_executor_start.sh - Inicio CONDICIONAL if else [[ -z \"${PARAMETERS_GCS_FILE}\" ]]; then #################### "

  echo "input parameters present"
  echo "GCS file with parameters: ${PARAMETERS_GCS_FILE}"
  gsutil cp "${PARAMETERS_GCS_FILE}" params.yaml
  papermill "${INPUT_NOTEBOOK_GCS_FILE}" "${TEMPORARY_NOTEBOOK_PATH}" -f params.yaml --log-output || PAPERMILL_EXIT_CODE=1
  PAPERMILL_RESULTS=$?
fi

conda deactivate

if [[ "${PAPERMILL_EXIT_CODE}" -ne 0 ]]; then

  echo "Unable to execute notebook. Exit code: ${PAPERMILL_EXIT_CODE}"
  file="${TEMPORARY_NOTEBOOK_FOLDER}/FAILED.txt" 
  echo "#################### Arquivo notebook_executor_start.sh - imprimindo VARIAVEL file: ${file} #################### "
  
  echo ${PAPERMILL_RESULTS} >${file}
  # For backward compitability.
  
  cp "${TEMPORARY_NOTEBOOK_PATH}" "${LEGACY_NOTEBOOK_PATH}"
  
  gsutil rsync -r "${TEMPORARY_NOTEBOOK_FOLDER}" "${OUTPUT_NOTEBOOK_GCS_FOLDER}"
fi

readonly INSTANCE_NAME=$(curl http://metadata.google.internal/computeMetadata/v1/instance/name -H "Metadata-Flavor: Google")

INSTANCE_ZONE="/"$(curl http://metadata.google.internal/computeMetadata/v1/instance/zone -H "Metadata-Flavor: Google")

INSTANCE_ZONE="${INSTANCE_ZONE##/*/}"

readonly INSTANCE_PROJECT_NAME=$(curl http://metadata.google.internal/computeMetadata/v1/project/project-id -H "Metadata-Flavor: Google")

date >> /home/jupyter/execucao_script.log

# gcloud compute instances stop "${INSTANCE_NAME}" --zone "${INSTANCE_ZONE}" --project "${INSTANCE_PROJECT_NAME}"
