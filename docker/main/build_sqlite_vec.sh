#!/bin/bash

set -euxo pipefail

SQLITE_VEC_VERSION="0.1.3"

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
apt-get -yqq build-dep sqlite3 gettext git

mkdir /tmp/sqlite_vec
# Grab the sqlite_vec source code.
wget -nv https://github.com/asg017/sqlite-vec/archive/refs/tags/v${SQLITE_VEC_VERSION}.tar.gz
tar -zxf v${SQLITE_VEC_VERSION}.tar.gz -C /tmp/sqlite_vec

cd /tmp/sqlite_vec/sqlite-vec-${SQLITE_VEC_VERSION}

mkdir -p vendor
wget -O sqlite-amalgamation.zip https://www.sqlite.org/2024/sqlite-amalgamation-3450300.zip
unzip sqlite-amalgamation.zip
mv sqlite-amalgamation-3450300/* vendor/
rmdir sqlite-amalgamation-3450300
rm sqlite-amalgamation.zip

# build loadable module
make loadable

# install it
cp dist/vec0.* /usr/local/lib

