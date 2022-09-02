symbolifier_sources = [
  'main.vala',
]

symbolifier_deps = [
  dependency('glib-2.0'),
  dependency('gobject-2.0'),
  dependency('gio-2.0'),
]

executable('symbolifier', symbolifier_sources,
  vala_args: '--target-glib=2.58',  dependencies: symbolifier_deps,
  install: true,
)
