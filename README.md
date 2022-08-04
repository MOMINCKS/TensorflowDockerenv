# TensorflowDockerenv

fully customizable and compilable tensorflow development environment in docker

### Libraries:
* protobuf == 3.19.1
* onnx == 1.10.2
* onednn == 2.4.3
* opencv == 4.5.4
* tensorrt == 8.0.3.4
* bazel == 3.7.2
* tensorflow == 2.7.0
* onnxruntime (wheel install)
* tensorflow-addons == 0.15.0
* tensorflow-io == 0.22.0
* and more ...

### Requirements:
* tensorrt 8.0.3.4 from NVIDIA website: nv-tensorrt-repo-ubuntu2004-cuda11.3-trt8.0.3.4-ga-20210831_1-1_amd64.deb

### Tips:
* Compiled with AVX2/AVX512 on
* Compiled with highest NVIDIA compute capability supported by both device and tensorflow

### Results:
* training 75% faster than vanilla wheel install (HDRNet with Intel Xeon Silver and 2080Ti)
