FROM mcr.microsoft.com/vscode/devcontainers/base:debian

ARG GLEAM_VERSION="v1.0.0"

RUN apt-get update \
  && export DEBIAN_FRONTEND=noninteractive \
  && apt-get -y install --no-install-recommends erlang curl 2>&1 \
  # Install Rebar3

  && curl -sSL https://github.com/erlang/rebar3/releases/download/3.22.1/rebar3 -o /usr/local/bin/rebar3 \
  && chmod +x /usr/local/bin/rebar3

RUN curl -sSL https://github.com/gleam-lang/gleam/releases/download/${GLEAM_VERSION}/gleam-${GLEAM_VERSION}-x86_64-unknown-linux-musl.tar.gz -o /tmp/gleam.tar.az \
  && tar -xzvf /tmp/gleam.tar.az -C /usr/local/bin \
  # # Clean up
  && apt-get autoremove -y \
  && apt-get clean -y \
  && rm -rf /var/lib/apt/lists/* /tmp/gleam.tar.az
