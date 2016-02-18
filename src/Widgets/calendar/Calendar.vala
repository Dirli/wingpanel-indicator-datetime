/*
 * Copyright (c) 2011-2016 elementary Developers (https://launchpad.net/elementary)
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
 * Free Software Foundation, Inc., 59 Temple Place - Suite 330,
 * Boston, MA 02111-1307, USA.
 */

namespace DateTime.Widgets {
    public class Calendar : Gtk.Box {
        private const string CALENDAR_EXEC = "/usr/bin/maya-calendar";

        ControlHeader heading;
        CalendarView cal;
        public signal void selection_changed (GLib.DateTime new_date);
        public signal void day_double_click (GLib.DateTime date);

        public GLib.DateTime? selected_date { get {
                return cal.selected_date;
            } set {
            }}

        public Calendar () {
            Object (orientation: Gtk.Orientation.VERTICAL, halign: Gtk.Align.CENTER, valign: Gtk.Align.CENTER, can_focus: false);
            this.margin_start = 10;
            this.margin_end = 10;
            heading = new ControlHeader ();
            cal = new CalendarView ();
            cal.selection_changed.connect ((date) => {
                selection_changed (date);
            });
            cal.on_event_add.connect ((date) => {
                show_date_in_maya (date);
                day_double_click (date);
            });
            heading.left_clicked.connect (() => {
                CalendarModel.get_default ().change_month (-1);
            });
            heading.right_clicked.connect (() => {
                CalendarModel.get_default ().change_month (1);
            });
            heading.center_clicked.connect (() => {
                cal.today ();
            });
            add (heading);
            add (cal);
        }

        public void show_today () {
            cal.today ();
        }

        // TODO: As far as maya supports it use the Dbus Activation feature to run the calendar-app.
        public void show_date_in_maya (GLib.DateTime date) {
            int selected_year, selected_month, selected_day;
            selected_year = date.get_year ();
            selected_month = date.get_month ();
            selected_day= date.get_day_of_month ();

            var parameter_string = @" --show-day $selected_day/$selected_month/$selected_year";
            var command = CALENDAR_EXEC + parameter_string;

            var cmd = new Granite.Services.SimpleCommand ("/usr/bin", command);
            cmd.run ();
        }

        public override bool draw (Cairo.Context cr) {
            base.draw (cr);
            Gtk.Allocation size;
            cal.get_allocation (out size);
            cr.set_source_rgba (0.0, 0.0, 0.0, 0.25);
            cr.set_line_width (1.0);
            int y = 59;
            int height = size.height - 25;
            cr.move_to (4.5, y + 0.5);
            cr.line_to (size.width - 4.5, y + 0.5);
            cr.curve_to (size.width - 4.5, y + 0.5, size.width - 0.5, y + 0.5, size.width - 0.5, y + 4.5);
            cr.line_to (size.width - 0.5, y + height - 4.5);
            cr.curve_to (size.width - 0.5, y + height - 4.5, size.width - 0.5, y + height - 0.5, size.width - 4.5, y + height - 0.5);
            cr.line_to (4.5, y + height - 0.5);
            cr.curve_to (4.5, y + height - 0.5, 0.5, y + height - 0.5, 0.5, y + height - 4.5);
            cr.line_to (0.5, y + 4.5);
            cr.curve_to (0.5, y + 4.5, 0.5, y + 0.5, 4.5, y + 0.5);
            cr.stroke ();

            return false;
        }
    }
}