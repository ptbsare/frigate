#!/bin/bash

set -euxo pipefail

NGINX_VERSION="1.27.4"
VOD_MODULE_VERSION="1.31"
SECURE_TOKEN_MODULE_VERSION="1.5"
SET_MISC_MODULE_VERSION="v0.33"
NGX_DEVEL_KIT_VERSION="v0.3.3"

# 启用源码仓库以使用 build-dep
# 检查 /etc/apt/sources.list.d/ 中是否存在 .sources 文件
SOURCES_FILE=$(find /etc/apt/sources.list.d/ -name "*.sources" | head -n 1)

if [ -n "$SOURCES_FILE" ]; then
    # 对于新的 .sources 格式 (Debian 12+, Ubuntu 23.10+)
    # 在 "Types: deb" 所在行添加 "deb-src"
    sed -i '/^Types:/s/deb/& deb-src/' "$SOURCES_FILE"
elif [ -f /etc/apt/sources.list ]; then
    # 对于旧的 sources.list 格式，创建一个新文件
    grep '^deb ' /etc/apt/sources.list | sed 's/^deb /deb-src /' > /etc/apt/sources.list.d/sources-src.list
else
    echo "警告: 未找到 APT 软件源文件。" >&2
fi

sed -i 's/archive.ubuntu.com/mirrors.tuna.tsinghua.edu.cn/g' /etc/apt/sources.list.d/ubuntu.sources
apt-get update
apt-get -yqq build-dep nginx

apt-get -yqq install --no-install-recommends ca-certificates wget
update-ca-certificates -f
apt install -y ccache

export PATH="/usr/lib/ccache:$PATH"

mkdir /tmp/nginx
wget -nv https://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz
tar -zxf nginx-${NGINX_VERSION}.tar.gz -C /tmp/nginx --strip-components=1
rm nginx-${NGINX_VERSION}.tar.gz
mkdir /tmp/nginx-vod-module
wget -nv https://github.com/kaltura/nginx-vod-module/archive/refs/tags/${VOD_MODULE_VERSION}.tar.gz
tar -zxf ${VOD_MODULE_VERSION}.tar.gz -C /tmp/nginx-vod-module --strip-components=1
rm ${VOD_MODULE_VERSION}.tar.gz
    # Patch MAX_CLIPS to allow more clips to be added than the default 128
sed -i 's/MAX_CLIPS (128)/MAX_CLIPS (1080)/g' /tmp/nginx-vod-module/vod/media_set.h
patch -d /tmp/nginx-vod-module/ -p1 << 'EOF'
--- a/vod/avc_hevc_parser.c       2022-06-27 11:38:10.000000000 +0000
+++ b/vod/avc_hevc_parser.c       2023-01-16 11:25:10.900521298 +0000
@@ -3,6 +3,9 @@
 bool_t
 avc_hevc_parser_rbsp_trailing_bits(bit_reader_state_t* reader)
 {
+	// https://github.com/blakeblackshear/frigate/issues/4572
+	return TRUE;
+
 	uint32_t one_bit;

 	if (reader->stream.eof_reached)
EOF


mkdir /tmp/nginx-secure-token-module
wget https://github.com/kaltura/nginx-secure-token-module/archive/refs/tags/${SECURE_TOKEN_MODULE_VERSION}.tar.gz
tar -zxf ${SECURE_TOKEN_MODULE_VERSION}.tar.gz -C /tmp/nginx-secure-token-module --strip-components=1
rm ${SECURE_TOKEN_MODULE_VERSION}.tar.gz

mkdir /tmp/ngx_devel_kit
wget https://github.com/vision5/ngx_devel_kit/archive/refs/tags/${NGX_DEVEL_KIT_VERSION}.tar.gz
tar -zxf ${NGX_DEVEL_KIT_VERSION}.tar.gz -C /tmp/ngx_devel_kit --strip-components=1
rm ${NGX_DEVEL_KIT_VERSION}.tar.gz

mkdir /tmp/nginx-set-misc-module
wget https://github.com/openresty/set-misc-nginx-module/archive/refs/tags/${SET_MISC_MODULE_VERSION}.tar.gz
tar -zxf ${SET_MISC_MODULE_VERSION}.tar.gz -C /tmp/nginx-set-misc-module --strip-components=1
rm ${SET_MISC_MODULE_VERSION}.tar.gz

cd /tmp/nginx

./configure --prefix=/usr/local/nginx \
    --with-file-aio \
    --with-http_sub_module \
    --with-http_ssl_module \
    --with-http_auth_request_module \
    --with-http_realip_module \
    --with-threads \
    --add-module=../ngx_devel_kit \
    --add-module=../nginx-set-misc-module \
    --add-module=../nginx-vod-module \
    --add-module=../nginx-secure-token-module \
    --with-cc-opt="-O3 -Wno-error=implicit-fallthrough"

make CC="ccache gcc" -j$(nproc) && make install
rm -rf /usr/local/nginx/html /usr/local/nginx/conf/*.default
