#!/bin/bash
set -e

echo "Waiting on Identity RBAC replication (${initialDelay})"
sleep ${initialDelay}

# Installing required packages
apk add --no-cache curl zip unzip

# Download the file using curl
echo "Downloading file from ${URL}"
curl -L -o repo.zip "${URL}"

# Check if the download was successful
if [ $? -ne 0 ]; then
    echo "Failed to download the file from ${URL}"
    exit 1
fi

# Create a directory for extracted files
mkdir -p extracted_files

# Unzip the file
echo "Extracting contents..."
unzip -q repo.zip -d extracted_files

# Find and replace 'kind: GitRepository' with 'kind: Bucket' in all files
find extracted_files -type f -path "*/software/*" -exec sed -i '
    /sourceRef:/{
        N;N;N
        s/sourceRef:\n[[:space:]]*kind: GitRepository\n[[:space:]]*name: flux-system\n[[:space:]]*namespace: flux-system/sourceRef:\n        kind: Bucket\n        name: flux-system\n        namespace: flux-system/g
    }' {} +


# Convert the JSON string to bash array
eval "array=($(echo $UPLOAD_DIR | jq -r '.[]'))"

# Loop the directories and upload the files
for item in "${array[@]}"; do
    echo "Processing folder ${item}"
    software_dir=$(find extracted_files -type d -name "${item}" -exec dirname {} \;)

    if [ -z "$software_dir" ]; then
        echo "Error: '${item}' directory not found in the extracted contents."
        exit 1
    fi

    echo "Uploading files from ${software_dir} to blob container ${CONTAINER}"
    az storage blob upload-batch --destination ${CONTAINER} --source "${software_dir}" --pattern "${item}/**" --overwrite true --auth-mode login
    echo "Files from software directory uploaded to blob container ${CONTAINER}."
done

# Clean up
rm -rf extracted_files repo.zip
