FROM ubuntu:jammy

RUN apt-get update && apt-get install -y git
RUN apt-get update && apt-get install -y vim
RUN apt-get update && apt-get install -y sudo
RUN apt-get update && apt-get install -y systemd apt-utils ssh

ARG DEBIAN_FRONTEND=noninteractive

RUN mkdir -p /opt/MagAOX/source/
WORKDIR /opt/MagAOX/source/
RUN git clone --depth=1 https://github.com/magao-x/MagAOX.git
WORKDIR /opt/MagAOX/source/MagAOX

ENV MAGAOX_ROLE container
RUN echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections

RUN echo "MAGAOX_ROLE=${MAGAOX_ROLE}" > /etc/profile.d/magaox_role.sh

RUN bash -l /opt/MagAOX/source/MagAOX/setup/setup_users_and_groups.sh
RUN bash -l /opt/MagAOX/source/MagAOX/setup/steps/install_ubuntu_22_packages.sh
RUN bash -l /opt/MagAOX/source/MagAOX/setup/steps/configure_ubuntu_22.sh

## Build third-party dependencies under /opt/MagAOX/vendor
RUN mkdir -p /opt/MagAOX/vendor
WORKDIR /opt/MagAOX/vendor
RUN bash -l /opt/MagAOX/source/MagAOX/setup/steps/install_fftw.sh
RUN bash -l /opt/MagAOX/source/MagAOX/setup/steps/install_rclone.sh
RUN bash -l /opt/MagAOX/source/MagAOX/setup/steps/install_cfitsio.sh
RUN bash -l /opt/MagAOX/source/MagAOX/setup/steps/install_eigen.sh
RUN bash -l /opt/MagAOX/source/MagAOX/setup/steps/install_zeromq.sh
RUN bash -l /opt/MagAOX/source/MagAOX/setup/steps/install_cppzmq.sh
RUN bash -l /opt/MagAOX/source/MagAOX/setup/steps/install_flatbuffers.sh
RUN bash -l /opt/MagAOX/source/MagAOX/setup/steps/install_openblas.sh

WORKDIR /opt/MagAOX/source/MagAOX

# Initialize the config and calib repos
RUN bash -l /opt/MagAOX/source/MagAOX/setup/steps/install_magao-x_config.sh
RUN bash -l /opt/MagAOX/source/MagAOX/setup/steps/install_magao-x_calib.sh

# Create Python env and install Python libs that need special treatment
RUN bash -l /opt/MagAOX/source/MagAOX/setup/steps/install_python.sh
# Make RUN commands use the conda env
SHELL ["/opt/conda/bin/conda", "run", "-n", "base", "/bin/bash", "-c"]
# RUN bash -l /opt/MagAOX/source/MagAOX/setup/steps/configure_python.sh
RUN pip3 install ipython ipykernel --upgrade

## Needed by the Milk & Cacao install
RUN conda install -y pybind11 -c conda-forge

ENV pythonExe=/opt/conda/bin/python

# # Install first-party deps
RUN bash -l /opt/MagAOX/source/MagAOX/setup/steps/install_xrif.sh
RUN bash -l /opt/MagAOX/source/MagAOX/setup/steps/install_purepyindi.sh
RUN bash -l /opt/MagAOX/source/MagAOX/setup/steps/install_purepyindi2.sh
RUN bash -l /opt/MagAOX/source/MagAOX/setup/steps/install_xconf.sh
RUN bash -l /opt/MagAOX/source/MagAOX/setup/steps/install_lookyloo.sh
RUN bash -l /opt/MagAOX/source/MagAOX/setup/steps/install_magpyx.sh
RUN bash -l /opt/MagAOX/source/MagAOX/setup/steps/install_mxlib.sh

# Install milk. The install_milk_and_cacao.sh script doesn't work in layer, so need to do it manually
# SHELL ["/bin/bash", "-c"]
WORKDIR /opt/MagAOX/source
RUN git clone -b dev --depth=1 https://github.com/milk-org/milk.git
RUN git clone -b dev --depth=1 https://github.com/cacao-org/cacao.git /opt/MagAOX/source/milk/plugins/cacao-src
RUN mkdir -p opt/MagAOX/source/milk/_build
WORKDIR /opt/MagAOX/source/milk/_build
# RUN cmake .. -DCMAKE_INSTALL_PREFIX=/usr/local -Dbuild_python_module=ON -DPYTHON_EXECUTABLE=/opt/conda/bin/python
RUN cmake ..
RUN make
RUN sudo make install
RUN sudo /opt/conda/bin/python -m pip install ../src/ImageStreamIO/
RUN /opt/conda/bin/python -c 'import ImageStreamIOWrap' || exit 1
RUN milkSuffix=bin/milk && milkBinary=$(grep -e "${milkSuffix}$" ./install_manifest.txt) && milkPath=${milkBinary/${milkSuffix}/} && sudo ln -s $milkPath /usr/local/milk
RUN echo "/usr/local/milk/lib" | sudo tee /etc/ld.so.conf.d/milk.conf
RUN sudo ldconfig
RUN echo "export PATH=\"\$PATH:/usr/local/milk/bin\"" | sudo tee /etc/profile.d/milk.sh
RUN echo "export PKG_CONFIG_PATH=\$PKG_CONFIG_PATH:/usr/local/milk/lib/pkgconfig" | sudo tee -a /etc/profile.d/milk.sh
RUN echo "export MILK_SHM_DIR=/milk/shm" | sudo tee -a /etc/profile.d/milk.sh
RUN echo "export MILK_ROOT=/opt/MagAOX/source/milk" | sudo tee -a /etc/profile.d/milk.sh
RUN echo "export MILK_INSTALLDIR=/usr/local/milk" | sudo tee -a /etc/profile.d/milk.sh
RUN sudo mkdir -p /milk/shm

# Install milkzmq. The install_milkzmq.sh script doesn't work in layer, so need to do it manually
WORKDIR /opt/MagAOX/source
RUN git clone -b master --depth=1 https://github.com/jaredmales/milkzmq.git
WORKDIR /opt/MagAOX/source/milkzmq
RUN make
RUN sudo make install

SHELL ["/bin/bash", "-c", "source /etc/profile.d/mxmakefile.sh"]

# realtime image viewer
RUN bash -l /opt/MagAOX/source/MagAOX/setup/steps/install_rtimv.sh
RUN echo "export RTIMV_CONFIG_PATH=/opt/MagAOX/config" | sudo tee /etc/profile.d/rtimv_config_path.sh

# aliases to improve ergonomics of MagAO-X ops
RUN sudo bash -l /opt/MagAOX/source/MagAOX/setup/steps/install_aliases.sh

## Install MagAOX
# Build flatlogs
SHELL ["/bin/bash", "-c"]
WORKDIR /opt/MagAOX/source/MagAOX/flatlogs/src
RUN make
RUN make install
# Build apps
WORKDIR /opt/MagAOX/source/MagAOX/
RUN make setup
RUN echo 'NEED_CUDA = no' >> /opt/MagAOX/source/MagAOX/local/common.mk
# The dbIngest link breaks the install, so remove it and then make the previous app the last one in the list
RUN sed -i 's@dbIngest@@g' Makefile
RUN sed -i 's@closedLoopIndi \\@closedLoopIndi@g' Makefile
RUN make all
RUN make install
# Set up upstream for git repo
RUN git remote remove origin
RUN git remote add origin https://github.com/magao-x/MagAOX.git
RUN git fetch origin
RUN git branch -u origin/dev dev

# Activate conda env for the user
SHELL ["/bin/bash", "-c", "source /opt/conda/bin/activate"]

ENV DEBIAN_FRONTEND dialog
RUN echo 'debconf debconf/frontend select Dialog' | debconf-set-selections
RUN sudo adduser xsup sudo
USER xsup

CMD ["/bin/bash"]