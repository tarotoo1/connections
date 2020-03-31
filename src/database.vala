/* database.vala
 *
 * Copyright (C) Red Hat, Inc
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
 * Author: Felipe Borges <felipeborges@gnome.org>
 *
 */

namespace Connections {
    private class MachineConfig : Connections.Database {

        private unowned Connection connection;

        public MachineConfig (Connection connection) {
            load_keyfile ();

            this.connection = connection;
            load ();
        }

        private void load () {
            connection.protocol = connection.protocol.from_string (get_string (connection.uri, "protocol"));
            connection.host = get_string (connection.uri, "host");
            connection.port = int.parse (get_string (connection.uri, "port"));
            connection.display_name = get_string (connection.uri, "display-name");

            connection.scaling = get_boolean (connection.uri, "scaling");
            connection.view_only = get_boolean (connection.uri, "view_only");
            connection.show_local_pointer = get_boolean (connection.uri, "show_local_pointer");
        }

        public bool save () {
            set_string (connection.uri, "protocol", connection.protocol.to_string ());
            set_string (connection.uri, "host", connection.host);
            set_string (connection.uri, "port", connection.port.to_string ());
            set_string (connection.uri, "display-name", connection.display_name);

            set_boolean (connection.uri, "scaling", connection.scaling);
            set_boolean (connection.uri, "view_only", connection.view_only);
            set_boolean (connection.uri, "show_local_pointer", connection.show_local_pointer);

            return save_keyfile ();
        }

        public void delete () {
            load_keyfile ();
            try {
                keyfile.remove_group (connection.uri);
            } catch (GLib.Error error) {
            }

            save_keyfile ();
        }
    }

    private class Database : Object {
        protected KeyFile keyfile = new KeyFile ();
        protected string? filename = Path.build_filename (Environment.get_user_config_dir (),
                                                          "connections.db");

        public void load_keyfile () {
            try {
                File file = File.new_for_path (filename);
                file.create (FileCreateFlags.PRIVATE);
            } catch (GLib.IOError.EXISTS error) {
                // This means that the database exists. Let's use it!
            } catch (GLib.Error error) {
                warning ("Failed to load database file: %s", error.message);

                return;
            }

            try {
                keyfile.load_from_file (filename,
                                        KeyFileFlags.KEEP_COMMENTS | KeyFileFlags.KEEP_TRANSLATIONS);
            } catch (GLib.Error error) {
                warning ("Failed to load database: %s", error.message);
            }
        }

        public bool save_keyfile () {
            try {
                return FileUtils.set_contents (filename, keyfile.to_data (null));
            } catch (GLib.Error error) {
                warning ("Failed to save database: %s", error.message);

                return false;
            }
        }

        public bool get_boolean (string group, string key) {
            try {
                return keyfile.get_boolean (group, key);
            } catch (GLib.KeyFileError error) {
                debug ("Key %s not found in group %s: %s", key, group, error.message);

                return false; // DEFAULT_VALUE
            }
        }

        public void set_boolean (string group, string key, bool value) {
            keyfile.set_boolean (group, key, value);
        }

        public void set_string (string group, string key, string value) {
            keyfile.set_string (group, key, value);
        }

        public string get_string (string group, string key) {
            return keyfile.get_string (group, key);
        }

        public List<Connections.Connection> get_connections () {
            load_keyfile ();

            List<Connections.Connection >? connections = new List<Connections.Connection> ();
            foreach (var group in keyfile.get_groups ()) {
                var uri = Xml.URI.parse (group);
                if (uri.scheme == "vnc")
                    connections.append (new VncConnection (group));
            }

            return connections;
        }
    }
}
