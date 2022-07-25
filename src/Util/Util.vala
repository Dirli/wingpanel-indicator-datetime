/*
 * Copyright 2011-2019 elementary, Inc. (https://elementary.io)
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public
 * License as published by the Free Software Foundation; either
 * version 2 of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * General Public License for more details.
 *
 * You should have received a copy of the GNU General Public
 * License along with this program; if not, write to the
 * Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
 * Boston, MA 02110-1301 USA.
 *
 * Authored by: Corentin Noël <corentin@elementaryos.org>
 */

namespace DateTimeIndicator.Util {
    public static string w_time_format (int64 unix_time) {
        if (unix_time == 0) {
            return "-";
        }

        var datetime = new GLib.DateTime.from_unix_local (unix_time);
        var sys_setting = new GLib.Settings ("org.gnome.desktop.interface");

        return sys_setting.get_string ("clock-format") == "12h"
               ? datetime.format ("%I:%M")
               : datetime.format ("%R");
    }

    public GLib.DateTime get_start_of_month (owned GLib.DateTime? date = null) {
        if (date == null) {
            date = new GLib.DateTime.now_local ();
        }

        return new GLib.DateTime.local (date.get_year (), date.get_month (), 1, 0, 0, 0);
    }

    public GLib.DateTime strip_time (GLib.DateTime datetime) {
        return datetime.add_full (0, 0, 0, -datetime.get_hour (), -datetime.get_minute (), -datetime.get_second ());
    }

    /**
     * Say if an event lasts all day.
     */
    public bool is_the_all_day (GLib.DateTime dtstart, GLib.DateTime dtend) {
        var utc_start = dtstart.to_timezone (new GLib.TimeZone.utc ());
        var timespan = dtend.difference (dtstart);

        if (timespan % GLib.TimeSpan.DAY == 0 && utc_start.get_hour () == 0) {
            return true;
        } else {
            return false;
        }
    }

#if USE_EVO
    public Gtk.CssProvider? set_event_calendar_color (string color) {
        string style = """
            @define-color accent_color %s;
        """.printf (color);

        try {
            var style_provider = new Gtk.CssProvider ();
            style_provider.load_from_data (style, style.length);

            return style_provider;
        } catch (Error e) {
            critical ("Unable to set calendar color: %s", e.message);
        }

        return null;
    }

    /**
     * Gets the timezone of the given TimeType as a GLib.TimeZone.
     */
    public TimeZone timezone_from_ical (ICal.Time date) {
        if (date.is_date ()) {
            return new GLib.TimeZone.local ();
        }

        var tzid = date.get_tzid ();
        if (tzid == null) {
            // In libical, null tzid means floating time
            assert (date.get_timezone () == null);
            return new GLib.TimeZone.local ();
        }

        if (tzid != null) {
            /* Standard city names are usable directly by GLib, so we can bypass
             * the ICal scaffolding completely and just return a new
             * GLib.TimeZone here. This method also preserves all the timezone
             * information, like going in/out of daylight savings, which parsing
             * from UTC offset does not.
             * Note, this can't recover from failure, since GLib.TimeZone
             * constructor doesn't communicate failure information. This block
             * will always return a GLib.TimeZone, which will be UTC if parsing
             * fails for some reason.
             */
            var prefix = "/freeassociation.sourceforge.net/";
            return new GLib.TimeZone (tzid.has_prefix (prefix) ? tzid.offset (prefix.length) : tzid);
        }

        unowned ICal.Timezone? timezone = null;
        if (timezone == null && date.get_timezone () != null) {
            timezone = date.get_timezone ();
        }

        if (timezone == null) {
            return new GLib.TimeZone.local ();
        }

        // Get UTC offset and format for GLib.TimeZone constructor
        int is_daylight;
        int interval = timezone.get_utc_offset (date, out is_daylight);
        bool is_positive = interval >= 0;
        interval = interval.abs ();
        var hours = (interval / 3600);
        var minutes = (interval % 3600) / 60;
        var hour_string = "%s%02d:%02d".printf (is_positive ? "+" : "-", hours, minutes);

        return new GLib.TimeZone (hour_string);
    }

    /**
     * Converts the given ICal.Time to a DateTime.
     * XXX : Track next versions of evolution in order to convert ICal.Timezone to GLib.TimeZone with a dedicated function…
     */
    public GLib.DateTime ical_to_date_time (ICal.Time date) {
#if E_CAL_2_0
        int year, month, day, hour, minute, second;
        date.get_date (out year, out month, out day);
        date.get_time (out hour, out minute, out second);
        return new GLib.DateTime (timezone_from_ical (date), year, month, day, hour, minute, second);
#else
        return new GLib.DateTime (timezone_from_ical (date), date.year, date.month, date.day, date.hour, date.minute, date.second);
#endif
    }

    /*
     * Gee Utility Functions
     */

    /* Computes hash value for E.Source */
    public uint source_hash_func (E.Source key) {
        return key.dup_uid (). hash ();
    }

    /* Returns true if 'a' and 'b' are the same E.Source */
    public bool source_equal_func (E.Source a, E.Source b) {
        return a.dup_uid () == b.dup_uid ();
    }

    /* Returns true if 'a' and 'b' are the same ECal.Component */
    public bool calcomponent_equal_func (ECal.Component a, ECal.Component b) {
        return a.get_id ().equal (b.get_id ());
    }

    public int calcomponent_compare_func (ECal.Component? a, ECal.Component? b) {
        if (a == null && b != null) {
            return 1;
        } else if (b == null && a != null) {
            return -1;
        } else if (b == null && a == null) {
            return 0;
        }

        var a_id = a.get_id ();
        var b_id = b.get_id ();
        int res = GLib.strcmp (a_id.get_uid (), b_id.get_uid ());
        if (res == 0) {
            return GLib.strcmp (a_id.get_rid (), b_id.get_rid ());
        }

        return res;
    }

    public bool calcomp_is_on_day (ECal.Component comp, GLib.DateTime day) {
#if E_CAL_2_0
        unowned ICal.Timezone system_timezone = ECal.util_get_system_timezone ();
#else
        unowned ICal.Timezone system_timezone = ECal.Util.get_system_timezone ();
#endif

        var stripped_time = new GLib.DateTime.local (day.get_year (), day.get_month (), day.get_day_of_month (), 0, 0, 0);

        var selected_date_unix = stripped_time.to_unix ();
        var selected_date_unix_next = stripped_time.add_days (1).to_unix ();

        /* We want to be relative to the local timezone */
        unowned ICal.Component? icomp = comp.get_icalcomponent ();
        ICal.Time? start_time = icomp.get_dtstart ();
        ICal.Time? end_time = icomp.get_dtend ();
        time_t start_unix = start_time.as_timet_with_zone (system_timezone);
        time_t end_unix = end_time.as_timet_with_zone (system_timezone);

        /* If the selected date is inside the event */
        if (start_unix < selected_date_unix && selected_date_unix_next < end_unix) {
            return true;
        }

        /* If the event start before the selected date but finished in the selected date */
        if (start_unix < selected_date_unix && selected_date_unix < end_unix) {
            return true;
        }

        /* If the event start after the selected date but finished after the selected date */
        if (start_unix < selected_date_unix_next && selected_date_unix_next < end_unix) {
            return true;
        }

        /* If the event is inside the selected date */
        if (start_unix < selected_date_unix_next && selected_date_unix < end_unix) {
            return true;
        }

        return false;
    }
#endif

    public string wind_format (GWeather.SpeedUnit s_unit, double? speed, int wind_d) {
        if (speed == null) {
            return "no data";
        }

        string w_label = s_unit == GWeather.SpeedUnit.MS ? _("m/s") :
                         s_unit == GWeather.SpeedUnit.MPH ? _("mph") :
                         s_unit == GWeather.SpeedUnit.KPH ? _("kph") :
                         s_unit == GWeather.SpeedUnit.KNOTS ? _("knots") :
                         "unknown";

        string windformat = "%.1f %s".printf (speed, w_label);

        string[] arr = {"N", "NNE", "NE", "ENE", "E", "ESE", "SE", "SSE", "S", "SSW", "SW", "WSW", "W", "WNW", "NW", "NNW"};
        if (wind_d > -1 && wind_d < arr.length) {
            switch (arr[wind_d]) {
                case "N":
                case "NNE":
                case "NNW":
                    windformat += ", ↓";
                    break;
                case "NE":
                    windformat += ", ↙";
                    break;
                case "ENE":
                case "E":
                case "ESE":
                    windformat += ", ←";
                    break;
                case "SE":
                    windformat += ", ↖";
                    break;
                case "SSE":
                case "S":
                case "SSW":
                    windformat += ", ↑";
                    break;
                case "SW":
                    windformat += ", ↗";
                    break;
                case "WSW":
                case "W":
                case "WNW":
                        windformat += ", →";
                    break;
                case "NW":
                    windformat += ", ↘";
                    break;
            }
        }

        return windformat;
    }
}
