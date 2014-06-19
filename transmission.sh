#!/bin/bash

set -e
set -x

mkdir ~/transmission && cd ~/transmission

BASE=`pwd`
SRC=$BASE/src
WGET="wget --prefer-family=IPv4"
DEST=$BASE/opt
LDFLAGS="-L$DEST/lib -Wl,--gc-sections"
CPPFLAGS="-I$DEST/include"
CFLAGS="-mtune=mips32 -mips32 -ffunction-sections -fdata-sections"
CXXFLAGS=$CFLAGS
CONFIGURE="./configure --prefix=/opt --host=mipsel-linux"
MAKE="make -j`nproc`"

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
CFLAGS=$CFLAGS \
CXXFLAGS=$CXXFLAGS \
CROSS_PREFIX=mipsel-linux- \
./configure \
--prefix=/opt

$MAKE
make install DESTDIR=$BASE

########### #################################################################
# OPENSSL # #################################################################
########### #################################################################

mkdir -p $SRC/openssl && cd $SRC/openssl
$WGET http://www.openssl.org/source/openssl-1.0.1h.tar.gz
tar zxvf openssl-1.0.1h.tar.gz
cd openssl-1.0.1h

cat << "EOF" > openssl.patch
--- Configure_orig      2013-11-19 11:32:38.755265691 -0700
+++ Configure   2013-11-19 11:31:49.749650839 -0700
@@ -402,6 +402,7 @@ my %table=(
 "linux-alpha+bwx-gcc","gcc:-O3 -DL_ENDIAN -DTERMIO::-D_REENTRANT::-ldl:SIXTY_FOUR_BIT_LONG RC4_CHAR RC4_CHUNK DES_RISC1 DES_UNROLL:${alpha_asm}:dlfcn:linux-shared:-fPIC::.so.\$(SHLIB_MAJOR).\$(SHLIB_MINOR)",
 "linux-alpha-ccc","ccc:-fast -readonly_strings -DL_ENDIAN -DTERMIO::-D_REENTRANT:::SIXTY_FOUR_BIT_LONG RC4_CHUNK DES_INT DES_PTR DES_RISC1 DES_UNROLL:${alpha_asm}",
 "linux-alpha+bwx-ccc","ccc:-fast -readonly_strings -DL_ENDIAN -DTERMIO::-D_REENTRANT:::SIXTY_FOUR_BIT_LONG RC4_CHAR RC4_CHUNK DES_INT DES_PTR DES_RISC1 DES_UNROLL:${alpha_asm}",
+"linux-mipsel", "gcc:-DL_ENDIAN -DTERMIO -O3 -mtune=mips32 -mips32 -fomit-frame-pointer -Wall::-D_REENTRANT::-ldl:BN_LLONG RC4_CHAR RC4_CHUNK DES_INT DES_UNROLL BF_PTR:${mips32_asm}:o32:dlfcn:linux-shared:-fPIC::.so.\$(SHLIB_MAJOR).\$(SHLIB_MINOR)",

 # Android: linux-* but without -DTERMIO and pointers to headers and libs.
 "android","gcc:-mandroid -I\$(ANDROID_DEV)/include -B\$(ANDROID_DEV)/lib -O3 -fomit-frame-pointer -Wall::-D_REENTRANT::-ldl:BN_LLONG RC4_CHAR RC4_CHUNK DES_INT DES_UNROLL BF_PTR:${no_asm}:dlfcn:linux-shared:-fPIC::.so.\$(SHLIB_MAJOR).\$(SHLIB_MINOR)",
EOF

patch < openssl.patch

./Configure linux-mipsel \
-ffunction-sections -fdata-sections -Wl,--gc-sections \
--prefix=/opt shared zlib \
--with-zlib-lib=$DEST/lib \
--with-zlib-include=$DEST/include

make CC=mipsel-linux-gcc AR="mipsel-linux-ar r" RANLIB=mipsel-linux-ranlib
make install CC=mipsel-linux-gcc AR="mipsel-linux-ar r" RANLIB=mipsel-linux-ranlib INSTALLTOP=$DEST OPENSSLDIR=$DEST/ssl

########### #################################################################
# GETTEXT # #################################################################
########### #################################################################

mkdir $SRC/gettext && cd $SRC/gettext
$WGET http://ftp.gnu.org/pub/gnu/gettext/gettext-0.19.1.tar.gz
tar zxvf gettext-0.19.1.tar.gz
cd gettext-0.19.1

$WGET https://raw.github.com/lancethepants/tomatoware/master/patches/spawn.patch
patch -p1 < spawn.patch

LDFLAGS=$LDFLAGS \
CPPFLAGS=$CPPFLAGS \
CFLAGS=$CFLAGS \
CXXFLAGS=$CXXFLAGS \
$CONFIGURE \
--enable-static \
--disable-shared

$MAKE
make install DESTDIR=$BASE

######## ####################################################################
# CURL # ####################################################################
######## ####################################################################

mkdir $SRC/curl && cd $SRC/curl
$WGET http://curl.haxx.se/download/curl-7.37.0.tar.gz
tar zxvf curl-7.37.0.tar.gz
cd curl-7.37.0

LDFLAGS=$LDFLAGS \
CPPFLAGS=$CPPFLAGS \
CFLAGS=$CFLAGS \
CXXFLAGS=$CXXFLAGS \
$CONFIGURE \
--with-ca-path=/opt/ssl/certs \
--enable-static \
--disable-shared

$MAKE
make install DESTDIR=$BASE

mkdir -p $DEST/ssl/certs
cd $DEST/ssl/certs
curl http://curl.haxx.se/ca/cacert.pem | awk 'split_after==1{n++;split_after=0} /-----END CERTIFICATE-----/ {split_after=1} {print > "cert" n ".pem"}'
c_rehash .

############ ################################################################
# LIBEVENT # ################################################################
############ ################################################################

mkdir $SRC/libevent && cd $SRC/libevent
$WGET https://github.com/downloads/libevent/libevent/libevent-2.0.21-stable.tar.gz
tar zxvf libevent-2.0.21-stable.tar.gz
cd libevent-2.0.21-stable

LDFLAGS=$LDFLAGS \
CPPFLAGS=$CPPFLAGS \
CFLAGS=$CFLAGS \
CXXFLAGS=$CXXFLAGS \
$CONFIGURE \
--enable-static \
--disable-shared

$MAKE
make install DESTDIR=$BASE

################ ############################################################
# TRANSMISSION # ############################################################
################ ############################################################

mkdir $SRC/transmission && cd $SRC/transmission
$WGET http://download.transmissionbt.com/files/transmission-2.83.tar.xz
tar xvJf transmission-2.83.tar.xz
cd transmission-2.83

LIBEVENT_CFLAGS="-I$DEST/include" \
LIBEVENT_LIBS=$DEST/lib/libevent.la \
LDFLAGS=$LDFLAGS \
CPPFLAGS=$CPPFLAGS \
CFLAGS=$CFLAGS \
CXXFLAGS=$CXXFLAGS \
$CONFIGURE \
--enable-lightweight

make LDFLAGS="-zmuldefs" LIBS="-all-static -ldl"
make install DESTDIR=$BASE/transmission
