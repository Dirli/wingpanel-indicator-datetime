/*
 * Copyright (c) 2011-2016 elementary LLC. (https://elementary.io)
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

public class DateTime.Indicator : Wingpanel.Indicator {
    public static GLib.Settings settings;

    private Widgets.PanelLabel panel_label;
    private Gtk.Grid main_grid;
    private Widgets.Calendar calendar;
    private Gtk.ListBox event_listbox;
    private uint update_events_idle_source = 0;

    public Indicator () {
        Object (
            code_name: Wingpanel.Indicator.DATETIME,
            display_name: _("Date & Time"),
            description: _("The date and time indicator")
        );
    }

    static construct {
        settings = new GLib.Settings ("io.elementary.desktop.wingpanel.datetime");
    }

    construct {
        visible = true;
    }

    public override Gtk.Widget get_display_widget () {
        if (panel_label == null) {
            panel_label = new Widgets.PanelLabel ();
        }

        return panel_label;
    }

    public override Gtk.Widget? get_widget () {
        if (main_grid == null) {
            calendar = new Widgets.Calendar ();
            calendar.margin_bottom = 6;

            var placeholder_label = new Gtk.Label (_("No Events on This Day"));
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

            event_listbox = new Gtk.ListBox ();
            event_listbox.selection_mode = Gtk.SelectionMode.NONE;
            event_listbox.set_header_func (header_update_func);
            event_listbox.set_placeholder (placeholder_label);
            event_listbox.set_sort_func (sort_function);

            var scrolled_window = new Gtk.ScrolledWindow (null, null);
            scrolled_window.hscrollbar_policy = Gtk.PolicyType.NEVER;
            scrolled_window.add (event_listbox);

            var settings_button = new Gtk.ModelButton ();
            settings_button.text = _("Date & Time Settings…");

            main_grid = new Gtk.Grid ();
            main_grid.margin_top = 12;
            main_grid.attach (calendar, 0, 0);
            main_grid.attach (new Gtk.Separator (Gtk.Orientation.VERTICAL), 1, 0);
            main_grid.attach (scrolled_window, 2, 0);
            main_grid.attach (new Wingpanel.Widgets.Separator (), 0, 2, 3);
            main_grid.attach (settings_button, 0, 3, 3);

            var size_group = new Gtk.SizeGroup (Gtk.SizeGroupMode.HORIZONTAL);
            size_group.add_widget (calendar);
            size_group.add_widget (event_listbox);

            calendar.day_double_click.connect (() => {
                close ();
            });

            calendar.selection_changed.connect ((date) => {
                idle_update_events ();
            });

            event_listbox.row_activated.connect ((row) => {
                calendar.show_date_in_maya (((DateTime.EventRow) row).cal_event.date);
                close ();
            });

            settings_button.clicked.connect (() => {
                try {
                    AppInfo.launch_default_for_uri ("settings://time", null);
                } catch (Error e) {
                    warning ("Failed to open time and date settings: %s", e.message);
                }
            });
        }

        return main_grid;
    }

    private void header_update_func (Gtk.ListBoxRow lbrow, Gtk.ListBoxRow? lbbefore) {
        var row = (DateTime.EventRow) lbrow;
        if (lbbefore != null) {
            var before = (DateTime.EventRow) lbbefore;
            if (row.cal_event.is_allday == before.cal_event.is_allday) {
                row.set_header (null);
                return;
            }

            if (row.cal_event.is_allday != before.cal_event.is_allday) {
                var header_label = new Granite.HeaderLabel (_("During the Day"));
                header_label.margin_start = header_label.margin_end = 6;

                row.set_header (header_label);
                return;
            }
        } else {
            if (row.cal_event.is_allday) {
                var allday_header = new Granite.HeaderLabel (_("All Day"));
                allday_header.margin_start = allday_header.margin_end = 6;

                row.set_header (allday_header);
            }
            return;
        }
    }

    [CCode (instance_pos = -1)]
    private int sort_function (Gtk.ListBoxRow child1, Gtk.ListBoxRow child2) {
        var e1 = ((EventRow) child1).cal_event;
        var e2 = ((EventRow) child2).cal_event;

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

    private void update_events_model (E.Source source, Gee.Collection<ECal.Component> events) {
        idle_update_events ();
    }

    private void idle_update_events () {
        if (update_events_idle_source > 0) {
            GLib.Source.remove (update_events_idle_source);
        }

        update_events_idle_source = GLib.Idle.add (update_events);
    }

    private bool update_events () {
        foreach (unowned Gtk.Widget widget in event_listbox.get_children ()) {
            widget.destroy ();
        }

        if (calendar.selected_date == null) {
            update_events_idle_source = 0;
            return GLib.Source.REMOVE;
        }

        var events = Widgets.CalendarModel.get_default ().get_events (calendar.selected_date);
        if (events.size == 0) {
            update_events_idle_source = 0;
            return GLib.Source.REMOVE;
        }

        foreach (var event in events) {
            var menuitem = new DateTime.EventRow (event);

            event_listbox.add (menuitem);
        }

        event_listbox.show_all ();
        update_events_idle_source = 0;
        return GLib.Source.REMOVE;
    }

    public override void opened () {
        calendar.show_today ();

        Widgets.CalendarModel.get_default ().events_added.connect (update_events_model);
        Widgets.CalendarModel.get_default ().events_updated.connect (update_events_model);
        Widgets.CalendarModel.get_default ().events_removed.connect (update_events_model);
    }

    public override void closed () {
        Widgets.CalendarModel.get_default ().events_added.disconnect (update_events_model);
        Widgets.CalendarModel.get_default ().events_updated.disconnect (update_events_model);
        Widgets.CalendarModel.get_default ().events_removed.disconnect (update_events_model);
    }
}

public Wingpanel.Indicator get_indicator (Module module) {
    debug ("Activating DateTime Indicator");
    var indicator = new DateTime.Indicator ();

    return indicator;
}
