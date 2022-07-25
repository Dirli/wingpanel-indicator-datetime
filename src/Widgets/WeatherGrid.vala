namespace DateTimeIndicator {
    public class Widgets.WeatherGrid : Gtk.Grid {
        private Gtk.Label city_value;
        private Gtk.Label temp_value;
        private Gtk.Label humidity_value;
        private Gtk.Label pressure_value;
        private Gtk.Label wind_value;
        private Gtk.Label sunrise_value;
        private Gtk.Label sunset_value;
        private Gtk.Label desc_value;
        private Gtk.Image w_icon;

        private Gtk.Label update_label;

        private Gtk.Box forecast_box;

        public WeatherGrid () {
            Object (row_spacing: 8,
                    column_spacing: 12,
                    halign: Gtk.Align.FILL,
                    margin_start: 12,
                    margin_top: 12,
                    margin_end: 12);
        }

        construct {
            city_value = new Gtk.Label (null);
            city_value.halign = Gtk.Align.START;
            city_value.get_style_context ().add_class (Granite.STYLE_CLASS_H2_LABEL);
            city_value.set_ellipsize (Pango.EllipsizeMode.END);

            desc_value = new Gtk.Label (null);
            desc_value.set_ellipsize (Pango.EllipsizeMode.END);
            desc_value.halign = Gtk.Align.START;

            temp_value = new Gtk.Label (null);
            temp_value.get_style_context ().add_class (Granite.STYLE_CLASS_H2_LABEL);
            temp_value.halign = Gtk.Align.CENTER;
            temp_value.valign = Gtk.Align.CENTER;

            w_icon = new Gtk.Image ();
            w_icon.valign = Gtk.Align.CENTER;

            sunrise_value = new Gtk.Label (null);

            var sunrise_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
            sunrise_box.halign = Gtk.Align.END;
            sunrise_box.add (sunrise_value);
            sunrise_box.add (new Gtk.Image.from_icon_name ("daytime-sunrise-symbolic", Gtk.IconSize.SMALL_TOOLBAR));

            sunset_value = new Gtk.Label (null);

            var sunset_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
            sunset_box.halign = Gtk.Align.END;
            sunset_box.add (sunset_value);
            sunset_box.add (new Gtk.Image.from_icon_name ("daytime-sunset-symbolic", Gtk.IconSize.SMALL_TOOLBAR));

            var sunstate_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 8) {
                hexpand = true,
                halign = Gtk.Align.FILL
            };
            sunstate_box.add (sunrise_box);
            sunstate_box.add (sunset_box);

            humidity_value = new Gtk.Label (null);
            pressure_value = new Gtk.Label (null);
            wind_value = new Gtk.Label (null);

            var wrap_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 18);
            wrap_box.halign = Gtk.Align.CENTER;
            wrap_box.add (wind_value);
            wrap_box.add (humidity_value);
            wrap_box.add (pressure_value);

            forecast_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 10) {
                halign = Gtk.Align.CENTER,
                margin_start = 6,
                margin_end = 6,
                margin_top = 6,
                margin_bottom = 12
            };

            var scrolled_window = new Gtk.ScrolledWindow (null, null);
            scrolled_window.set_policy (Gtk.PolicyType.AUTOMATIC, Gtk.PolicyType.NEVER);
            scrolled_window.add (forecast_box);

            update_label = new Gtk.Label (null);
            update_label.halign = Gtk.Align.END;

            attach (city_value,      0, 0, 3);
            attach (desc_value,      0, 1, 3);
            attach (temp_value,      0, 2);
            attach (w_icon,          1, 2);
            attach (sunstate_box,    2, 2);
            attach (wrap_box,        0, 3, 3);
            attach (scrolled_window, 0, 4, 3);
            attach (update_label,    0, 5, 3);
        }

        public void update_city (string s) {
            city_value.set_label (s);
        }

        public void update_sun_state (int64 rise_unix, int64 set_unix) {
            sunrise_value.label = Util.w_time_format (rise_unix);
            sunset_value.label = Util.w_time_format (set_unix);
        }

        public void update_today (WeatherStruct w) {
            w_icon.set_from_icon_name (w.icon_name + "-symbolic", Gtk.IconSize.DND);
            temp_value.set_label (w.temp);

            humidity_value.set_label (w.humidity);
            pressure_value.set_label (w.pressure);
            wind_value.set_label (w.wind);
            desc_value.set_label (w.description);

            update_label.label = _("Last update") + ": " + Util.w_time_format (w.date);
        }

        public void add_forecast_item (WeatherStruct w) {
            Gtk.Box hour_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 6);
            hour_box.halign = Gtk.Align.CENTER;
            hour_box.add (new Gtk.Label (w.temp));
            hour_box.add (new Gtk.Image.from_icon_name (w.icon_name, Gtk.IconSize.LARGE_TOOLBAR));
            hour_box.add (new Gtk.Label (Util.w_time_format (w.date)));

            forecast_box.add (hour_box);
        }

        public void show_forecast () {
            forecast_box.show_all ();
        }

        public void clear_forecast () {
            foreach (unowned Gtk.Widget w_box in forecast_box.get_children ()) {
                forecast_box.remove (w_box);
            }

            forecast_box.hide ();
        }
    }
}
