{ stdenv, fetchFromGitHub, fetchpatch, pkgconfig, libtool, curl
, python, munge, perl, pam, openssl, zlib
, ncurses, mysql, gtk2, lua, hwloc, numactl
, readline, freeipmi, libssh2, xorg, lz4
# enable internal X11 support via libssh2
, enableX11 ? true
}:

stdenv.mkDerivation rec {
  name = "slurm-${version}";
  version = "18.08.5.2";

  # N.B. We use github release tags instead of https://www.schedmd.com/downloads.php
  # because the latter does not keep older releases.
  src = fetchFromGitHub {
    owner = "SchedMD";
    repo = "slurm";
    # The release tags use - instead of .
    rev = "${builtins.replaceStrings ["."] ["-"] name}";
    sha256 = "0x1pdq58sdf0m28cai0lcyzvhhjl7l85gq324pwh8fi3zy2h0n4k";
  };

  outputs = [ "out" "dev" ];

  patches = [
    (fetchpatch {
      name = "CVE-2019-12838-prerequisite-1.patch";
      url = "https://github.com/SchedMD/slurm/commit/e8567e06be57190825bff737e5523c307da51530.patch";
      sha256 = "1sxllghnc8j5sh4md1lv3hdj3h3xag3ylqv3v00nhxfximgc74d6";
      excludes = [ "NEWS" ];
    })
    (fetchpatch {
      name = "CVE-2019-12838.patch";
      url = "https://github.com/SchedMD/slurm/commit/afa7d743f407c60a7c8a4bd98a10be32c82988b5.patch";
      sha256 = "017zskjr2yyphij61zws391znghmnh7r7zr21kjngqaixpjaark9";
      excludes = [ "NEWS" ];
    })
  ];

  prePatch = stdenv.lib.optional enableX11 ''
    substituteInPlace src/common/x11_util.c \
        --replace '"/usr/bin/xauth"' '"${xorg.xauth}/bin/xauth"'
  '';

  # nixos test fails to start slurmd with 'undefined symbol: slurm_job_preempt_mode'
  # https://groups.google.com/forum/#!topic/slurm-devel/QHOajQ84_Es
  # this doesn't fix tests completely at least makes slurmd to launch
  hardeningDisable = [ "bindnow" ];

  nativeBuildInputs = [ pkgconfig libtool ];
  buildInputs = [
    curl python munge perl pam openssl zlib
      mysql.connector-c ncurses gtk2 lz4
      lua hwloc numactl readline freeipmi
  ] ++ stdenv.lib.optionals enableX11 [ libssh2 xorg.xauth ];

  configureFlags = with stdenv.lib;
    [ "--with-freeipmi=${freeipmi}"
      "--with-hwloc=${hwloc.dev}"
      "--with-lz4=${lz4.dev}"
      "--with-munge=${munge}"
      "--with-ssl=${openssl.dev}"
      "--with-zlib=${zlib}"
      "--sysconfdir=/etc/slurm"
    ] ++ (optional (gtk2 == null)  "--disable-gtktest")
      ++ (optional enableX11 "--with-libssh2=${libssh2.dev}");


  preConfigure = ''
    patchShebangs ./doc/html/shtml2html.py
    patchShebangs ./doc/man/man2html.py
  '';

  postInstall = ''
    rm -f $out/lib/*.la $out/lib/slurm/*.la
  '';

  enableParallelBuilding = true;

  meta = with stdenv.lib; {
    homepage = http://www.schedmd.com/;
    description = "Simple Linux Utility for Resource Management";
    platforms = platforms.linux;
    license = licenses.gpl2;
    maintainers = with maintainers; [ jagajaga markuskowa ];
  };
}
