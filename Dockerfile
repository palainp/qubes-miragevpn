# Pin the base image to a specific hash for maximum reproducibility.
# It will probably still work on newer images, though, unless an update
# changes some compiler optimisations (unlikely).
# bookworm-slim taken from https://hub.docker.com/_/debian/tags?page=1&name=bookworm-slim
FROM debian@sha256:3d5df92588469a4c503adbead0e4129ef3f88e223954011c2169073897547cac
# install remove default packages repository
RUN rm /etc/apt/sources.list.d/debian.sources
# and set the package source to a specific release too
# taken from https://snapshot.debian.org/archive/debian
RUN printf "deb [check-valid-until=no] http://snapshot.debian.org/archive/debian/20240419T024211Z bookworm main\n" > /etc/apt/sources.list
# taken from https://snapshot.debian.org/archive/debian-security/
RUN printf "deb [check-valid-until=no] http://snapshot.debian.org/archive/debian-security/20240419T111010Z bookworm-security main\n" >> /etc/apt/sources.list

RUN apt update && apt install --no-install-recommends --no-install-suggests -y wget ca-certificates git patch unzip bzip2 xz-utils make gcc g++ libc-dev
RUN wget -O /usr/bin/opam https://github.com/ocaml/opam/releases/download/2.1.6/opam-2.1.6-i686-linux && chmod 755 /usr/bin/opam
# taken from https://raw.githubusercontent.com/ocaml/opam/master/shell/install.sh
RUN test `sha512sum /usr/bin/opam | cut -d' ' -f1` = \
"2b308e7a848252d831a1e046b70156cd901e8a5d95405fc03244fc69ce08222675871d3bcc35352b4448f15787f68a16491c574a6f9d5d8c9bcab81eb6d71ef8" || exit

ENV OPAMROOT=/tmp
ENV OPAMCONFIRMLEVEL=unsafe-yes
# Pin last known-good version for reproducible builds.
# Remove this line (and the base image pin above) if you want to test with the
# latest versions.
# taken from https://github.com/ocaml/opam-repository
RUN opam init --disable-sandboxing -a --bare https://github.com/ocaml/opam-repository.git#2926702fdd0fe7cab6ee1fa26ccecd28c3c3dd95
RUN opam switch create myswitch 4.14.2
RUN opam exec -- opam install -y mirage opam-monorepo ocaml-solo5
RUN opam exec -- opam install -y tls
RUN opam pin add -y https://github.com/robur-coop/miragevpn.git#34588aecfee64cbd1bf4be9ca4f198423a3c3c0b
RUN opam pin add -y https://github.com/mirage/mirage-qubes.git#6d4745eb111c84d68efc8bb14e03d4c5c761df3b
RUN mkdir /tmp/orb-build
ADD config.ml /tmp/orb-build/config.ml
WORKDIR /tmp/orb-build
CMD opam exec -- sh -exc 'mirage configure -t xen --extra-repos=\
opam-overlays:https://github.com/dune-universe/opam-overlays.git#4e75ee36715b27550d5bdb87686bb4ae4c9e89c4,\
mirage-overlays:https://github.com/dune-universe/mirage-opam-overlays.git#797cb363df3ff763c43c8fbec5cd44de2878757e \
&& make depend && make build'
