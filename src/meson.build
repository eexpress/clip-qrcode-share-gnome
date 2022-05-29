clip_qrcode_share_sources = [
  'main.vala',
  'window.vala',
  'application.vala',
]

clip_qrcode_share_deps = [
  dependency('libadwaita-1', version: '>= 1.0'),
  meson.get_compiler('vala').find_library('posix'),
  # error: The namespace name `Posix' could not be found
  #  20 | using Posix;

]

gnome = import('gnome')

clip_qrcode_share_sources += gnome.compile_resources('clip_qrcode_share-resources',
  'clip_qrcode_share.gresource.xml',
  c_name: 'clip_qrcode_share'
)

executable('clip-qrcode-share', clip_qrcode_share_sources,
  vala_args: '--target-glib=2.50',  dependencies: clip_qrcode_share_deps,
  install: true,
)
