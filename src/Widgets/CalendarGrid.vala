/*
 * Copyright 2011–2019 elementary, Inc. (https://elementary.io)
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
 * Authored by: Maxwell Barvian
 *              Corentin Noël <corentin@elementaryos.org>
 */

namespace DateTimeIndicator {
/**
 * Represents the entire date grid as a table.
 */
    public class Widgets.CalendarGrid : Gtk.Grid {
        public Util.DateRange grid_range { get; private set; }

        /*
         * Event emitted when the day is double clicked or the ENTER key is pressed.
         */
        public signal void on_event_add (GLib.DateTime date);

        public signal void selection_changed (GLib.DateTime new_date);

        private Gee.HashMap<uint, Widgets.CalendarDay> data;
        private Widgets.CalendarDay selected_gridday;
        private Gtk.Label[] header_labels;
        private Gtk.Revealer[] week_labels;

        construct {
            header_labels = new Gtk.Label[7];
            for (int c = 0; c < 7; c++) {
                header_labels[c] = new Gtk.Label (null);
                header_labels[c].get_style_context ().add_class (Granite.STYLE_CLASS_H4_LABEL);

                attach (header_labels[c], c + 2, 0);
            }

            var week_sep = new Gtk.Separator (Gtk.Orientation.VERTICAL);
            week_sep.margin_start = 9;
            week_sep.margin_end = 3;

            var week_sep_revealer = new Gtk.Revealer ();
            week_sep_revealer.transition_type = Gtk.RevealerTransitionType.SLIDE_LEFT;
            week_sep_revealer.add (week_sep);

            hexpand = true;
            attach (week_sep_revealer, 1, 1, 1, 6);

            Indicator.settings.bind ("show-weeks", week_sep_revealer, "reveal-child", GLib.SettingsBindFlags.DEFAULT);

            data = new Gee.HashMap<uint, Widgets.CalendarDay> ();
            events |= Gdk.EventMask.SCROLL_MASK;
            events |= Gdk.EventMask.SMOOTH_SCROLL_MASK;
        }

        private void on_day_focus_in (Widgets.CalendarDay day) {
            debug ("on_day_focus_in %s", day.date.to_string ());
            if (selected_gridday != null) {
                selected_gridday.set_selected (false);
            }

            var selected_date = day.date;
            selected_gridday = day;
            day.set_selected (true);
            day.set_state_flags (Gtk.StateFlags.FOCUSED, false);
            selection_changed (selected_date);
            var calmodel = Models.CalendarModel.get_default ();
            var date_month = selected_date.get_month () - calmodel.month_start.get_month ();
            var date_year = selected_date.get_year () - calmodel.month_start.get_year ();

            if (date_month != 0 || date_year != 0) {
                calmodel.change_month (date_month);
                calmodel.change_year (date_year);
            }
        }

        public void set_focus_to_today () {
            if (grid_range == null) {
                return;
            }
            Gee.List<GLib.DateTime> dates = grid_range.to_list ();
            for (int i = 0; i < dates.size; i++) {
                var date = dates[i];
                Widgets.CalendarDay? day = data[day_hash (date)];
                if (day != null && day.name == "today") {
                    day.grab_focus_force ();
                    return;
                }
            }
        }

        /**
         * Sets the given range to be displayed in the grid. Note that the number of days
         * must remain the same.
         */
        public void set_range (Util.DateRange new_range, GLib.DateTime month_start) {
            var today = new GLib.DateTime.now_local ();

            Gee.List<GLib.DateTime> old_dates;

            if (grid_range == null) {
                old_dates = new Gee.ArrayList<GLib.DateTime> ();
            } else {
                old_dates = grid_range.to_list ();
            }

            var new_dates = new_range.to_list ();

            var data_new = new Gee.HashMap<uint, Widgets.CalendarDay> ();

            /* Assert that a valid number of weeks should be displayed */
            assert (new_dates.size % 7 == 0);

            /* Create new widgets for the new range */

            var date = Util.strip_time (today);
            date = date.add_days (Models.CalendarModel.get_default ().week_starts_on - date.get_day_of_week ());
            foreach (var label in header_labels) {
                label.label = date.format ("%a");
                date = date.add_days (1);
            }

            int i = 0;
            int col = 0, row = 1;

            for (i = 0; i < new_dates.size; i++) {
                var new_date = new_dates[i];
                Widgets.CalendarDay day;

                if (i < old_dates.size) {
                    /* A widget already exists for this date, just change it */

                    var old_date = old_dates[i];
                    day = update_day (data[day_hash (old_date)], new_date, today, month_start);
                } else {
                    /* Still update_day to get the color of etc. right */
                    day = update_day (new Widgets.CalendarDay (new_date), new_date, today, month_start);
                    day.on_event_add.connect ((date) => on_event_add (date));
                    day.scroll_event.connect ((event) => { scroll_event (event); return false; });
                    day.focus_in_event.connect ((event) => {
                        on_day_focus_in (day);

                        return false;
                    });

                    attach (day, col + 2, row);
                    day.show_all ();
                }

                col = (col + 1) % 7;
                row = (col == 0) ? row + 1 : row;
                data_new.set (day_hash (new_date), day);
            }

            /* Destroy the widgets that are no longer used */
            while (i < old_dates.size) {
                /* There are widgets remaining that are no longer used, destroy them */
                var old_date = old_dates[i];
                var old_day = data.get (day_hash (old_date));

                old_day.destroy ();
                i++;
            }

            data.clear ();
            data.set_all (data_new);

            grid_range = new_range;
        }

        /**
         * Updates the given CalendarDay so that it shows the given date. Changes to its style etc.
         */
        private Widgets.CalendarDay update_day (Widgets.CalendarDay day, GLib.DateTime new_date, GLib.DateTime today, GLib.DateTime month_start) {
            update_today_style (day, new_date, today);
            if (new_date.get_month () == month_start.get_month ()) {
                day.sensitive_container (true);
            } else {
                day.sensitive_container (false);
            }

            day.date = new_date;

            return day;
        }

        public void update_weeks (GLib.DateTime date, int nr_of_weeks) {
            if (week_labels != null) {
                foreach (unowned Gtk.Widget widget in week_labels) {
                    widget.destroy ();
                }
            }

            var next = date;
            // Find the beginning of the week which is apparently always a monday
            int days_to_add = (8 - next.get_day_of_week ()) % 7;
            next = next.add_days (days_to_add);

            week_labels = new Gtk.Revealer[nr_of_weeks];
            for (int c = 0; c < nr_of_weeks; c++) {
                var week_label = new Gtk.Label (next.get_week_of_year ().to_string ());
                week_label.margin_bottom = 6;
                week_label.width_chars = 2;
                week_label.get_style_context ().add_class (Granite.STYLE_CLASS_H4_LABEL);

                week_labels[c] = new Gtk.Revealer ();
                week_labels[c].transition_type = Gtk.RevealerTransitionType.SLIDE_LEFT;
                week_labels[c].add (week_label);
                week_labels[c].show_all ();

                Indicator.settings.bind ("show-weeks", week_labels[c], "reveal-child", GLib.SettingsBindFlags.DEFAULT);

                attach (week_labels[c], 0, c + 1);

                next = next.add_weeks (1);
            }
        }

        public void update_today () {
            if (grid_range == null) return;
            Gee.List<GLib.DateTime> dates = grid_range.to_list ();
            var today = new GLib.DateTime.now_local ();

            int i = 0;
            for (i = 0; i < dates.size; i++) {
                var date = dates[i];
                Widgets.CalendarDay? day = data[day_hash (date)];
                if (day == null) return;
                update_today_style (day, date, today);
            }
        }

        private void update_today_style (Widgets.CalendarDay day, GLib.DateTime date, GLib.DateTime today) {
            if (date.get_day_of_year () == today.get_day_of_year () && date.get_year () == today.get_year ()) {
                day.name = "today";
                day.get_style_context ().add_class (Granite.STYLE_CLASS_ACCENT);
                day.set_receives_default (true);
                day.show_all ();
            } else if (day.name == "today") {
                day.name = "";
                day.get_style_context ().remove_class (Granite.STYLE_CLASS_ACCENT);
                day.set_receives_default (false);
                day.show_all ();
            }
        }

        private uint day_hash (GLib.DateTime date) {
            return date.get_year () * 10000 + date.get_month () * 100 + date.get_day_of_month ();
        }

#if USE_EVO
        public void add_event_dots (E.Source source, Gee.Collection<ECal.Component> events) {
            foreach (var component in events) {
                unowned ICal.Component? icomp = component.get_icalcomponent ();
                ICal.Time? start_time = icomp.get_dtstart ();
                time_t start_unix = start_time.as_timet ();
                var t = new DateTime.from_unix_utc (start_unix);
                var d_hash = day_hash (t);
                if (data.has_key (d_hash)) {
                    data[d_hash].add_dots (source, component.get_icalcomponent ());
                }
            }
        }

        public void remove_event_dots (E.Source source, Gee.Collection<ECal.Component> events) {
            foreach (var component in events) {
                unowned ICal.Component ical = component.get_icalcomponent ();
                var event_uid = ical.get_uid ();

                ICal.Time? start_time = ical.get_dtstart ();
                time_t start_unix = start_time.as_timet ();
                var t = new DateTime.from_unix_utc (start_unix);
                var d_hash = day_hash (t);
                if (data.has_key (d_hash)) {
                    data[d_hash].remove_dots (event_uid);
                }
            }
        }
#endif
    }
}
