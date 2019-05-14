#!/bin/bash
# -*- mode: shell-script; indent-tabs-mode: nil; sh-basic-offset: 4; -*-
# ex: ts=8 sw=4 sts=4 et filetype=sh

check() {
    return 255
}

depends() {
    return 0
}

installkernel() {
    local _fipsmodules _mod i _bootfstype

    if [[ -f "${srcmods}/modules.fips" ]]; then
        _fipsmodules="$(cat "${srcmods}/modules.fips")"
    else
        _fipsmodules="aead aes_generic aes-x86_64 ansi_cprng arc4 blowfish camellia cast6 cbc ccm "
        _fipsmodules+="chainiv crc32c crct10dif_generic cryptomgr crypto_null ctr cts deflate des des3_ede dm-crypt dm-mod drbg "
        _fipsmodules+="ecb eseqiv fcrypt gcm ghash_generic hmac khazad lzo md4 md5 michael_mic rmd128 "
        _fipsmodules+="rmd160 rmd256 rmd320 rot13 salsa20 seed seqiv serpent sha1 sha224 sha256 sha256_generic "
        _fipsmodules+="aes_s390 des_s390 prng sha256_s390 sha_common des_check_key sha1_s390 sha512_s390 "
        _fipsmodules+="sha384 sha512 sha512_generic tea tnepres twofish wp256 wp384 wp512 xeta xtea xts zlib cmac authenc "
    fi

    mkdir -m 0755 -p "${initdir}/etc/modprobe.d"

    for _mod in $_fipsmodules tcrypt; do
        if hostonly='' instmods -c -s $_mod; then
            echo $_mod >> "${initdir}/etc/fipsmodules"
            echo "blacklist $_mod" >> "${initdir}/etc/modprobe.d/fips.conf"
            for i in $(modprobe --resolve-alias $_mod 2>/dev/null); do
                [[ $i == $_mod ]] && continue
                echo "blacklist $i" >> "${initdir}/etc/modprobe.d/fips.conf"
            done
        fi
    done

    # with hostonly_default_device fs module for /boot is not installed by default
    if [[ $hostonly ]] && [[ "$hostonly_default_device" == "no" ]]; then
        _bootfstype=$(find_mp_fstype /boot)
        if [[ -n "$_bootfstype" ]]; then
            hostonly='' instmods $_bootfstype
        else
            dwarning "Can't determine fs type for /boot, FIPS check may fail."
        fi
    fi
}

install() {
    local _dir
    inst_hook pre-mount 01 "$moddir/fips-boot.sh"
    inst_hook pre-pivot 01 "$moddir/fips-noboot.sh"
    inst_hook pre-udev 01 "$moddir/fips-load-crypto.sh"
    inst_script "$moddir/fips.sh" /sbin/fips.sh

    inst_multiple sha512hmac rmmod insmod mount uname umount fipscheck

    inst_libdir_file libsoftokn3.so libsoftokn3.so \
        libsoftokn3.chk libfreebl3.so libfreebl3.chk \
        libssl.so 'hmaccalc/sha512hmac.hmac' libssl.so.10 \
        libfreeblpriv3.so libfreeblpriv3.chk

    inst_multiple -o prelink
    inst_simple /etc/system-fips
}

