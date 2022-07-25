namespace DateTimeIndicator {
    public class Services.WeatherManager : GLib.Object {
        public signal void updated_today (WeatherStruct w, int64 sunrise, int64 sunset);
        public signal void updated_forecast ();
        public signal void changed_location (string current_loc);

        public uint timeout_id = 0;

        private Gee.ArrayList<WeatherStruct?> w_array;

        private GLib.NetworkMonitor network_monitor;
        private Services.GeoManager? geo_manager = null;
        private Provider.Gweather? weather_provider = null;

        private GLib.Settings w_settings;
        private GLib.DateTime sel_date;

        public WeatherManager () {
            if (GLib.SettingsSchemaSource.get_default ().lookup ("io.elementary.meteo", false) != null) {
                w_settings = new GLib.Settings ("io.elementary.meteo");
            }

            w_array = new Gee.ArrayList<WeatherStruct?> ();

            network_monitor = GLib.NetworkMonitor.get_default ();
        }

        public void init () {
            network_monitor.network_changed.connect (on_network_changed);

            on_network_changed (true);
        }

        private void on_network_changed (bool network_available) {
            if (network_monitor.get_connectivity () == NetworkConnectivity.FULL) {
                if (geo_manager == null) {
                    geo_manager = new Services.GeoManager ();
                    geo_manager.changed_location.connect (on_changed_location);
                    geo_manager.init ();
                } else {
                    start_watcher ();
                }

                // if (weather_provider == null) {
                //     on_changed_location (w_settings.get_double ("latitude"), w_settings.get_double ("longitude"));
                // }
            }
        }

        private void on_changed_location (double lat, double lon) {
            if (weather_provider == null) {
                weather_provider = new Provider.Gweather (lat, lon);
                weather_provider.updated_today.connect ((today_w, _sunrise, _sunset) => {
                    updated_today (today_w, _sunrise, _sunset);
                });
                weather_provider.updated_long.connect ((forecast_w) => {
                    w_array.clear ();
                    w_array.add_all (forecast_w);
                    updated_forecast ();
                });
            } else {
                weather_provider.update_location (lat, lon);
            }

            update_location ();
            start_watcher ();
        }

        public void update_location () {
            if (weather_provider != null) {
                changed_location (weather_provider.current_location_name ());
            }
        }

        public bool need_update (GLib.DateTime d) {
            return sel_date == null || !sel_date.equal (d);
        }

        public Gee.ArrayList<WeatherStruct?> forecast_on_date (GLib.DateTime d) {
            var req_forecast = new Gee.ArrayList<WeatherStruct?> ();

            sel_date = d;

            var sel_day = d.get_day_of_year ();
            w_array.@foreach ((w_iter) => {
                var datetime = new GLib.DateTime.from_unix_local (w_iter.date);
                var n_day = datetime.get_day_of_year ();
                if (n_day == sel_day) {
                    req_forecast.add (w_iter);
                }

                return n_day <= sel_day;
            });


            return req_forecast;
        }

        public bool fetch_data () {
            if (network_monitor.get_connectivity () != NetworkConnectivity.FULL || weather_provider == null) {
                return false;
            }

            weather_provider.update_forecast ();
            return true;
        }

        private void start_watcher () {
            stop_watcher ();

            fetch_data ();

            timeout_id = GLib.Timeout.add_seconds (3600, fetch_data);
        }

        private void stop_watcher () {
            if (timeout_id > 0) {
                GLib.Source.remove (timeout_id);
                timeout_id = 0;
            }
        }
    }
}
