FROM ruby:2.6.9-alpine3.15

RUN apk add --no-cache jq bash build-base nodejs python3 py3-pip imagemagick

RUN gem install bundler -v 2.1.4 \
  && gem install rails -v '~>6.0.3' \
  # Remove unneeded files (cached *.gem, *.o, *.c)
  && rm -rf /usr/local/bundle/cache/*.gem \
  && find /usr/local/bundle/gems/ -name "*.c" -delete \
  && find /usr/local/bundle/gems/ -name "*.o" -delete

LABEL "com.github.actions.name"="generate_ssm_document"
LABEL "com.github.actions.description"="generates an ssm document"
LABEL "com.github.actions.icon"="upload-cloud"
LABEL "com.github.actions.color"="purple"

LABEL version="0.2.0"
LABEL repository="https://github.com/rewindio/github-action-generate-ssm-documents"
LABEL homepage="https://www.rewind.com/"
LABEL maintainer="Harrison Hammond <harrison@rewind.io>"

# https://github.com/aws/aws-cli/blob/master/CHANGELOG.rst
ENV AWSCLI_VERSION='1.22.55'

RUN pip3 install --quiet --no-cache-dir awscli==${AWSCLI_VERSION}

ADD entrypoint.sh /entrypoint.sh
RUN chmod a+x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
