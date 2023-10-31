# Implementation notes

## setup-ruby

It turns out `setup-ruby` is not supposed to install Ruby on self-hosted runners.

When we tried bundling the tool cache for a Ruby version like:

```
RUN export PATH=$PATH:/home/runner/externals/node20/bin ; export NODE_PATH=/home/runner/externals/node20/lib/node_modules ; \
    npm install -g https://github.com/ruby/setup-ruby && env "INPUT_RUBY-VERSION=3.2.2" node <<EOF && npm uninstall -g setup-ruby
const sr = require('setup-ruby/dist')

sr.run()
EOF
```

It ended up with:

```
#0 53.56 ::debug::isExplicit: 3.2.2
#0 53.57 ::debug::explicit? true
#0 53.57 ::debug::checking cache: /opt/hostedtoolcache/Ruby/3.2.2/arm64
#0 53.57 ::debug::not found
#0 53.57 ::error::The current runner (ubuntu-20.04-arm64) was detected as self-hosted because the platform does not match a GitHub-hosted runner image (or that image is deprecated and no longer supported).%0AIn such a case, you should install Ruby in the $RUNNER_TOOL_CACHE yourself, for example using https://github.com/rbenv/ruby-build%0AYou can take inspiration from this workflow for more details: https://github.com/ruby/ruby-builder/blob/master/.github/workflows/build.yml%0A$ ruby-build 3.2.2 /opt/hostedtoolcache/Ruby/3.2.2/arm64%0AOnce that completes successfully, mark it as complete with:%0A$ touch /opt/hostedtoolcache/Ruby/3.2.2/arm64.complete%0AIt is your responsibility to ensure installing Ruby like that is not done in parallel.%0A
```

Apparently, it's working as intended; [you need to install Ruby beforehand to make setup-ruby work](https://github.com/ruby/setup-ruby/issues/242#issuecomment-1453730769).
