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
    public class Widgets.EventsListBox : Gtk.ListBox {
        private Gtk.Label placeholder_label;
        private const string TODAY = _("Today");
        private const string TOMORROW = _("Tomorrow");
        private const string YESTERDAY = _("Yesterday");
        public EventsListBox () {
            selection_mode = Gtk.SelectionMode.NONE;

            placeholder_label = new Gtk.Label (_("No Events ") + TODAY);
            placeholder_label.wrap = true;
            placeholder_label.wrap_mode = Pango.WrapMode.WORD;
            placeholder_label.margin_start = 12;
            placeholder_label.margin_end = 12;
            placeholder_label.max_width_chars = 20;
            placeholder_label.justify = Gtk.Justification.CENTER;
            placeholder_label.show_all ();

            var placeholder_style_context = placeholder_label.get_style_context ();
            placeholder_style_context.add_class (Gtk.STYLE_CLASS_DIM_LABEL);
            placeholder_style_context.add_class (Granite.STYLE_CLASS_H3_LABEL);

            set_header_func (header_update_func);
            set_placeholder (placeholder_label);
            set_sort_func (sort_function);
        }

        public void clear_list () {
            foreach (unowned Gtk.Widget widget in get_children ()) {
                widget.destroy ();
            }
        }

        public void update_placeholder (GLib.DateTime? new_date) {
            if (new_date == null) {
                return;
            }

            var today = new GLib.DateTime.now_local ();
            var today_dy = today.get_day_of_year ();
            var new_dy = new_date.get_day_of_year ();
            string new_label = "";
            if (today.get_year () == new_date.get_year () && today_dy == new_dy) {
                new_label = TODAY;
            } else {
                if (today_dy == 1) {
                    if (new_date.get_year () + 1 == today.get_year () && new_date.get_month () == 12 && new_date.get_day_of_month () == 31) {
                        new_label = YESTERDAY;
                    } else if (today_dy + 1 == new_dy) {
                        new_label = TOMORROW;
                    }
                } else if (today.get_month () == 12 && today.get_day_of_month () == 31) {
                    if (today_dy == new_dy + 1) {
                        new_label = YESTERDAY;
                    } else if (new_date.get_year () - 1 == today.get_year () && new_dy == 1) {
                        new_label = TOMORROW;
                    }
                } else if (new_date.get_year () == today.get_year ()) {
                    if (today_dy == new_dy + 1) {
                        new_label = YESTERDAY;
                    } else if (today_dy + 1 == new_dy) {
                        new_label = TOMORROW;
                    }
                }
            }

            if (new_label == "") {
                int new_dw = new_date.get_day_of_week ();
                new_label = new_dw == 1
                    ? _("on Monday") : new_dw == 2
                    ? _("on Tuesday") : new_dw == 3
                    ? _("on Wednesday") : new_dw == 4
                    ? _("on Thursday") : new_dw == 5
                    ? _("on Friday") : new_dw == 6
                    ? _("on Saturday") : new_dw == 7
                    ? _("on Sunday") : _("on This Day");
            }

            placeholder_label.set_label (_("No Events ") + new_label);
        }

        public void update_events (GLib.DateTime? selected_date, HashTable<E.Source, Gee.TreeMultiMap<string, ECal.Component>> source_events) {
            clear_list ();

            if (selected_date == null) {
                return;
            }

            var events_on_day = new Gee.TreeMap<string, Widgets.EventRow> ();

            source_events.@foreach ((source, component_map) => {
                foreach (var comp in component_map.get_values ()) {
                    if (Util.calcomp_is_on_day (comp, selected_date)) {
                        unowned ICal.Component ical = comp.get_icalcomponent ();
                        var event_uid = ical.get_uid ();
                        if (!events_on_day.has_key (event_uid)) {
                            events_on_day[event_uid] = new Widgets.EventRow (selected_date, ical, source);

                            add (events_on_day[event_uid]);
                        }
                    }
                }
            });

            show_all ();
            return;
        }

        private void header_update_func (Gtk.ListBoxRow lbrow, Gtk.ListBoxRow? lbbefore) {
            var row = (Widgets.EventRow) lbrow;
            if (lbbefore != null) {
                var before = (Widgets.EventRow) lbbefore;
                if (row.is_allday == before.is_allday) {
                    row.set_header (null);
                    return;
                }

                if (row.is_allday != before.is_allday) {
                    var header_label = new Granite.HeaderLabel (_("During the Day"));
                    header_label.margin_start = header_label.margin_end = 6;

                    row.set_header (header_label);
                    return;
                }
            } else {
                if (row.is_allday) {
                    var allday_header = new Granite.HeaderLabel (_("All Day"));
                    allday_header.margin_start = allday_header.margin_end = 6;

                    row.set_header (allday_header);
                }
                return;
            }
        }

        [CCode (instance_pos = -1)]
        private int sort_function (Gtk.ListBoxRow child1, Gtk.ListBoxRow child2) {
            var e1 = (Widgets.EventRow) child1;
            var e2 = (Widgets.EventRow) child2;

            if (e1.start_time.compare (e2.start_time) != 0) {
                return e1.start_time.compare (e2.start_time);
            }

            // If they have the same date, sort them wholeday first
            if (e1.is_allday) {
                return -1;
            } else if (e2.is_allday) {
                return 1;
            }

            return 0;
        }
    }
}
