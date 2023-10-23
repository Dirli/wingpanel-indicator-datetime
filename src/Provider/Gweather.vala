namespace DateTimeIndicator {
    public class Provider.Gweather : GLib.Object {
        public signal void updated_today (WeatherStruct w, int64 sunrise, int64 sunset);
        public signal void updated_long (Gee.ArrayList<WeatherStruct?> f);

        public double latitude { get; construct set; }
        public double longitude { get; construct set; }

        public int64 sunrise { get; set; default = 0; }
        public int64 sunset { get; set; default = 0; }

        private GWeather.Info gweather_info;

        public Gweather (double lat, double lon) {
            Object (latitude: lat,
                    longitude: lon);
        }

        construct {
            var gweather_location = GWeather.Location.get_world ();
            gweather_location = gweather_location.find_nearest_city (latitude, longitude);

            gweather_info = new GWeather.Info (gweather_location);
#if GWEATHER_40
			gweather_info.set_application_id ("org.pantheon.weather");
            gweather_info.set_contact_info ("litandrej85@gmail.com");
			gweather_info.set_enabled_providers (GWeather.Provider.METAR | GWeather.Provider.MET_NO | GWeather.Provider.OWM);
#else
			gweather_info.set_enabled_providers (GWeather.Provider.ALL);
#endif
            
            gweather_info.updated.connect (parse_response);
        }

        public void update_forecast () {
            gweather_info.update ();
        }

        public void update_location (double lat, double lon) {
            latitude = lat;
            longitude = lon;

            var new_location = GWeather.Location.get_world ();
            new_location = new_location.find_nearest_city (latitude, longitude);

            gweather_info.set_location (new_location);
        }

        private void parse_response () {
            if (!gweather_info.is_valid ()) {
                return;
            }

            parse_today_forecast ();
            parse_long_forecast ();
        }

        public string current_location_name () {
            return gweather_info.get_location_name ();
        }

        private void parse_today_forecast () {
            ulong sunrise_unix_val;
            if (gweather_info.get_value_sunrise (out sunrise_unix_val)) {
                sunrise = sunrise_unix_val;
            }

            ulong sunset_unix_val;
            if (gweather_info.get_value_sunset (out sunset_unix_val)) {
                sunset = sunset_unix_val;
            }

            WeatherStruct weather_struct = {};

            weather_struct.icon_name = gweather_info.get_symbolic_icon_name ();
            weather_struct.description = gweather_info.get_sky ();
            weather_struct.pressure = gweather_info.get_pressure ();
            weather_struct.humidity = gweather_info.get_humidity ();
            weather_struct.wind = gweather_info.get_wind ();
            weather_struct.temp = gweather_info.get_temp_summary ();

            double w_speed;
            GWeather.WindDirection w_direction;
            if (gweather_info.get_value_wind (GWeather.SpeedUnit.MS, out w_speed, out w_direction)) {
                weather_struct.wind = Util.wind_format (GWeather.SpeedUnit.MS, w_speed, w_direction - 1);
            }

            long update_val;
            if (gweather_info.get_value_update (out update_val)) {
                weather_struct.date = update_val;
                updated_today (weather_struct, sunrise, sunset);
            }
        }

        private void parse_long_forecast () {
            var forecast_array = new Gee.ArrayList<WeatherStruct?> ();

            gweather_info.get_forecast_list ().@foreach ((info_iter) => {
                long iter_date;
                if (info_iter.get_value_update (out iter_date)) {
                    WeatherStruct w_struct = {};

                    w_struct.date = iter_date;
                    w_struct.icon_name = info_iter.get_symbolic_icon_name ();
                    w_struct.temp = info_iter.get_temp_summary ();

                    forecast_array.add (w_struct);
                }
            });

            updated_long (forecast_array);
        }
    }
}
