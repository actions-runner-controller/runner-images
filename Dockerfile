FROM mcr.microsoft.com/dotnet/runtime-deps:6.0-focal

LABEL org.opencontainers.image.source="https://github.com/actions-runner-controller/runner-images"

ARG TARGETOS
ARG TARGETARCH
ARG RUNNER_VERSION=2.310.2
ARG RUNNER_CONTAINER_HOOKS_VERSION=0.3.2
ARG DOCKER_VERSION=23.0.6

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update -y \
    && apt-get install -y --no-install-recommends \
        sudo \
        # packages in actions-runner-controller/runner-22.04
        curl \
        git \
        jq \
        unzip \
        zip \
        # packages in actions-runner-controller/runner-20.04
        build-essential \
        locales \
        tzdata \
        # ruby/setup-ruby dependencies
        # https://github.com/ruby/setup-ruby#using-self-hosted-runners
        libyaml-dev \
        # dockerd dependencies
        tini \
        iptables

# KEEP LESS PACKAGES:
# We'd like to keep this image small for maintanability and security.
# See also,
# https://github.com/actions/actions-runner-controller/pull/2050
# https://github.com/actions/actions-runner-controller/blob/master/runner/actions-runner.ubuntu-22.04.dockerfile

# keep /var/lib/apt/lists to reduce time of apt-get update in a job

# set up the runner environment,
# based on https://github.com/actions/runner/blob/v2.309.0/images/Dockerfile
RUN adduser --disabled-password --gecos "" --uid 1001 runner \
    && groupadd docker --gid 123 \
    && usermod -aG sudo runner \
    && usermod -aG docker runner \
    && echo "%sudo   ALL=(ALL:ALL) NOPASSWD:ALL" > /etc/sudoers \
    && echo "Defaults env_keep += \"DEBIAN_FRONTEND\"" >> /etc/sudoers

WORKDIR /home/runner
RUN export RUNNER_ARCH=${TARGETARCH} \
    && if [ "$RUNNER_ARCH" = "amd64" ]; then export RUNNER_ARCH=x64 ; fi \
    && curl -f -L -o runner.tar.gz https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/actions-runner-${TARGETOS}-${RUNNER_ARCH}-${RUNNER_VERSION}.tar.gz \
    && tar xzf ./runner.tar.gz \
    && rm runner.tar.gz

RUN curl -f -L -o runner-container-hooks.zip https://github.com/actions/runner-container-hooks/releases/download/v${RUNNER_CONTAINER_HOOKS_VERSION}/actions-runner-hooks-k8s-${RUNNER_CONTAINER_HOOKS_VERSION}.zip \
    && unzip ./runner-container-hooks.zip -d ./k8s \
    && rm runner-container-hooks.zip

RUN export RUNNER_ARCH=${TARGETARCH} \
    && if [ "$RUNNER_ARCH" = "amd64" ]; then export DOCKER_ARCH=x86_64 ; fi \
    && if [ "$RUNNER_ARCH" = "arm64" ]; then export DOCKER_ARCH=aarch64 ; fi \
    && curl -fLo docker.tgz https://download.docker.com/${TARGETOS}/static/stable/${DOCKER_ARCH}/docker-${DOCKER_VERSION}.tgz \
    && tar zxvf docker.tgz \
    && rm -rf docker.tgz \
    && install -o root -g root -m 755 docker/* /usr/bin/ \
    && rm -rf docker

# some setup actions store cache into /opt/hostedtoolcache
ENV RUNNER_TOOL_CACHE /opt/hostedtoolcache

RUN mkdir /opt/hostedtoolcache \
    && chown runner:docker /opt/hostedtoolcache

# We pre-install nodejs to reduce time of setup-node and improve its reliability.
ENV NODE_VERSION 18.18.2

RUN if [ "${TARGETARCH}" = "amd64" ]; then export NODE_ARCH=x64 ; else export NODE_ARCH=${TARGETARCH} ; fi; \
    mkdir -p /opt/hostedtoolcache/node/${NODE_VERSION}/${NODE_ARCH} && \
    curl -s -L https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-${NODE_ARCH}.tar.gz \
    | tar xvzf - --strip-components=1 -C /opt/hostedtoolcache/node/${NODE_VERSION}/${NODE_ARCH} \
    && touch /opt/hostedtoolcache/node/${NODE_VERSION}/${NODE_ARCH}.complete \
    && chown -R runner:docker /opt/hostedtoolcache/node && \
    ${RUNNER_TOOL_CACHE}/node/${NODE_VERSION}/${NODE_ARCH}/bin/node --version

RUN export PATH=$PATH:/home/runner/externals/node20/bin ; export NODE_PATH=/home/runner/externals/node20/lib/node_modules ; \
    npm install -g @actions/tool-cache && node <<EOF && npm uninstall -g @actions/tool-cache
const tc = require('@actions/tool-cache');
const allNodeVersions = tc.findAllVersions('node');
const expected = ['${NODE_VERSION}'];
if (expected[0] == '') {
  console.log('Invalid NODE_VERSION: ' + expected[0]);
  process.on("exit", function() {
      process.exit(1);
  });
} else if (allNodeVersions.length != expected.length) {
  console.log('Expected versions of node available: ' + expected);
  console.log('Actual versions of node available: ' + allNodeVersions);
  process.on("exit", function() {
    process.exit(1);
  });
} else if (allNodeVersions[0] != expected[0]) {
  console.log('Expected versions of node available: ' + expected);
  console.log('Actual versions of node available: ' + allNodeVersions);
  process.on("exit", function() {
    process.exit(1);
  });
} else {
  console.log('Versions of node available: ' + allNodeVersions);
}
EOF

ENV RUBY_VERSION 3.2.2
RUN if [ "${TARGETARCH}" = "amd64" ]; then export RUBY_ARCH=x64 ; else export RUBY_ARCH=${TARGETARCH} ; fi; \
    git clone https://github.com/rbenv/ruby-build.git && \
    ./ruby-build/install.sh && \
    apt-get install -y --no-install-recommends zlib1g-dev libssl-dev && \
    RUBY_CONFIGURE_OPTS="--enable-shared --disable-install-doc" ruby-build --verbose ${RUBY_VERSION} ${RUNNER_TOOL_CACHE}/Ruby/${RUBY_VERSION}/${RUBY_ARCH} && \
    ${RUNNER_TOOL_CACHE}/Ruby/${RUBY_VERSION}/${RUBY_ARCH}/bin/ruby --version

RUN if [ "${TARGETARCH}" = "amd64" ]; then export RUBY_ARCH=x64 ; else export RUBY_ARCH=${TARGETARCH} ; fi; \
    touch ${RUNNER_TOOL_CACHE}/Ruby/${RUBY_VERSION}/${RUBY_ARCH}.complete && \
    chown -R runner:docker /opt/hostedtoolcache/Ruby

RUN export PATH=$PATH:/home/runner/externals/node20/bin ; export NODE_PATH=/home/runner/externals/node20/lib/node_modules ; \
    ls -lah ${RUNNER_TOOL_CACHE}/Ruby/${RUBY_VERSION} && npm install -g @actions/tool-cache && node <<EOF && npm uninstall -g @actions/tool-cache
const tc = require('@actions/tool-cache');
const allRubyVersions = tc.findAllVersions('Ruby');
const expected = ['${RUBY_VERSION}'];
if (expected[0] == '') {
  console.log('Invalid RUBY_VERSION: ' + expected[0]);
  process.on("exit", function() {
      process.exit(1);
  });
} else if (allRubyVersions.length != expected.length) {
  console.log('Expected versions of ruby available: ' + expected);
  console.log('Actual versions of ruby available: ' + allRubyVersions);
  process.on("exit", function() {
    process.exit(1);
  });
} else if (allRubyVersions[0] != expected[0]) {
  console.log('Expected versions of ruby available: ' + expected);
  console.log('Actual versions of ruby available: ' + allRubyVersions);
  process.on("exit", function() {
    process.exit(1);
  });
} else {
  console.log('Versions of ruby available: ' + allRubyVersions);
}
EOF

COPY entrypoint.sh /

VOLUME /var/lib/docker

# some setup actions depend on ImageOS variable
# https://github.com/actions/runner-images/issues/345
ENV ImageOS=ubuntu20

USER runner
ENTRYPOINT ["/usr/bin/tini", "--", "/entrypoint.sh"]
CMD ["/home/runner/run.sh"]
