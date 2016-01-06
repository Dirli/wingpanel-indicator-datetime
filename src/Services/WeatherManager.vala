/*-
 * Copyright (c) 2015 Wingpanel Developers (http://launchpad.net/wingpanel)
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Library General Public License as published by
 * the Free Software Foundation, either version 2.1 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Library General Public License for more details.
 *
 * You should have received a copy of the GNU Library General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

public class DateTime.Services.WeatherManager : GLib.Object {
    private static WeatherManager? instance = null;
    GWeather.Info actual_info;

    public signal void updated (GWeather.Info info);

    public void set_location (GWeather.Location location) {
        actual_info = new GWeather.Info (location, GWeather.ForecastType.LIST);
        actual_info.updated.connect (() => {
            updated (actual_info);
        });
    }

    public static WeatherManager get_default () {
        if (instance == null)
            instance = new WeatherManager ();

        return instance;
    }
}
