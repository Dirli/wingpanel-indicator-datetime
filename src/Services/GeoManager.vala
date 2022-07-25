namespace DateTimeIndicator {
    public class Services.GeoManager : GLib.Object {
        public signal void changed_location (double lat, double lon);
        private GClue.Simple? gclue_simple;
        private int gclue_reconnect;

        public GeoManager () {
            gclue_reconnect = 5;
        }

        public void init () {
            auto_detect_async.begin ((obj, res) => {
                if (gclue_simple == null) {
                    return;
                }

                gclue_simple.notify["location"].connect (() => {
                    changed_location (gclue_simple.location.latitude, gclue_simple.location.longitude);
                });

                changed_location (gclue_simple.location.latitude, gclue_simple.location.longitude);
            });
        }

        private async void auto_detect_async () {
            if (gclue_simple != null) {
                return;
            }

            try {
                gclue_simple = yield new GClue.Simple ("io.elementary.wingpanel", GClue.AccuracyLevel.CITY, null);
            } catch (Error e) {
                warning ("Failed to connect to GeoClue2 service: %s", e.message);
                // in case of "timeout expired" error
                // for me it manifests itself in a debian-based assembly, maybe this is my problem, but so far so
                if (gclue_reconnect-- > 0) {
                    GLib.Timeout.add_seconds (300, () => {
                        init ();

                        return false;
                    });
                }
            }
        }
    }
}
