/*-
 * Copyright (c) 2011–2020 elementary, Inc. (https://elementary.io)
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 */

namespace DateTimeIndicator {
    public class Widgets.CalendarView : Gtk.Grid {
        public signal void day_double_click ();
        public signal void event_updates ();
        public signal void selection_changed (GLib.DateTime new_date);

        public GLib.DateTime? selected_date { get; private set; default = null;}
        public GLib.Settings settings { get; construct; }

        private Hdy.Carousel carousel;
        private uint position;
        private int rel_postion;
        private GLib.DateTime start_month;
        private Gtk.Label label;
        private bool showtoday;


        public CalendarView (GLib.Settings clock_settings) {
            Object (settings: clock_settings);
        }

        construct {
            label = new Gtk.Label (new GLib.DateTime.now_local ().format (_("%OB, %Y")));
            label.hexpand = true;
            label.margin_start = 6;
            label.xalign = 0;
            label.width_chars = 13;

            var provider = new Gtk.CssProvider ();
            provider.load_from_resource ("/io/elementary/desktop/wingpanel/datetime/ControlHeader.css");

            var label_style_context = label.get_style_context ();
            label_style_context.add_class ("header-label");
            label_style_context.add_provider (provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);

            var left_button = new Gtk.Button.from_icon_name ("pan-start-symbolic");
            var center_button = new Gtk.Button.from_icon_name ("office-calendar-symbolic");
            center_button.tooltip_text = _("Go to today's date");
            var right_button = new Gtk.Button.from_icon_name ("pan-end-symbolic");

            var box_buttons = new Gtk.Grid ();
            box_buttons.margin_end = 6;
            box_buttons.valign = Gtk.Align.CENTER;
            box_buttons.get_style_context ().add_class (Gtk.STYLE_CLASS_LINKED);
            box_buttons.add (left_button);
            box_buttons.add (center_button);
            box_buttons.add (right_button);

            var calmodel = Models.CalendarModel.get_default ();
            start_month = Util.get_start_of_month ();

            var center_grid = create_grid ();
            center_grid.set_range (calmodel.data_range, calmodel.month_start, selected_date);
            center_grid.update_weeks (calmodel.data_range.first_dt, calmodel.num_weeks);

            calmodel.change_month (-1);
            var left_grid = create_grid ();
            left_grid.set_range (calmodel.data_range, calmodel.month_start, selected_date);
            left_grid.update_weeks (calmodel.data_range.first_dt, calmodel.num_weeks);

            calmodel.change_month (2);
            var right_grid = create_grid ();
            right_grid.set_range (calmodel.data_range, calmodel.month_start, selected_date);
            right_grid.update_weeks (calmodel.data_range.first_dt, calmodel.num_weeks);
            calmodel.change_month (-1);

            carousel = new Hdy.Carousel () {
                interactive = true,
                expand = true,
                spacing = 15
            };

            carousel.add (left_grid);
            carousel.add (center_grid);
            carousel.add (right_grid);
            carousel.scroll_to (center_grid);

            position = 1;
            rel_postion = 0;
            showtoday = false;

            carousel.show_all ();

            column_spacing = 6;
            row_spacing = 6;
            margin_start = margin_end = 10;
            attach (label, 0, 0);
            attach (box_buttons, 1, 0);
            attach (carousel, 0, 1, 2);

            left_button.clicked.connect (() => {
                selected_date = selected_date.add_months (-1);
                carousel.switch_child ((int) carousel.get_position () - 1, carousel.get_animation_duration ());
            });

            right_button.clicked.connect (() => {
                selected_date = selected_date.add_months (1);
                carousel.switch_child ((int) carousel.get_position () + 1, carousel.get_animation_duration ());
            });

            center_button.clicked.connect (() => {
                show_today ();
            });

            carousel.page_changed.connect ((index) => {
                calmodel.change_month (-rel_postion);
                if (position > index) {
                    rel_postion--;
                    position--;
                } else if (position < index) {
                    rel_postion++;
                    position++;
                } else if (showtoday) {
                    showtoday = false;
                    rel_postion = 0;
                    position = (int) carousel.get_position ();
                    label.label = calmodel.month_start.format (_("%OB, %Y"));
                    return;
                } else {
                    calmodel.change_month (rel_postion);
                    return;
                }

                calmodel.change_month (rel_postion);
                // selected_date = null;
                selection_changed (selected_date);

                var selected_grid = carousel.get_children ().nth_data (position);
                if (selected_grid != null) {
                    ((Widgets.CalendarGrid) selected_grid).set_focus_to_day (selected_date);
                }

                /* creates a new Grid, when the Hdy.Carousel is on it's first/last page*/
                if (index + 1 == (int) carousel.get_n_pages ()) {
                    calmodel.change_month (1);
                    var grid = create_grid ();
                    grid.set_range (calmodel.data_range, calmodel.month_start, selected_date);
                    grid.update_weeks (calmodel.data_range.first_dt, calmodel.num_weeks);
                    carousel.add (grid);
                    calmodel.change_month (-1);

                } else if (index == 0) {
                    calmodel.change_month (-1);
                    var grid = create_grid ();
                    grid.set_range (calmodel.data_range, calmodel.month_start, selected_date);
                    grid.update_weeks (calmodel.data_range.first_dt, calmodel.num_weeks);
                    carousel.prepend (grid);
                    calmodel.change_month (1);
                    position++;
                }

                label.label = calmodel.month_start.format (_("%OB, %Y"));
            });
        }

        private Widgets.CalendarGrid create_grid () {
            var calendar_grid = new Widgets.CalendarGrid (settings);
            calendar_grid.show_all ();

            calendar_grid.on_event_add.connect ((date) => {
                if (date != null) {
                    show_date_in_maya (date);
                }
                day_double_click ();
            });

            calendar_grid.selection_changed.connect ((date, up) => {
                selected_date = date;
                if (up) {
                    selection_changed (date);
                }
            });

            calendar_grid.change_month.connect ((m_relative, date) => {
                selected_date = date;
                carousel.switch_child ((int) carousel.get_position () + (m_relative), carousel.get_animation_duration ());
            });

            return calendar_grid;
        }

        public void show_today () {
            var calmodel = Models.CalendarModel.get_default ();
            showtoday = true;
            var today = Util.strip_time (new GLib.DateTime.now_local ());
            var start = Util.get_start_of_month (today);
            selected_date = today;

            if (start.equal (start_month)) {
                position -= rel_postion;

                var selected_grid = carousel.get_children ().nth_data (position);
                if (selected_grid != null) {
                    ((Widgets.CalendarGrid) selected_grid).set_focus_to_today ();
                }

                carousel.switch_child (position, carousel.get_animation_duration ());
            } else {
                /*reset Carousel if center_child != the grid of the month of today*/
                carousel.no_show_all = true;
                foreach (unowned Gtk.Widget grid in carousel.get_children ()) {
                    carousel.remove (grid);
                }
                start_month = Util.get_start_of_month ();
                calmodel.month_start = start_month;
                var center_grid = create_grid ();
                center_grid.set_range (calmodel.data_range, calmodel.month_start, selected_date);
                center_grid.update_weeks (calmodel.data_range.first_dt, calmodel.num_weeks);
                center_grid.set_focus_to_today ();

                calmodel.change_month (-1);
                var left_grid = create_grid ();
                left_grid.set_range (calmodel.data_range, calmodel.month_start, selected_date);
                left_grid.update_weeks (calmodel.data_range.first_dt, calmodel.num_weeks);

                calmodel.change_month (2);
                var right_grid = create_grid ();
                right_grid.set_range (calmodel.data_range, calmodel.month_start, selected_date);
                right_grid.update_weeks (calmodel.data_range.first_dt, calmodel.num_weeks);
                calmodel.change_month (-1);

                carousel.add (left_grid);
                carousel.add (center_grid);
                carousel.add (right_grid);
                carousel.scroll_to (center_grid);
                label.label = calmodel.month_start.format (_("%OB, %Y"));
                carousel.no_show_all = false;
            }
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

#if USE_EVO
        public void add_event_dots (E.Source source, Gee.Collection<ECal.Component> events) {
            var selected_grid = carousel.get_children ().nth_data (position);
            if (selected_grid != null) {
                ((Widgets.CalendarGrid) selected_grid).add_event_dots (source, events);
            }
        }

        public void remove_event_dots (E.Source source, Gee.Collection<ECal.Component> events) {
            var selected_grid = carousel.get_children ().nth_data (position);
            if (selected_grid != null) {
                ((Widgets.CalendarGrid) selected_grid).remove_event_dots (source, events);
            }
        }
#endif
    }
}
