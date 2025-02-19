# daemon runs in the background
# run something like tail /var/log/CrowdInvestNetworkd/current to see the status
# be sure to run with volumes, ie:
# docker run -v $(pwd)/CrowdInvestNetworkd:/var/lib/CrowdInvestNetworkd -v $(pwd)/wallet:/home/CrowdInvestNetwork --rm -ti CrowdInvestNetwork:0.2.2
ARG base_image_version=0.10.0
FROM phusion/baseimage:$base_image_version

ADD https://github.com/just-containers/s6-overlay/releases/download/v1.21.2.2/s6-overlay-amd64.tar.gz /tmp/
RUN tar xzf /tmp/s6-overlay-amd64.tar.gz -C /

ADD https://github.com/just-containers/socklog-overlay/releases/download/v2.1.0-0/socklog-overlay-amd64.tar.gz /tmp/
RUN tar xzf /tmp/socklog-overlay-amd64.tar.gz -C /

ARG CROWDINVESTNETWORK_BRANCH=master
ENV CROWDINVESTNETWORK_BRANCH=${CROWDINVESTNETWORK_BRANCH}

# install build dependencies
# checkout the latest tag
# build and install
RUN apt-get update && \
    apt-get install -y \
      build-essential \
      python-dev \
      gcc-4.9 \
      g++-4.9 \
      git cmake \
      libboost1.58-all-dev && \
    git clone https://github.com/respectme/CIN/CIN.git /src/CrowdInvestNetwork && \
    cd /src/CrowdInvestNetwork && \
    git checkout $CROWDINVESTNETWORK_BRANCH && \
    mkdir build && \
    cd build && \
    cmake -DCMAKE_CXX_FLAGS="-g0 -Os -fPIC -std=gnu++11" .. && \
    make -j$(nproc) && \
    mkdir -p /usr/local/bin && \
    cp src/CrowdInvestNetworkd /usr/local/bin/CrowdInvestNetworkd && \
    cp src/walletd /usr/local/bin/walletd && \
    cp src/zedwallet /usr/local/bin/zedwallet && \
    cp src/miner /usr/local/bin/miner && \
    strip /usr/local/bin/CrowdInvestNetworkd && \
    strip /usr/local/bin/walletd && \
    strip /usr/local/bin/zedwallet && \
    strip /usr/local/bin/miner && \
    cd / && \
    rm -rf /src/CrowdInvestNetwork && \
    apt-get remove -y build-essential python-dev gcc-4.9 g++-4.9 git cmake libboost1.58-all-dev && \
    apt-get autoremove -y && \
    apt-get install -y  \
      libboost-system1.58.0 \
      libboost-filesystem1.58.0 \
      libboost-thread1.58.0 \
      libboost-date-time1.58.0 \
      libboost-chrono1.58.0 \
      libboost-regex1.58.0 \
      libboost-serialization1.58.0 \
      libboost-program-options1.58.0 \
      libicu55

# setup the CrowdInvestNetworkd service
RUN useradd -r -s /usr/sbin/nologin -m -d /var/lib/CrowdInvestNetworkd CrowdInvestNetworkd && \
    useradd -s /bin/bash -m -d /home/CrowdInvestNetwork CrowdInvestNetwork && \
    mkdir -p /etc/services.d/CrowdInvestNetworkd/log && \
    mkdir -p /var/log/CrowdInvestNetworkd && \
    echo "#!/usr/bin/execlineb" > /etc/services.d/CrowdInvestNetworkd/run && \
    echo "fdmove -c 2 1" >> /etc/services.d/CrowdInvestNetworkd/run && \
    echo "cd /var/lib/CrowdInvestNetworkd" >> /etc/services.d/CrowdInvestNetworkd/run && \
    echo "export HOME /var/lib/CrowdInvestNetworkd" >> /etc/services.d/CrowdInvestNetworkd/run && \
    echo "s6-setuidgid CrowdInvestNetworkd /usr/local/bin/CrowdInvestNetworkd" >> /etc/services.d/CrowdInvestNetworkd/run && \
    chmod +x /etc/services.d/CrowdInvestNetworkd/run && \
    chown nobody:nogroup /var/log/CrowdInvestNetworkd && \
    echo "#!/usr/bin/execlineb" > /etc/services.d/CrowdInvestNetworkd/log/run && \
    echo "s6-setuidgid nobody" >> /etc/services.d/CrowdInvestNetworkd/log/run && \
    echo "s6-log -bp -- n20 s1000000 /var/log/CrowdInvestNetworkd" >> /etc/services.d/CrowdInvestNetworkd/log/run && \
    chmod +x /etc/services.d/CrowdInvestNetworkd/log/run && \
    echo "/var/lib/CrowdInvestNetworkd true CrowdInvestNetworkd 0644 0755" > /etc/fix-attrs.d/CrowdInvestNetworkd-home && \
    echo "/home/CrowdInvestNetwork true CrowdInvestNetwork 0644 0755" > /etc/fix-attrs.d/CrowdInvestNetwork-home && \
    echo "/var/log/CrowdInvestNetworkd true nobody 0644 0755" > /etc/fix-attrs.d/CrowdInvestNetworkd-logs

VOLUME ["/var/lib/CrowdInvestNetworkd", "/home/CrowdInvestNetwork","/var/log/CrowdInvestNetworkd"]

ENTRYPOINT ["/init"]
CMD ["/usr/bin/execlineb", "-P", "-c", "emptyenv cd /home/CrowdInvestNetwork export HOME /home/CrowdInvestNetwork s6-setuidgid CrowdInvestNetwork /bin/bash"]
