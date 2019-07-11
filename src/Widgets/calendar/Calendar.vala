/*
 * Copyright (c) 2011-2019 elementary, Inc. (https://elementary.io)
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
 */

namespace DateTime.Widgets {
    public class Calendar : Gtk.Grid {
        public signal void selection_changed (GLib.DateTime? new_date);
        public signal void day_double_click (GLib.DateTime date);

        private CalendarView cal;

        public GLib.DateTime? selected_date {
            get {
                return cal.selected_date;
            }
        }

        construct {
            var heading = new ControlHeader ();
            heading.margin = 6;

            cal = new CalendarView ();

            margin_start = margin_end = 10;
            orientation = Gtk.Orientation.VERTICAL;
            add (heading);
            add (cal);

            cal.selection_changed.connect ((date) => {
                selection_changed (date);
            });
            cal.on_event_add.connect ((date) => {
                show_date_in_maya (date);
                day_double_click (date);
            });
            heading.center_clicked.connect (() => {
                cal.today ();
            });
        }

        public void show_today () {
            cal.today ();
        }

        // TODO: As far as maya supports it use the Dbus Activation feature to run the calendar-app.
        public void show_date_in_maya (GLib.DateTime date) {
            var command = "io.elementary.calendar --show-day %s".printf (date.format ("%F"));

            try {
                var appinfo = AppInfo.create_from_commandline (command, null, AppInfoCreateFlags.NONE);
                appinfo.launch_uris (null, null);
            } catch (GLib.Error e) {
                var dialog = new Granite.MessageDialog.with_image_from_icon_name (
                    _("Unable To Launch Calendar"),
                    _("The program \"io.elementary.calendar\" may not be installed"),
                    "dialog-error"
                );
                dialog.show_error_details (e.message);
                dialog.run ();
                dialog.destroy ();
            }
        }
    }
}
