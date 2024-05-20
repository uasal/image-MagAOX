### Base image for writing & testing MagAOX apps

#### Contents
The image is build on Ubuntu Jammy (22.04), with the following repos installed:
- [MagAOX dev branch](https://github.com/magao-x/MagAOX) (commit b41715e)
- [MagAOX config repo](https://github.com/magao-x/config) (commit 8637054)


#### How to build image in CLI
Can be built for multiple architectures with `buildx`. Add a version number tag and, if it's backwards compatible, the `latest` tag as well. For example:
```
docker buildx build --platform linux/amd64,linux/arm64 --push -t pearlhub/magaox-dev:vx -t pearlhub/magaox-dev:latest .
```