# Builds the Flutcraft server into one self-contained binary and ships it on
# a small Debian image.
#
# Not `scratch`: `dart compile exe` embeds the Dart runtime but still links
# against the host's libc, so the image needs one. Not the full Dart image
# either — nothing of the toolchain is needed once the binary exists.
#
# The build has to run on the architecture it ships to: Dart does not
# cross-compile, so building this on an arm64 laptop produces an arm64 binary.
# `docker build --platform linux/amd64` on a machine with emulation, or a CI
# runner of the right kind, is the way to an x86 image.
FROM dart:stable AS build

WORKDIR /app

# A workspace root that names only the three packages a server needs; the
# real one lists the Flutter packages too, and a Dart-only image cannot
# resolve those.
COPY docker/pubspec.yaml ./pubspec.yaml

# Only what resolving needs, so editing the game does not re-resolve.
COPY packages/flutcraft_domain/pubspec.yaml packages/flutcraft_domain/
COPY packages/flutcraft_protocol/pubspec.yaml packages/flutcraft_protocol/
COPY packages/flutcraft_server/pubspec.yaml packages/flutcraft_server/
RUN dart pub get

COPY packages/flutcraft_domain packages/flutcraft_domain
COPY packages/flutcraft_protocol packages/flutcraft_protocol
COPY packages/flutcraft_server packages/flutcraft_server
RUN dart compile exe packages/flutcraft_server/bin/server.dart -o /app/server

FROM debian:stable-slim

# A server that runs as root is a server that hands out root.
RUN useradd --system --create-home --uid 10001 flutcraft
USER flutcraft

COPY --from=build /app/server /usr/local/bin/flutcraft-server

# The world lives here; mount a volume over it or it goes when the container
# does.
VOLUME /world
EXPOSE 8787

# Exec form, so the binary is PID 1 and receives the SIGTERM that `docker
# stop` sends. Wrapped in a shell it would never get one, and the last minute
# of everybody's building would be lost on every deploy.
ENTRYPOINT ["flutcraft-server", "--port", "8787", "--world", "/world"]
