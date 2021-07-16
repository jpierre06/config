#!/bin/bash

echo "#################### Inicio arquivo notebook_executor_start.sh #################### "

echo "#################### Arquivo notebook_executor_start.sh - Inicio de configuração driver NVIDIA #################### "

if lspci -vnn | grep NVIDIA > /dev/null 2>&1; then
  # Nvidia card found, need to check if driver is up
  if ! nvidia-smi > /dev/null 2>&1; then
	echo "#################### Arquivo notebook_executor_start.sh - Inicio CONDICIONAL if ! nvidia-smi > /dev/null 2>&1; then #################### "
  
    echo "Installing driver"
    /opt/deeplearning/install-driver.sh
  fi
  echo "#################### Arquivo notebook_executor_start.sh - Fim CONDICIONAL if ! nvidia-smi > /dev/null 2>&1; then #################### "
fi

echo "#################### Arquivo notebook_executor_start.sh - Fim de configuração divrer NVIDIA #################### "


echo "#################### Arquivo notebook_executor_start.sh - Inicio conda init #################### "
/opt/conda/bin/conda init

echo "#################### Arquivo notebook_executor_start.sh - Ativação do environment python=3.7 #################### "
/opt/conda/bin/conda activate environment




readonly INPUT_NOTEBOOK_GCS_FILE=$(curl http://metadata.google.internal/computeMetadata/v1/instance/attributes/input_notebook -H "Metadata-Flavor: Google")
echo "#################### Arquivo notebook_executor_start.sh - imprimindo VARIAVEL INPUT_NOTEBOOK_GCS_FILE: ${INPUT_NOTEBOOK_GCS_FILE} #################### "

readonly OUTPUT_NOTEBOOK_GCS_FOLDER=$(curl http://metadata.google.internal/computeMetadata/v1/instance/attributes/output_notebook -H "Metadata-Flavor: Google")
echo "#################### Arquivo notebook_executor_start.sh - imprimindo VARIAVEL OUTPUT_NOTEBOOK_GCS_FOLDER: ${OUTPUT_NOTEBOOK_GCS_FOLDER} #################### "

readonly PARAMETERS_GCS_FILE=$(curl --fail http://metadata.google.internal/computeMetadata/v1/instance/attributes/parameters_file -H "Metadata-Flavor: Google")
echo "#################### Arquivo notebook_executor_start.sh - imprimindo VARIAVEL PARAMETERS_GCS_FILE: ${PARAMETERS_GCS_FILE} #################### "

readonly TEMPORARY_NOTEBOOK_FOLDER="/tmp/notebook"
echo "#################### Arquivo notebook_executor_start.sh - imprimindo VARIAVEL TEMPORARY_NOTEBOOK_FOLDER: ${TEMPORARY_NOTEBOOK_FOLDER} #################### "

mkdir "${TEMPORARY_NOTEBOOK_FOLDER}"

readonly OUTPUT_NOTEBOOK_NAME=$(basename ${INPUT_NOTEBOOK_GCS_FILE})
echo "#################### Arquivo notebook_executor_start.sh - imprimindo VARIAVEL OUTPUT_NOTEBOOK_NAME: ${OUTPUT_NOTEBOOK_NAME} #################### "

readonly OUTPUT_NOTEBOOK_CLEAN_NAME="${OUTPUT_NOTEBOOK_NAME%.ipynb}-clean"
echo "#################### Arquivo notebook_executor_start.sh - imprimindo VARIAVEL OUTPUT_NOTEBOOK_CLEAN_NAME: ${OUTPUT_NOTEBOOK_CLEAN_NAME} #################### "

readonly TEMPORARY_NOTEBOOK_PATH="${OUTPUT_NOTEBOOK_GCS_FOLDER}/${OUTPUT_NOTEBOOK_NAME}"
echo "#################### Arquivo notebook_executor_start.sh - imprimindo VARIAVEL TEMPORARY_NOTEBOOK_PATH: ${TEMPORARY_NOTEBOOK_PATH} #################### "

# For backward compitability.
readonly LEGACY_NOTEBOOK_PATH="${TEMPORARY_NOTEBOOK_FOLDER}/notebook.ipynb"
echo "#################### Arquivo notebook_executor_start.sh - imprimindo VARIAVEL LEGACY_NOTEBOOK_PATH: ${LEGACY_NOTEBOOK_PATH} #################### "

PAPERMILL_EXIT_CODE=0
if [[ -z "${PARAMETERS_GCS_FILE}" ]]; then
	
	echo "#################### Arquivo notebook_executor_start.sh - Inicio CONDICIONAL if [[ -z \"${PARAMETERS_GCS_FILE}\" ]]; then #################### "

  echo "No input parameters present"
  /opt/conda/bin/	 ${INPUT_NOTEBOOK_GCS_FILE} ${TEMPORARY_NOTEBOOK_PATH} --log-output || PAPERMILL_EXIT_CODE=1
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
echo "#################### Arquivo notebook_executor_start.sh - Fim CONDICIONAL if [[ -z \"${PARAMETERS_GCS_FILE}\" ]]; then #################### "

echo "#################### Arquivo notebook_executor_start.sh - Inicio COMANDO conda deactivate #################### "
conda deactivate
echo "#################### Arquivo notebook_executor_start.sh - Fim COMANDO conda deactivate #################### "

echo "Papermill exit code is: ${PAPERMILL_EXIT_CODE}"

if [[ "${PAPERMILL_EXIT_CODE}" -ne 0 ]]; then
	echo "#################### Arquivo notebook_executor_start.sh - Inicio CONDICIONAL if [[ \"${PAPERMILL_EXIT_CODE}\" -ne 0 ]]; then #################### "

  echo "Unable to execute notebook. Exit code: ${PAPERMILL_EXIT_CODE}"
  file="${TEMPORARY_NOTEBOOK_FOLDER}/FAILED.txt" 
  echo "#################### Arquivo notebook_executor_start.sh - imprimindo VARIAVEL file: ${file} #################### "
  
  echo ${PAPERMILL_RESULTS} >${file}
  # For backward compitability.
  
  echo "#################### Arquivo notebook_executor_start.sh - Inicio COMANDO  cp \"${TEMPORARY_NOTEBOOK_PATH}\" \"${LEGACY_NOTEBOOK_PATH}\" #################### "
  cp "${TEMPORARY_NOTEBOOK_PATH}" "${LEGACY_NOTEBOOK_PATH}"
  echo "#################### Arquivo notebook_executor_start.sh - Fim COMANDO  cp \"${TEMPORARY_NOTEBOOK_PATH}\" \"${LEGACY_NOTEBOOK_PATH}\" #################### "
  
  
  echo "#################### Arquivo notebook_executor_start.sh - Inicio COMANDO gsutil rsync -r \"${TEMPORARY_NOTEBOOK_FOLDER}\" \"${OUTPUT_NOTEBOOK_GCS_FOLDER}\" #################### "
  gsutil rsync -r "${TEMPORARY_NOTEBOOK_FOLDER}" "${OUTPUT_NOTEBOOK_GCS_FOLDER}"
  echo "#################### Arquivo notebook_executor_start.sh - Fim COMANDO gsutil rsync -r \"${TEMPORARY_NOTEBOOK_FOLDER}\" \"${OUTPUT_NOTEBOOK_GCS_FOLDER}\" #################### "
  
  
  echo "#################### Arquivo notebook_executor_start.sh - Fim CONDICIONAL if [[ \"${PAPERMILL_EXIT_CODE}\" -ne 0 ]]; then #################### "
fi

readonly INSTANCE_NAME=$(curl http://metadata.google.internal/computeMetadata/v1/instance/name -H "Metadata-Flavor: Google")
echo "#################### Arquivo notebook_executor_start.sh - imprimindo VARIAVEL INSTANCE_NAME: ${INSTANCE_NAME} #################### "

INSTANCE_ZONE="/"$(curl http://metadata.google.internal/computeMetadata/v1/instance/zone -H "Metadata-Flavor: Google")
echo "#################### Arquivo notebook_executor_start.sh - imprimindo VARIAVEL INSTANCE_ZONE: ${INSTANCE_ZONE} #################### "

INSTANCE_ZONE="${INSTANCE_ZONE##/*/}"
echo "#################### Arquivo notebook_executor_start.sh - imprimindo VARIAVEL INSTANCE_ZONE: ${INSTANCE_ZONE} #################### "

readonly INSTANCE_PROJECT_NAME=$(curl http://metadata.google.internal/computeMetadata/v1/project/project-id -H "Metadata-Flavor: Google")
echo "#################### Arquivo notebook_executor_start.sh - imprimindo VARIAVEL INSTANCE_PROJECT_NAME: ${INSTANCE_PROJECT_NAME} #################### "


echo "#################### Arquivo notebook_executor_start.sh - Inicio COMANDO gcloud compute instances stop #################### "
gcloud compute instances stop "${INSTANCE_NAME}" --zone "${INSTANCE_ZONE}" --project "${INSTANCE_PROJECT_NAME}"
echo "#################### Arquivo notebook_executor_start.sh - Fim COMANDO gcloud compute instances stop #################### "


echo "#################### Fim arquivo notebook_executor_start.sh #################### "