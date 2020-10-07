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

        public Models.CalendarModel current_model {get; private set;}
        private Hdy.Carousel carousel;
        private Gtk.Label label;

        public CalendarView (GLib.Settings clock_settings) {
            Object (settings: clock_settings,
                    column_spacing: 6,
                    row_spacing: 6,
                    margin_start: 10,
                    margin_end: 10);
        }

        construct {
            // label = new Gtk.Label (new GLib.DateTime.now_local ().format (_("%OB, %Y")));
            label = new Gtk.Label ("");
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

            carousel = new Hdy.Carousel () {
                interactive = true,
                expand = true,
                spacing = 15
            };

            init_default_carousel ();

            carousel.show_all ();

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
                var selected_grid = carousel.get_children ().nth_data (index);
                if (selected_grid == null) {
                    return;
                }

                var old_month = current_model.month_start;

                current_model = ((Widgets.CalendarGrid) selected_grid).model;

                label.label = current_model.month_start.format (_("%OB, %Y"));

                var current_month = current_model.month_start.get_month ();
                if (selected_date.get_month () != current_month) {
                    int inc = 0;
                    if (selected_date.add_months (1).get_month () == current_month) {
                        inc = 1;
                    } else if (selected_date.add_months (-1).get_month () == current_month) {
                        inc = -1;
                    }

                    if (inc != 0) {
                        var prev_grid = carousel.get_children ().nth_data (1);
                        if (prev_grid != null) {
                            ((Widgets.CalendarGrid) prev_grid).ungrab_focus ();
                        }
                        selected_date = selected_date.add_months (inc);
                    }
                }

                if (index > 1) {
                    var next_month = current_model.get_relative_position (1);
                    var right_grid = create_grid (new Models.CalendarModel (next_month));
                    right_grid.set_range (right_grid.model.data_range, right_grid.model.month_start);
                    right_grid.update_weeks (right_grid.model.data_range.first_dt, right_grid.model.num_weeks);

                    carousel.add (right_grid);

                    Gtk.Widget? first_el = carousel.get_children ().first ().data;
                    if (first_el != null) {
                        carousel.remove (first_el);
                    }
                } else if (index < 1) {
                    var prev_month = current_model.get_relative_position (-1);
                    var left_grid = create_grid (new Models.CalendarModel (prev_month));
                    left_grid.set_range (left_grid.model.data_range, left_grid.model.month_start);
                    left_grid.update_weeks (left_grid.model.data_range.first_dt, left_grid.model.num_weeks);

                    carousel.prepend (left_grid);

                    Gtk.Widget? last_el = carousel.get_children ().last ().data;
                    if (last_el != null) {
                        carousel.remove (last_el);
                    }
                }

                selection_changed (selected_date);
                ((Widgets.CalendarGrid) selected_grid).set_focus_to_day (selected_date);
            });
        }

        private Widgets.CalendarGrid create_grid (Models.CalendarModel calmodel) {
            var calendar_grid = new Widgets.CalendarGrid (settings, calmodel);
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
            var start = Util.get_start_of_month ();
            var today = Util.strip_time (new GLib.DateTime.now_local ());
            selected_date = today;

            if (start.equal (current_model.month_start)) {
                var selected_grid = carousel.get_children ().nth_data (1);
                if (selected_grid != null) {
                    ((Widgets.CalendarGrid) selected_grid).set_focus_to_today ();
                }

                return;
            }


            if (start.equal(current_model.get_relative_position (-1))) {
                carousel.switch_child ((int) carousel.get_position () - 1, carousel.get_animation_duration ());
                return;
            }

            if (start.equal (current_model.get_relative_position (1))) {
                carousel.switch_child ((int) carousel.get_position () + 1, carousel.get_animation_duration ());
                return;
            }

            /*reset Carousel*/
            carousel.no_show_all = true;
            foreach (unowned Gtk.Widget grid in carousel.get_children ()) {
                carousel.remove (grid);
            }

            init_default_carousel ();
            carousel.no_show_all = false;
        }

        public void init_default_carousel () {
            current_model = new Models.CalendarModel (null);
            label.label = current_model.month_start.format (_("%OB, %Y"));

            var center_grid = create_grid (current_model);
            center_grid.set_range (current_model.data_range, current_model.month_start);
            center_grid.update_weeks (current_model.data_range.first_dt, current_model.num_weeks);

            var prev_month = current_model.get_relative_position (-1);
            var left_grid = create_grid (new Models.CalendarModel (prev_month));
            left_grid.set_range (left_grid.model.data_range, left_grid.model.month_start);
            left_grid.update_weeks (left_grid.model.data_range.first_dt, left_grid.model.num_weeks);

            var next_month = current_model.get_relative_position (1);
            var right_grid = create_grid (new Models.CalendarModel (next_month));
            right_grid.set_range (right_grid.model.data_range, right_grid.model.month_start);
            right_grid.update_weeks (right_grid.model.data_range.first_dt, right_grid.model.num_weeks);

            carousel.add (left_grid);
            carousel.add (center_grid);
            carousel.add (right_grid);
            carousel.scroll_to (center_grid);
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
            var selected_grid = carousel.get_children ().nth_data (1);
            if (selected_grid != null) {
                ((Widgets.CalendarGrid) selected_grid).add_event_dots (source, events);
            }
        }

        public void remove_event_dots (E.Source source, Gee.Collection<ECal.Component> events) {
            var selected_grid = carousel.get_children ().nth_data (1);
            if (selected_grid != null) {
                ((Widgets.CalendarGrid) selected_grid).remove_event_dots (source, events);
            }
        }
#endif
    }
}
