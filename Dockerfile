FROM python:3.8-alpine

RUN apk update && apk add jq bash

LABEL "com.github.actions.name"="generate_ssm_document"
LABEL "com.github.actions.description"="generates an ssm document"
LABEL "com.github.actions.icon"="upload-cloud"
LABEL "com.github.actions.color"="purple"

LABEL version="0.1.0"
LABEL repository="https://github.com/rewindio/github-action-generate-ssm-documents"
LABEL homepage="https://www.rewind.io/"
LABEL maintainer="Harrison Hammond <harrison@rewind.io>"

# https://github.com/aws/aws-cli/blob/master/CHANGELOG.rst
ENV AWSCLI_VERSION='1.18.2'

RUN pip install --quiet --no-cache-dir awscli==${AWSCLI_VERSION}

ADD entrypoint.sh /entrypoint.sh
RUN chmod a+x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
