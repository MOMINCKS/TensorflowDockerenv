FROM nvidia/cuda:11.2.2-devel-ubuntu20.04
LABEL MAINTAINER KEVIN CHAN <kschan.kevin@gmail.com>

# params
ENV DEBIAN_FRONTEND noninteractive
ENV BASEDIR /repo
ENV NJOBS 16

# install basics
RUN apt-get -y update
RUN apt-get -y install sudo && useradd -m user && echo "user:user" | chpasswd && adduser user sudo
RUN apt-get -y install \
    # basics
    build-essential cmake wget zip unzip git wget curl vim ack htop python3-dev python3-pip \
    # required by protobuf
    autoconf automake libtool \
    # required by onnx
    libprotobuf-dev protobuf-compiler \
    # opencl
    ocl-icd-opencl-dev \
    # miscs
    libhdf5-dev libc-ares-dev libeigen3-dev libatlas-base-dev libopenblas-dev libblas-dev gfortran liblapack-dev

# required by tensorflow
RUN python3 -m pip install --upgrade pip
RUN pip3 install -U numpy wheel
RUN pip3 install -U keras_preprocessing --no-deps

# git clone all repos
WORKDIR ${BASEDIR}
RUN git clone https://github.com/protocolbuffers/protobuf.git
RUN git clone https://github.com/onnx/onnx.git
RUN git clone https://github.com/oneapi-src/oneDNN.git
RUN git clone https://github.com/microsoft/onnxruntime.git
RUN git clone https://github.com/opencv/opencv.git
RUN git clone https://github.com/tensorflow/tensorflow.git

# build protobuf
ENV PROTOBUF_VER 3.19.1
WORKDIR ${BASEDIR}/protobuf
RUN git checkout tags/v${PROTOBUF_VER} -b build
RUN git submodule update --init --recursive
WORKDIR ${BASEDIR}/protobuf/build
RUN cmake ../cmake \
    -D CMAKE_BUILD_TYPE=release \
    -D CMAKE_INSTALL_PREFIX=/usr \
    -D protobuf_BUILD_SHARED_LIBS=OFF \
    -D protobuf_BUILD_TESTS=OFF
RUN make -j${NJOBS}
RUN make install

# build onnx
ENV ONNX_VER 1.10.2
WORKDIR ${BASEDIR}/onnx
RUN git checkout tags/v${ONNX_VER} -b build
RUN git submodule update --init --recursive
ENV CMAKE_ARGS "-DONNX_USE_PROTOBUF_SHARED_LIBS=ON"
RUN pip3 install -e .
RUN unset CMAKE_ARGS

# build onednn
ENV ONEDNN_VER 2.4.3
WORKDIR ${BASEDIR}/oneDNN
RUN git checkout tags/v${ONEDNN_VER} -b build
WORKDIR ${BASEDIR}/oneDNN/build
RUN cmake .. \
    -D ONEDNN_BUILD_EXAMPLES=OFF \
    -D ONEDNN_BUILD_TESTS=OFF \
    -D DNNL_CPU_RUNTIME=OMP \
    -D DNNL_GPU_RUNTIME=OCL \
    -D DDNNL_GPU_VENDOR=NVIDIA \
    -D OPENCLROOT=/usr/lib/x86_64-linux-gnu/libOpenCL.so
RUN make -j16

# build opencv
# ENV OPENCV_VER 4.5.4
# WORKDIR ${BASEDIR}/opencv
# RUN git checkout tags/${OPENCV_VER} -b build
# WORKDIR ${BASEDIR}/opencv/build
WORKDIR ${BASEDIR}
RUN wget -O opencv.zip https://github.com/opencv/opencv/archive/master.zip && \
    wget -O opencv_contrib.zip https://github.com/opencv/opencv_contrib/archive/master.zip
RUN unzip opencv.zip && unzip opencv_contrib.zip
WORKDIR ${BASEDIR}/opencv_build
RUN cmake ../opencv-master \
    -D CPU_BASELINE=AVX2 \
    -D WITH_CUDA=ON \
    -D WITH_ONNX=ON \
    -D WITH_OPENMP=ON \
    -D WITH_OPENGL=ON \
    -D WITH_OPENCL=ON \
	-D WITH_CUBLAS=ON \
    -D OPEN_DNN_CUDA=ON \
    -D OPENCV_EXTRA_MODULES_PATH=../opencv_contrib-master/modules
RUN make -j${NJOBS}

# build tensorrt 8.0.3.4
WORKDIR ${BASEDIR}
ADD ./nv-tensorrt-repo-ubuntu2004-cuda11.3-trt8.0.3.4-ga-20210831_1-1_amd64.deb ${BASEDIR}
RUN dpkg -i nv-tensorrt-repo-ubuntu2004-cuda11.3-trt8.0.3.4-ga-20210831_1-1_amd64.deb
RUN ls /var/nv-tensorrt-repo-*/7fa2af80.pub | xargs apt-key add && apt-get -y update
RUN apt-get -y install python3-libnvinfer-dev uff-converter-tf onnx-graphsurgeon

# build onnxruntime
RUN apt-get -y install snapd
RUN pip3 install onnxruntime-gpu
# ENV ONNXRT_VER 1.9.1
# WORKDIR ${BASEDIR}/onnxruntime
# RUN git checkout tags/v${ONNXRT_VER} -b build
# RUN ./build.sh \
#     --cudnn_home /usr/lib/x86_64-linux-gnu \
#     --cuda_home /usr/local/cuda \
#     --use_tensorrt \
#     --tensorrt_home /usr/lib/python3.8/dist-packages/tensorrt

# build bazel 3.7.2
WORKDIR ${BASEDIR}
RUN wget https://github.com/bazelbuild/bazel/releases/download/3.7.2/bazel_3.7.2-linux-x86_64.deb
RUN dpkg -i bazel_3.7.2-linux-x86_64.deb

# build tensorflow
ENV TF_VER 2.7.0
WORKDIR ${BASEDIR}/tensorflow
RUN git checkout tags/v${TF_VER} -b build
RUN ln -s /usr/bin/python3 /usr/bin/python
RUN python3 configure.py
RUN bazel build \
    --config cuda \
    --config mkl \
    --jobs 8 \
    //tensorflow/tools/pip_package:build_pip_package
RUN ./bazel-bin/tensorflow/tools/pip_package/build_pip_package ${BASEDIR}
RUN pip3 install ${BASEDIR}/tensorflow*.whl

# miscs python packages
ENV TFA_VER 0.15.0
ENV TFIO_VER 0.22.0
RUN pip3 install pycuda pyyaml requests PyQt5 scipy Cython 
RUN pip3 install tensorflow-addons==${TFA_VER}
RUN pip3 install tensorflow-io==${TFIO_VER}

# finishing up
USER user
WORKDIR /workspace
CMD /bin/bash