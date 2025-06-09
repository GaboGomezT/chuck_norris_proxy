# Build stage
FROM elixir:1.18.4 as build

# Install build dependencies
RUN apt-get update -y && apt-get install -y build-essential git \
    && apt-get clean && rm -f /var/lib/apt/lists/*_*

# Prepare build dir
WORKDIR /app

# Install hex + rebar
RUN mix local.hex --force && \
    mix local.rebar --force

# Install mix dependencies
COPY mix.exs mix.lock ./
RUN mix deps.get --only prod
RUN MIX_ENV=prod mix deps.compile

# Copy config and source code
COPY config ./config
COPY lib ./lib
COPY priv ./priv

# Compile the project
RUN MIX_ENV=prod mix compile

# Build the release
RUN MIX_ENV=prod mix release

# Release stage (use same image as build)
FROM elixir:1.18.4

WORKDIR /app

# Install runtime dependencies
RUN apt-get update -y && apt-get install -y openssl libncurses5 locales curl \
    && apt-get clean && rm -f /var/lib/apt/lists/*_*

# Set the locale
RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen

ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8

# Copy the release from the build stage
COPY --from=build /app/_build/prod/rel/chuck_norris_proxy ./

# Set environment variables
ENV MIX_ENV=prod
ENV PORT=4000

# The command to run the application
CMD ["bin/chuck_norris_proxy", "start"] 