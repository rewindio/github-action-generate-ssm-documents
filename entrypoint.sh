#!/bin/bash

# text color codes
TEXT_COLOUR_BEIGE="\e[38;5;179m"
TEXT_COLOUR_RED="\e[38;5;196m"
TEXT_COLOUR_GREEN="\e[38;5;2m"
TEXT_COLOUR_ORANGE="\e[38;5;202m"
TEXT_COLOUR_CLEAR="\033[0m"

if [ -z "$AWS_ACCESS_KEY_ID" ]; then
  echo "AWS_ACCESS_KEY_ID is not set. Quitting."
  exit 1
fi

if [ -z "$AWS_SECRET_ACCESS_KEY" ]; then
  echo "AWS_SECRET_ACCESS_KEY is not set. Quitting."
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
if [ -z "$PUBLISH_REGIONS" ]; then
  PUBLISH_REGIONS="us-east-1"
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
      if [ $DEBUG == True ]; then echo "\n$FOLDER exists"; fi
      echo ""
  else
      mkdir tempFiles # create dir for temp files
      if [ $DEBUG == True ]; then echo "\nMaking $FOLDER"; fi
  fi

  for file in $(echo $FILE_LIST | jq '.[]');
  do

  # extract file name from path and extension
  fileName=${file##*/}
  fileName=${fileName%\"}
  fileName=${fileName#\"} # the name of the file. Used when calling the file from ssm document

  filePath=$(dirname $file)
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
  > tempFiles/$(echo $fileName | cut -f 1 -d '.').yml
  done

}

create_aws_profile(){
# Create a dedicated profile for this action to avoid conflicts
# with past/future actions.
PROFILE_NAME=ssm-create-document

aws configure --profile ${PROFILE_NAME} <<-EOF > /dev/null 2>&1
${AWS_ACCESS_KEY_ID}
${AWS_SECRET_ACCESS_KEY}
$1
text
EOF
}

# upload the created file to each region specified
upload_ssm_documents(){
  # seperate the given regions by the comma
  REGION_ARRAY=($(echo $PUBLISH_REGIONS | tr "," "\n")) 
  if [ $DEBUG == True ]; then echo "Region Array: $REGION_ARRAY"; fi

  for region in ${REGION_ARRAY[@]}
  do

    create_aws_profile $region

    if [ $DEBUG == True ]; then echo "Region: $region"; fi

    for file in $(echo $FILE_LIST | jq '.[]');
    do
      file=${file##*/}
      file=${file%\"}
      file=${file#\"}
      file=$(echo $file | cut -f 1 -d '.')

      filePath=$(echo $filePath | tr / -)
      if [ $DEBUG == True ]; then echo "SSM Document Name: $filePath-$file"; fi

      aws ssm create-document --content file://tempFiles/$file.yml --name "$filePath-$file" \
      --document-type "Command" \
      --profile ${PROFILE_NAME} \
      --region ${region} \
      --document-format YAML

    done
  done

}

remove_temp_files(){
  rm -rf tempFiles

}

# check if filtering is on and apply filter if needed
check_filter(){
  if [ $DEBUG == True ]; then echo "\nAll files:\n $FILE_LIST"; fi
  if [ $filtering != False ]
  then
    if [ $DEBUG == True ]; then echo "Filter is filtering to: $PREFIX_FILTER"; fi
    NEW_LIST="["
    for file in $(echo $FILE_LIST | jq '.[]');
    do
      if [ "$(echo ${file#\"} | cut -f1 -d"/")" == "$PREFIX_FILTER" ]
      then 
        NEW_LIST="$NEW_LIST$file,"
      fi
    done
    # overwrite the file list with the filtered version
    FILE_LIST="${NEW_LIST::${#NEW_LIST}-1}]"
    if [ $DEBUG == True ]; then echo "Filtered Files:\n $FILE_LIST"; fi
  fi

}

printf "Creating AWS profile..."
create_aws_profile
printf "${TEXT_COLOUR_GREEN}[DONE]\n${TEXT_COLOUR_CLEAR}"
printf "Filtering Files..."
check_filter
printf "${TEXT_COLOUR_GREEN}[DONE]\n${TEXT_COLOUR_CLEAR}"
printf "Creating ssm documents..."
create_ssm_documents
printf "${TEXT_COLOUR_GREEN}[DONE]\n${TEXT_COLOUR_CLEAR}"
printf "Uploading ssm documents to ssm document manager..."
upload_ssm_documents
printf "${TEXT_COLOUR_GREEN}[DONE]\n${TEXT_COLOUR_CLEAR}"
printf "Removing temp files..."
# remove_temp_files
printf "${TEXT_COLOUR_GREEN}[DONE]\n${TEXT_COLOUR_CLEAR}"
