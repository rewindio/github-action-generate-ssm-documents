#!/bin/bash

# text color codes
TEXT_COLOUR_BEIGE="\e[38;5;179m"
TEXT_COLOUR_RED="\e[38;5;196m"
TEXT_COLOUR_GREEN="\e[38;5;2m"
TEXT_COLOUR_ORANGE="\e[38;5;202m"
TEXT_COLOUR_CLEAR="\033[0m"

if [ -z "$AWS_ACCESS_KEY_ID_PROD" ]; then
  echo "AWS_ACCESS_KEY_ID_PROD is not set. Quitting."
  exit 1
fi

if [ -z "$AWS_SECRET_ACCESS_KEY_PROD" ]; then
  echo "AWS_SECRET_ACCESS_KEY_PROD is not set. Quitting."
  exit 1
fi

if [ -z "$AWS_ACCESS_KEY_ID_STAGING" ]; then
  echo "AWS_ACCESS_KEY_ID_STAGING is not set. Quitting."
  exit 1
fi

if [ -z "$AWS_SECRET_ACCESS_KEY_STAGING" ]; then
  echo "AWS_SECRET_ACCESS_KEY_STAGING is not set. Quitting."
  exit 1
fi

if [ -z "$REPO_NAME" ]; then
  echo "REPO_NAME is not set. Quitting."
  exit 1
fi

if [ -z "$REPO_OWNER" ]; then
  echo "REPO_OWNER is not set. Quitting."
  exit 1
fi

# Default to us-east-1 if PUBLISH_REGIONS not set.
if [ -z "$PUBLISH_REGIONS_PROD" ]; then
  PUBLISH_REGIONS_PROD="us-east-1"
fi

if [ -z "$PUBLISH_REGIONS_STAGING" ]; then
  PUBLISH_REGIONS_STAGING="us-east-1"
fi

if [ -z "$DEBUG" ]; then
  echo "DEBUG output is off."
  DEBUG=False
else
  if [ $DEBUG == True ] || [ $DEBUG == true ]
  then
    echo "DEBUG output is on."
    DEBUG=True
  else
    echo "DEBUG output is off."
    DEBUG=False
  fi
fi

if [ -z "$FILE_LIST" ]; then
  echo "FILE_LIST is not set. Quitting."
  exit 1
fi

filtering=False
if [ -z "$PREFIX_FILTER" ]; then
  echo "PREFIX_FILTER is not set. Not Filtering."
  filtering=False
  PREFIX_FILTER=/
else
  filtering=True
fi

if [ $DEBUG == True ]; then pwd; ls; fi

# create the ssm docu
create_ssm_documents(){

  # ensure tempFiles folder exists
  FOLDER=tempFiles
  if test -d "$FOLDER"; 
  then
      if [ $DEBUG == True ]; then printf "\n%s exists" "$FOLDER"; fi
      echo ""
  else
      mkdir tempFiles # create dir for temp files
      if [ $DEBUG == True ]; then printf "\nMaking %s" "$FOLDER"; fi
  fi

  for file in $(echo "$FILE_LIST" | jq '.[]');
  do

  # extract file name from path and extension
  fileName=${file##*/}
  fileName=${fileName%\"}
  fileName=${fileName#\"} # the name of the file. Used when calling the file from ssm document

  filePath=$(dirname "$file")
  filePath=${filePath%\"}
  filePath=${filePath#\"} # the path to the document

  if [ $DEBUG == True ]; then echo "File Name: $fileName"; fi
  if [ $DEBUG == True ]; then echo "File path: $filePath"; fi
  if [ $DEBUG == True ]; then echo "Full Path: $filePath/$fileName"; fi

  # create the ssm document for each file given
  cat base_doc.yml | sed 's|$REPO_OWNER|'"${REPO_OWNER}|g" | \
  sed 's|$REPO_NAME|'"${REPO_NAME}|g" | \
  sed 's|$PREFIX_FILTER|'"${PREFIX_FILTER}|g" | \
  sed 's|$fileName|'"${fileName}|g" | \
  sed 's|$filePath|'"${filePath}|g" \
  > tempFiles/$fileName.yml
  done

}

create_aws_profile(){
# Create a dedicated profile for this action to avoid conflicts
# with past/future actions.
PROFILE_NAME=ssm-create-document

aws configure --profile ${PROFILE_NAME} <<-EOF > /dev/null 2>&1
$1
$2
$3
text
EOF
}

# upload the created file to each region specified
upload_ssm_documents(){
  # seperate the given regions by the comma
  REGION_ARRAY=($(echo "$3" | tr "," "\n")) 
  if [ $DEBUG == True ]; then printf "Region Array: %s" "${REGION_ARRAY[@]}"; fi

  for region in "${REGION_ARRAY[@]}"
  do

    create_aws_profile "$1" "$2" "$region"

    if [ $DEBUG == True ]; then echo "Region: $region"; fi

    for file in $(echo "$FILE_LIST" | jq '.[]');
    do

      if [ $DEBUG == True ]; then echo "File Pre-process: $file"; fi

      filePath=${file%\"}
      filePath=${filePath#\"}

      file=${filePath##*/}

      filePath=$(echo "$filePath" | cut -f 1 -d '.')
      filePath=$(echo "$filePath" | tr / -)

      if [ $DEBUG == True ]; then echo "File Post-process: $file"; fi
      if [ $DEBUG == True ]; then echo "SSM Document Name: $filePath"; fi

      aws ssm create-document --content file://tempFiles/$file.yml --name "$filePath" \
      --document-type "Command" \
      --profile ${PROFILE_NAME} \
      --region "${region}" \
      --document-format YAML

      # if the document already exists update it
      if [ $? -eq 255 ]
      then
        aws ssm update-document --content file://tempFiles/$file.yml --name "$filePath" \
        --profile ${PROFILE_NAME} \
        --region "${region}" \
        --document-version "$LATEST" \
        --document-format YAML
      fi

    done
  done

}

remove_temp_files(){
  rm -rf tempFiles

}

# check if filtering is on and apply filter if needed
check_filter(){
  if [ $DEBUG == True ]; then printf "\nAll files:\n %s" "$FILE_LIST"; fi
  if [ $filtering != False ]
  then
    if [ $DEBUG == True ]; then echo "Filter is filtering to: $PREFIX_FILTER"; fi
    NEW_LIST="["
    for file in $(echo "$FILE_LIST" | jq '.[]');
    do
      if [ "$(echo "${file#\"}" | cut -f1 -d"/")" == "$PREFIX_FILTER" ]
      then 
        NEW_LIST="$NEW_LIST$file,"
      fi
    done
    # overwrite the file list with the filtered version
    FILE_LIST="${NEW_LIST::${#NEW_LIST}-1}]"
    if [ $DEBUG == True ]; then printf "Filtered Files:\n %s" "$FILE_LIST"; fi
  fi

}

printf "Filtering Files..."
check_filter
printf "%b[DONE]\n%b" "${TEXT_COLOUR_GREEN}" "${TEXT_COLOUR_CLEAR}"
printf "Creating ssm documents..."
create_ssm_documents
printf "%b[DONE]\n%b" "${TEXT_COLOUR_GREEN}" "${TEXT_COLOUR_CLEAR}"
printf "Uploading staging ssm documents to ssm document manager..."
upload_ssm_documents "$AWS_ACCESS_KEY_ID_STAGING" "$AWS_SECRET_ACCESS_KEY_PROD_STAGING" "$PUBLISH_REGIONS_STAGING"
printf "%b[DONE]\n%b" "${TEXT_COLOUR_GREEN}" "${TEXT_COLOUR_CLEAR}"
printf "Uploading production ssm documents to ssm document manager..."
upload_ssm_documents "$AWS_ACCESS_KEY_ID_PROD" "$AWS_SECRET_ACCESS_KEY_PROD" "$PUBLISH_REGIONS_PROD"
printf "%b[DONE]\n%b" "${TEXT_COLOUR_GREEN}" "${TEXT_COLOUR_CLEAR}"
printf "Removing temp files..."
remove_temp_files
printf "%b[DONE]\n%b" "${TEXT_COLOUR_GREEN}" "${TEXT_COLOUR_CLEAR}"
