# Frigate (Custom Build)

This is a custom build of Frigate.

## Modifications

- The base image has been updated from Debian 12 to **Ubuntu 24.04** to incorporate newer and improved drivers.
- The Dockerfile and related build scripts have been patched to ensure compatibility with the new base image.

```
docker pull ptbsare/frigate:ubuntu24.04-latest
```
