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

        public GLib.DateTime? selected_date { get; private set; default = null; }
        public GLib.Settings settings { get; construct; }

        private Widgets.CalendarDay? _current_today = null;
        public Widgets.CalendarDay? current_today {
            set {
                unset_today_style ();
                _current_today = value;
                set_today_style ();
            }
            get {
                return _current_today;
            }
        }

        private Gtk.Label month_label;

        private Models.CalendarModel _current_model;
        public Models.CalendarModel current_model {
            get {
                return _current_model;
            }
            private set {
                _current_model = value;

                month_label.label = value.month_start.format (_("%OB, %Y"));
            }
        }

        private Hdy.Carousel carousel;

        public CalendarView (GLib.Settings clock_settings) {
            Object (settings: clock_settings,
                    column_spacing: 6,
                    row_spacing: 6,
                    margin_start: 10,
                    margin_end: 10);
        }

        construct {
            key_press_event.connect (on_key_press);

            var provider = new Gtk.CssProvider ();
            provider.load_from_resource ("/io/elementary/desktop/wingpanel/datetime/ControlHeader.css");

            month_label = new Gtk.Label (null);
            month_label.hexpand = true;
            month_label.margin_start = 6;
            month_label.xalign = 0;
            month_label.width_chars = 16;

            var month_style_context = month_label.get_style_context ();
            month_style_context.add_class (Granite.STYLE_CLASS_ACCENT);
            month_style_context.add_class ("header-label");
            month_style_context.add_provider (provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);

            var left_button = new Gtk.Button.from_icon_name ("pan-start-symbolic");
            var center_button = new Gtk.Button.from_icon_name ("office-calendar-symbolic");
            center_button.tooltip_text = _("Go to today's date");
            var right_button = new Gtk.Button.from_icon_name ("pan-end-symbolic");

            var box_buttons = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
            box_buttons.halign = Gtk.Align.CENTER;
            box_buttons.valign = Gtk.Align.START;
            box_buttons.get_style_context ().add_class (Gtk.STYLE_CLASS_LINKED);
            box_buttons.add (left_button);
            box_buttons.add (center_button);
            box_buttons.add (right_button);

            var box_buttons_revealer = new Gtk.Revealer ();
            box_buttons_revealer.transition_type = Gtk.RevealerTransitionType.SLIDE_UP;
            box_buttons_revealer.add (box_buttons);

            carousel = new Hdy.Carousel () {
                interactive = true,
                expand = true,
                spacing = 15
            };

            init_carousel (null);


            attach (month_label,          0, 0);
            attach (box_buttons_revealer, 1, 0);
            attach (carousel,             0, 1, 2);

            show_all ();

            settings.bind ("show-nav", box_buttons_revealer, "reveal-child", GLib.SettingsBindFlags.DEFAULT);

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

            carousel.page_changed.connect (on_page_changed);
        }

        private bool on_key_press (Gdk.EventKey event) {
            if (event.keyval == Gdk.keyval_from_name ("Home")) {
                show_today ();
                return true;
            }

            if (event.keyval == Gdk.keyval_from_name ("KP_Add")) {
                selected_date = selected_date.add_years (1);
                reset_carousel (selected_date);
                return true;
            }

            if (event.keyval == Gdk.keyval_from_name ("KP_Subtract")) {
                selected_date = selected_date.add_years (-1);
                reset_carousel (selected_date);
                return true;
            }

            return false;
        }

        private void on_page_changed (uint index) {
            var selected_grid = carousel.get_children ().nth_data (index);
            if (selected_grid == null) {
                return;
            }

            current_model = ((Widgets.CalendarGrid) selected_grid).model;

            var current_month = current_model.month_start.get_month ();
            if (selected_date.get_month () != current_month) {
                int inc = selected_date.add_months (1).get_month () == current_month ? 1 :
                          selected_date.add_months (-1).get_month () == current_month ? -1:
                          0;

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

                carousel.add (right_grid);

                Gtk.Widget? first_el = carousel.get_children ().first ().data;
                if (first_el != null) {
                    carousel.remove (first_el);
                }
            } else if (index < 1) {
                var prev_month = current_model.get_relative_position (-1);
                var left_grid = create_grid (new Models.CalendarModel (prev_month));

                carousel.prepend (left_grid);

                Gtk.Widget? last_el = carousel.get_children ().last ().data;
                if (last_el != null) {
                    carousel.remove (last_el);
                }
            }

            selection_changed (selected_date);
            ((Widgets.CalendarGrid) selected_grid).set_focus_to_day (selected_date);
        }

        private Widgets.CalendarGrid create_grid (Models.CalendarModel calmodel) {
            var calendar_grid = new Widgets.CalendarGrid (settings, calmodel);
            calendar_grid.show_all ();

            calendar_grid.on_event_add.connect ((date) => {
                show_date_in_maya (date);

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

            var _today = calendar_grid.set_range (calendar_grid.model.data_range, calendar_grid.model.month_start);
            calendar_grid.update_weeks (calendar_grid.model.data_range.first_dt, calendar_grid.model.num_weeks);

            if (_today != null) {
                current_today = _today;
            }

            return calendar_grid;
        }

        public void show_today (bool refresh = false) {
            var start = Util.get_start_of_month ();
            selected_date = Util.strip_time (new GLib.DateTime.now_local ());

            if (!refresh) {
                if (start.equal (current_model.month_start)) {
                    Widgets.CalendarGrid selected_grid = carousel.get_children ().nth_data (1) as Widgets.CalendarGrid;
                    if (selected_grid != null) {
                        selected_grid.set_focus_to_today (selected_date);

                        if (current_today != null && !selected_date.equal (Util.strip_time (current_today.date))) {
                            var _today = selected_grid.get_day (selected_date);
                            if (_today != null) {
                                current_today = _today;
                            }
                        }
                    }

                    return;
                }

                if (start.equal (current_model.get_relative_position (-1))) {
                    carousel.switch_child ((int) carousel.get_position () - 1, carousel.get_animation_duration ());
                    return;
                }

                if (start.equal (current_model.get_relative_position (1))) {
                    carousel.switch_child ((int) carousel.get_position () + 1, carousel.get_animation_duration ());
                    return;
                }
            }

            /*reset Carousel*/
            reset_carousel (null);
        }

        private void reset_carousel (GLib.DateTime? date) {
            carousel.no_show_all = true;
            foreach (unowned Gtk.Widget grid in carousel.get_children ()) {
                carousel.remove (grid);
            }

            init_carousel (date != null ? Util.get_start_of_month (date) : null);
            carousel.no_show_all = false;
        }

        private void init_carousel (GLib.DateTime? date) {
            current_model = new Models.CalendarModel (date);

            var center_grid = create_grid (current_model);

            var prev_month = current_model.get_relative_position (-1);
            var left_grid = create_grid (new Models.CalendarModel (prev_month));

            var next_month = current_model.get_relative_position (1);
            var right_grid = create_grid (new Models.CalendarModel (next_month));

            carousel.add (left_grid);
            carousel.add (center_grid);
            carousel.add (right_grid);
            carousel.scroll_to (center_grid);
        }

        private void set_today_style () {
            if (current_today != null) {
                current_today.get_style_context ().add_class (Granite.STYLE_CLASS_ACCENT);
                current_today.set_receives_default (true);
            }
        }

        private void unset_today_style () {
            if (current_today != null) {
                current_today.get_style_context ().remove_class (Granite.STYLE_CLASS_ACCENT);
                current_today.set_receives_default (false);
            }
        }

        public void show_date_in_maya (GLib.DateTime date) {
            var command = "io.elementary.calendar --show-day %s".printf (date.format ("%F"));

            try {
                var appinfo = AppInfo.create_from_commandline (command, null, AppInfoCreateFlags.NONE);
                appinfo.launch_uris (null, null);

                var selected_grid = carousel.get_children ().nth_data (1);
                if (selected_grid != null) {
                    ((Widgets.CalendarGrid) selected_grid).ungrab_focus ();
                }
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
