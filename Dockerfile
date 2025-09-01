# Copyright 2019-present Open Networking Foundation
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Default build args.
ARG GRPC_VER=1.48.2
ARG PI_COMMIT=main
ARG BMV2_COMMIT=main
ARG TAGNAME=latest
ARG BMV2_CONFIGURE_FLAGS="--with-pi --disable-elogger --without-nanomsg --without-thrift --disable-dependency-tracking"
ARG PI_CONFIGURE_FLAGS="--with-proto"
ARG JOBS=2
ARG BMV2_JOBS=1

# We use a 2-stage build. Build everything then copy only the strict necessary
# to a new image with runtime dependencies.

# ========= Builder stage =========
FROM debian:bookworm-slim AS builder
ENV DEBIAN_FRONTEND=noninteractive
ARG JOBS
ARG BMV2_JOBS
ENV MAKEFLAGS="-j${JOBS} -l ${JOBS}" \
    CMAKE_BUILD_PARALLEL_LEVEL="${JOBS}"

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential git curl ca-certificates pkg-config \
    cmake ninja-build autoconf automake libtool \
    python3 python3-pip python3-setuptools \
    libboost-dev libboost-filesystem-dev libboost-program-options-dev \
    libboost-system-dev libboost-thread-dev \
    libevent-dev libgflags-dev libgmp-dev libjudy-dev \
    libpcap-dev libreadline-dev zlib1g-dev \
    libssl-dev protobuf-compiler libprotobuf-dev libprotoc-dev \
    libc-ares-dev libre2-dev libabsl-dev \
    help2man groff-base python-is-python3 \
  && rm -rf /var/lib/apt/lists/*

# ---- gRPC（using system protobuf) ----
ARG GRPC_VER
RUN echo "*** Building gRPC v${GRPC_VER} on bookworm (system protobuf)"
RUN git clone --depth=1 -b v${GRPC_VER} https://github.com/grpc/grpc.git /tmp/grpc
WORKDIR /tmp/grpc

RUN cmake -B build -G Ninja \
      -DgRPC_BUILD_TESTS=OFF \
      -DgRPC_INSTALL=ON \
      -DgRPC_PROTOBUF_PROVIDER=package \
      -DgRPC_SSL_PROVIDER=package \
      -DgRPC_CARES_PROVIDER=package \
      -DgRPC_ZLIB_PROVIDER=package \
      -DgRPC_RE2_PROVIDER=package \
      -DgRPC_ABSL_PROVIDER=package \
      -DCMAKE_BUILD_TYPE=Release
RUN cmake --build build -- -j${JOBS}
RUN cmake --install build

# ---- PI ----
ARG PI_COMMIT
RUN echo "*** Building PI $PI_COMMIT - $PI_CONFIGURE_FLAGS"
RUN git clone https://github.com/p4lang/PI.git /tmp/PI && cd /tmp/PI && git checkout ${PI_COMMIT}
WORKDIR /tmp/PI
RUN ./autogen.sh && git submodule update --init --recursive
ARG PI_CONFIGURE_FLAGS
RUN ./configure ${PI_CONFIGURE_FLAGS}
RUN make -j${JOBS}
RUN make install

# ---- bmv2 ----
ARG BMV2_COMMIT
RUN echo "*** Building BMv2 $BMV2_COMMIT - $BMV2_CONFIGURE_FLAGS"
RUN git clone https://github.com/p4lang/behavioral-model.git /tmp/bmv2 && cd /tmp/bmv2 && git checkout ${BMV2_COMMIT}
WORKDIR /tmp/bmv2
RUN ./autogen.sh
ARG BMV2_CONFIGURE_FLAGS
RUN ./configure ${BMV2_CONFIGURE_FLAGS}
RUN make -j${BMV2_JOBS}
RUN make install

# ---- Mininet (Python3) ----
RUN git clone https://github.com/mininet/mininet.git /tmp/mininet
WORKDIR /tmp/mininet
# call python3 instead of python in this Makefile
RUN sed -i 's/PYTHONPATH=. python /PYTHONPATH=. python3 /g' Makefile
RUN make install-mnexec install-manpages PREFIX=/usr/local
RUN python3 setup.py install

RUN ldconfig

# ========= Runtime stage =========
FROM debian:bookworm-slim AS runtime
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    iproute2 iputils-ping net-tools ethtool socat psmisc procps iperf3 arping telnet tcpdump \
    python3 python3-setuptools python3-pexpect \
    libboost-filesystem1.74.0 libboost-program-options1.74.0 \
    libboost-system1.74.0 libboost-thread1.74.0 \
    libevent-2.1-7 libgflags2.2 libgmp10 libjudydebian1 \
    libpcap0.8 libreadline8 zlib1g libssl3 \
    libc-ares2 libre2-9 libprotobuf32 libabsl20220623 libprotoc32 \
  && rm -rf /var/lib/apt/lists/*

# copy objects on builder to /usr/local
COPY --from=builder /usr/local /usr/local
RUN ldconfig

WORKDIR /root
# place bmv2.py under /root
COPY bmv2.py /root/bmv2.py
ENV PYTHONPATH=/root

# gRPC ports
EXPOSE 50001-50999

# keep the original entry point
ENTRYPOINT ["mn", "--custom", "/root/bmv2.py", "--switch", "simple_switch_grpc", "--host", "onoshost", "--controller", "none"]

