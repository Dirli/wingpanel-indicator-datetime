project (
  'datetime',
  'vala', 'c',
  version: '3.0.2'
)

i18n = import ('i18n')
gnome = import ('gnome')

gettext_name = meson.project_name () + '-indicator'

prefix = get_option ('prefix')
libdir = join_paths (prefix, get_option ('libdir'))

add_global_arguments ('-DGETTEXT_PACKAGE="@0@"'.format (gettext_name), language:'c')
add_project_arguments (['--vapidir', join_paths (meson.current_source_dir (), 'vapi')], language: 'vala')

gresource = gnome.compile_resources (
  'gresource',
  join_paths ('data', 'datetime.gresource.xml'),
  source_dir: 'data'
)

wingpanel_dep = dependency ('wingpanel')
wingpanel_indicatorsdir = wingpanel_dep.get_pkgconfig_variable ('indicatorsdir', define_variable: ['libdir', libdir])

gweather_dep = dependency ('gweather4', required: false)
if gweather_dep.found ()
  add_project_arguments ('--define=GWEATHER_40', language: 'vala')
else
  gweather_dep = dependency ('gweather-3.0')
  if gweather_dep.version () >= '40.0'
    add_project_arguments ('--define=GWEATHER_40', language: 'vala')
  endif
endif

deps = [
  dependency ('glib-2.0'),
  dependency ('gobject-2.0'),
  dependency ('granite'),
  dependency ('gtk+-3.0'),
  dependency ('libgeoclue-2.0', version: '>=2.6.0'),
  dependency ('libhandy-1'),
  gweather_dep,
  wingpanel_dep,
  meson.get_compiler ('vala').find_library ('posix')
]

opt_files = []

libecal_dep = dependency ('libecal-2.0', required: false)
if libecal_dep.found ()
  deps += dependency ('libical-glib')
  add_project_arguments ('--define=E_CAL_2_0', language: 'vala')
  add_project_arguments ('-DLIBICAL_GLIB_UNSTABLE_API=1', language: 'c')
else
  libecal_dep = dependency ('libecal-1.2', version: '>=3.8.0', required: false)
  if libecal_dep.found ()
    deps += dependency ('libical')
    add_project_arguments ('--vapidir', join_paths (meson.current_source_dir (), 'vapi'), language: 'vala')
  endif
endif

if libecal_dep.found ()
  deps += libecal_dep
  deps += dependency ('libedataserver-1.2')

  opt_files += files (
    'src/Widgets/EventRow.vala',
    'src/Widgets/EventsListBox.vala',
    'src/Services/EventsManager.vala',
  )
  add_project_arguments ('--define=USE_EVO', language: 'vala')
endif

shared_module (
  meson.project_name (),
  gresource,
  'src/Indicator.vala',
  'src/Util/DateIterator.vala',
  'src/Util/DateRange.vala',
  'src/Util/Util.vala',
  'src/Models/CalendarModel.vala',
  'src/Provider/Gweather.vala',
  'src/Services/GeoManager.vala',
  'src/Services/TimeManager.vala',
  'src/Services/WeatherManager.vala',
  'src/Widgets/CalendarDay.vala',
  'src/Widgets/CalendarGrid.vala',
  'src/Widgets/CalendarView.vala',
  'src/Widgets/PanelLabel.vala',
  'src/Widgets/WeatherGrid.vala',
  opt_files,
  c_args: [
    '-DGWEATHER_I_KNOW_THIS_IS_UNSTABLE',
  ],
  dependencies: deps,
  install: true,
  install_dir : wingpanel_indicatorsdir,
)

subdir ('data')
subdir ('po')

meson.add_install_script ('meson/post_install.py')
