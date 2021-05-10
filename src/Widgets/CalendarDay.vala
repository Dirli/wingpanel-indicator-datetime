// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/*-
 * Copyright (c) 2011–2018 elementary, Inc. (https://elementary.io)
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
 * Authored by: Maxwell Barvian
 *              Corentin Noël <corentin@elementaryos.org>
 */

namespace DateTimeIndicator {
/**
 * Represents a single day on the grid.
 */
    public class Widgets.CalendarDay : Gtk.EventBox {
        /*
         * Event emitted when the day is double clicked or the ENTER key is pressed.
         */
        public signal void on_event_add (GLib.DateTime date);

        public GLib.DateTime date { get; construct set; }

        private static Gtk.CssProvider provider;

        private Gee.HashMap<string, Gee.ArrayList<string>> color_events;
        private Gee.HashMap<string, Gtk.Widget> dot_widgets;
        private Gee.HashMap<string, Gtk.CssProvider> color_providers;
        private Gtk.Grid event_grid;
        private Gtk.Label label;
        private bool valid_grab = false;

        public CalendarDay (GLib.DateTime date) {
            Object (date: date);
        }

        static construct {
            provider = new Gtk.CssProvider ();
            provider.load_from_resource ("/io/elementary/desktop/wingpanel/datetime/GridDay.css");
        }

        construct {
            label = new Gtk.Label (null);
            // label.margin_top = 6;

            unowned Gtk.StyleContext label_style_context = label.get_style_context ();
            label_style_context.add_provider (provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
            label_style_context.add_class ("circular");

            event_grid = new Gtk.Grid ();
            event_grid.halign = Gtk.Align.CENTER;
            event_grid.height_request = 6;

            var grid = new Gtk.Grid ();
            grid.halign = grid.valign = Gtk.Align.CENTER;
            grid.attach (label, 0, 0);
            grid.attach (event_grid, 0, 1);

            can_focus = true;
            events |= Gdk.EventMask.BUTTON_PRESS_MASK;

            set_css_name ("grid-day");
            halign = Gtk.Align.CENTER;
            hexpand = true;

            get_style_context ().add_provider (provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);

            add (grid);
            show_all ();

            // Signals and handlers
            button_press_event.connect (on_button_press);

            notify["date"].connect (() => {
                label.label = date.get_day_of_month ().to_string ();
            });

            dot_widgets = new Gee.HashMap<string, Gtk.Widget> ();
            color_providers = new Gee.HashMap<string, Gtk.CssProvider> ();
            color_events = new Gee.HashMap<string, Gee.ArrayList<string>> ();
        }

#if USE_EVO
        public void add_dots (string color, string event_uid) {
            if (!color_providers.has_key (color)) {
                var color_provider = Util.set_event_calendar_color (color);

                if (color_provider != null) {
                    color_providers[color] = color_provider;
                }
            }

            if (color_events.has_key (color)) {
                if (!color_events[color].contains (event_uid)) {
                    color_events[color].add (event_uid);
                }
            } else {
                var events_array = new Gee.ArrayList<string> ();
                events_array.add (event_uid);
                color_events[color] = events_array;
            }

            if (dot_widgets.size < 3 && !dot_widgets.has_key (color)) {
                var event_dot = new Gtk.Image ();
                event_dot.gicon = new ThemedIcon ("pager-checked-symbolic");
                event_dot.pixel_size = 6;

                dot_widgets[color] = event_dot;

                unowned Gtk.StyleContext style_context = event_dot.get_style_context ();
                style_context.add_class (Granite.STYLE_CLASS_ACCENT);
                style_context.add_provider (provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
                if (color_providers.has_key (color)) {
                    style_context.add_provider (color_providers[color], Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
                }

                event_grid.add (event_dot);
                event_dot.show ();
            }
        }

        public void remove_dots (string color, string event_uid) {
            if (!color_events.has_key (color) || !color_events[color].contains (event_uid)) {
                return;
            }

            color_events[color].remove (event_uid);
            if (color_events[color].size != 0) {
                return;
            }

            color_events.unset (color);

            if (dot_widgets.has_key (color)) {
                if (color_events.size > 2) {
                    color_events.foreach ((entry) => {
                        if (!dot_widgets.has_key (entry.key)) {
                            unowned Gtk.StyleContext style_context = dot_widgets[color].get_style_context ();
                            if (color_providers.has_key (color)) {
                                style_context.add_provider (color_providers[color], Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
                                return false;
                            }
                        }
                        return true;
                    });
                } else {
                    dot_widgets[color].destroy ();
                }
            }
        }
#endif

        public void set_selected (bool selected) {
            if (selected) {
                set_state_flags (Gtk.StateFlags.SELECTED, true);

                dot_widgets.foreach ((entry) => {
                    entry.value.hide ();
                    return true;
                });
            } else {
                set_state_flags (Gtk.StateFlags.NORMAL, true);

                dot_widgets.foreach ((entry) => {
                    entry.value.show ();
                    return true;
                });
            }
        }

        public void grab_focus_force () {
            valid_grab = true;
            grab_focus ();
        }

        public override void grab_focus () {
            if (valid_grab) {
                base.grab_focus ();
                valid_grab = false;
            }
        }

        public void sensitive_container (bool sens) {
            label.sensitive = sens;
            event_grid.sensitive = sens;
        }

        private bool on_button_press (Gdk.EventButton event) {
            if (event.type == Gdk.EventType.2BUTTON_PRESS && event.button == Gdk.BUTTON_PRIMARY) {
                on_event_add (date);
            }

            valid_grab = true;
            grab_focus ();
            return false;
        }
    }
}
