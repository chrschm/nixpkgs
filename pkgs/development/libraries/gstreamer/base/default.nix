{ stdenv, fetchurl, fetchpatch, lib
, pkgconfig, meson, ninja, gettext, gobject-introspection
, python3, gstreamer, orc, pango, libtheora
, libintl, libopus
, enableX11 ? stdenv.isLinux, libXv
, enableWayland ? stdenv.isLinux, wayland
, enableAlsa ? stdenv.isLinux, alsaLib
, enableCocoa ? false, darwin
, enableCdparanoia ? (!stdenv.isDarwin), cdparanoia }:

stdenv.mkDerivation rec {
  name = "gst-plugins-base-${version}";
  version = "1.14.4";

  meta = with lib; {
    description = "Base plugins and helper libraries";
    homepage = https://gstreamer.freedesktop.org;
    license = licenses.lgpl2Plus;
    platforms = platforms.unix;
    maintainers = with maintainers; [ matthewbauer ];
  };

  src = fetchurl {
    url = "${meta.homepage}/src/gst-plugins-base/${name}.tar.xz";
    sha256 = "0qbllw4kphchwhy4p7ivdysigx69i97gyw6q0rvkx1j81r4kjqfa";
  };

  outputs = [ "out" "dev" ];

  nativeBuildInputs = [ pkgconfig python3 gettext gobject-introspection ]

  # Broken meson with Darwin. Should hopefully be fixed soon. Tracking
  # in https://bugzilla.gnome.org/show_bug.cgi?id=781148.
  ++ lib.optionals (!stdenv.isDarwin) [ meson ninja ];

  # TODO How to pass these to Meson?
  configureFlags = [
    "--enable-x11=${if enableX11 then "yes" else "no"}"
    "--enable-wayland=${if enableWayland then "yes" else "no"}"
    "--enable-cocoa=${if enableCocoa then "yes" else "no"}"
  ]

  # Introspection fails on my MacBook currently
  ++ lib.optional stdenv.isDarwin "--disable-introspection";

  buildInputs = [ orc libtheora libintl libopus ]
    ++ lib.optional enableAlsa alsaLib
    ++ lib.optionals enableX11 [ libXv pango ]
    ++ lib.optional enableWayland wayland
    ++ lib.optional enableCocoa darwin.apple_sdk.frameworks.Cocoa
    ++ lib.optional enableCdparanoia cdparanoia;

  propagatedBuildInputs = [ gstreamer ];

  postPatch = ''
    patchShebangs .
  '';

  enableParallelBuilding = true;

  doCheck = false; # fails, wants DRI access for OpenGL

  patches = [
    (fetchpatch {
        url = "https://bug794856.bugzilla-attachments.gnome.org/attachment.cgi?id=370414";
        sha256 = "07x43xis0sr0hfchf36ap0cibx0lkfpqyszb3r3w9dzz301fk04z";
    })
    ./fix_pkgconfig_includedir.patch
    (fetchurl {
      url = "https://gitlab.freedesktop.org/gstreamer/gst-plugins-base/commit/f672277509705c4034bc92a141eefee4524d15aa.patch";
      name = "CVE-2019-9928.patch";
      sha256 = "0hz3lsq3ppmaf329sbyi05y1qniqfj9vlp2f3z918383pvrcms4i";
    })
  ];
}
