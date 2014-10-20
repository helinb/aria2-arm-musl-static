#!/bin/bash

set -e
set -x

mkdir ~/aria2 && cd ~/aria2

BASE=`pwd`
SRC=$BASE/src
WGET="wget --prefer-family=IPv4"
DEST=$BASE/opt
CC=arm-linux-musleabi-gcc
CXX=arm-linux-musleabi-g++
LDFLAGS="-L$DEST/lib"
CPPFLAGS="-I$DEST/include"
MAKE="make -j`nproc`"
CONFIGURE="./configure --prefix=/opt --host=arm-linux"
PATCHES=$(readlink -f $(dirname ${BASH_SOURCE[0]}))/patches
mkdir -p $SRC

######## ####################################################################
# ZLIB # ####################################################################
######## ####################################################################

mkdir $SRC/zlib && cd $SRC/zlib
$WGET http://zlib.net/zlib-1.2.8.tar.gz
tar zxvf zlib-1.2.8.tar.gz
cd zlib-1.2.8

LDFLAGS=$LDFLAGS \
CPPFLAGS=$CPPFLAGS \
CROSS_PREFIX=arm-linux-musleabi- \
./configure \
--prefix=/opt

$MAKE
make install DESTDIR=$BASE

########### #################################################################
# OPENSSL # #################################################################
########### #################################################################

mkdir -p $SRC/openssl && cd $SRC/openssl
$WGET http://www.openssl.org/source/openssl-1.0.1j.tar.gz
tar zxvf openssl-1.0.1j.tar.gz
cd openssl-1.0.1j

cat << "EOF" > openssl-musl.patch
--- a/crypto/ui/ui_openssl.c    2013-09-08 11:00:10.130572803 +0200
+++ b/crypto/ui/ui_openssl.c    2013-09-08 11:29:35.806580447 +0200
@@ -190,9 +190,9 @@
 # undef  SGTTY
 #endif

-#if defined(linux) && !defined(TERMIO)
-# undef  TERMIOS
-# define TERMIO
+#if defined(linux)
+# define TERMIOS
+# undef  TERMIO
 # undef  SGTTY
 #endif
EOF

patch -p1 < openssl-musl.patch

./Configure linux-armv4 \
--prefix=/opt shared zlib zlib-dynamic \
-D_GNU_SOURCE -D_BSD_SOURCE \
--with-zlib-lib=$DEST/lib \
--with-zlib-include=$DEST/include

make CC=$CC
make CC=$CC install INSTALLTOP=$DEST OPENSSLDIR=$DEST/ssl

########## ##################################################################
# SQLITE # ##################################################################
########## ##################################################################

mkdir $SRC/sqlite && cd $SRC/sqlite
$WGET http://sqlite.org/2014/sqlite-autoconf-3080700.tar.gz
tar zxvf sqlite-autoconf-3080700.tar.gz
cd sqlite-autoconf-3080700

CC=$CC \
CXX=$CXX \
LDFLAGS=$LDFLAGS \
CPPFLAGS=$CPPFLAGS \
$CONFIGURE

$MAKE
make install DESTDIR=$BASE

########### #################################################################
# LIBXML2 # #################################################################
########### #################################################################

mkdir $SRC/libxml2 && cd $SRC/libxml2
$WGET ftp://xmlsoft.org/libxml2/libxml2-2.9.2.tar.gz
tar zxvf libxml2-2.9.2.tar.gz
cd libxml2-2.9.2

patch < $PATCHES/libxml2-pthread.patch

CC=$CC \
CXX=$CXX \
LDFLAGS=$LDFLAGS \
CPPFLAGS=$CPPFLAGS \
$CONFIGURE \
--with-zlib=$DEST \
--without-python

$MAKE LIBS="-lz"
make install DESTDIR=$BASE

########## ##################################################################
# C-ARES # ##################################################################
########## ##################################################################

mkdir $SRC/c-ares && cd $SRC/c-ares
$WGET http://c-ares.haxx.se/download/c-ares-1.10.0.tar.gz
tar zxvf c-ares-1.10.0.tar.gz
cd c-ares-1.10.0

CC=$CC \
CXX=$CXX \
CPPFLAGS=$CPPFLAGS \
LDFLAGS=$LDFLAGS \
$CONFIGURE

$MAKE
make install DESTDIR=$BASE

######### ###################################################################
# ARIA2 # ###################################################################
######### ###################################################################

mkdir $SRC/aria2 && cd $SRC/aria2
$WGET http://downloads.sourceforge.net/project/aria2/stable/aria2-1.18.8/aria2-1.18.8.tar.gz
tar zxvf aria2-1.18.8.tar.gz
cd aria2-1.18.8

CC=$CC \
CXX=$CXX \
LDFLAGS=$LDFLAGS \
CPPFLAGS=$CPPFLAGS \
$CONFIGURE \
--enable-libaria2 \
--without-libuv \
--without-appletls \
--without-gnutls \
--without-libnettle \
--without-libgmp \
--without-libgcrypt \
--without-libexpat \
--with-xml-prefix=$DEST \
ZLIB_CFLAGS="-I$DEST/include" \
ZLIB_LIBS="-L$DEST/lib" \
OPENSSL_CFLAGS="-I$DEST/include" \
OPENSSL_LIBS="-L$DEST/lib" \
SQLITE3_CFLAGS="-I$DEST/include" \
SQLITE3_LIBS="-L$DEST/lib" \
LIBCARES_CFLAGS="-I$DEST/include" \
LIBCARES_LIBS="-L$DEST/lib" \
ARIA2_STATIC=yes

$MAKE \
LIBS="-static -lz -lssl -lcrypto -lsqlite3 -lxml2 -lcares"

make install DESTDIR=$BASE/aria2
