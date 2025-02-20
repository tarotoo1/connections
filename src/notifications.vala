/* notifications.vala
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
    private class NotificationsBar : Gtk.Bin {
        public const int DEFAULT_TIMEOUT = 6;
        private const int MAX_NOTIFICATIONS = 5;

        private Gtk.Widget? _active_notification;
        public Gtk.Widget? active_notification {
            get {
                return _active_notification;
            }

            set {
                if (_active_notification != null) {
                    remove (_active_notification);
                }

                _active_notification = value;
                add (_active_notification);
            }
        }

        construct {
            valign = Gtk.Align.START;
            halign = Gtk.Align.CENTER;
            get_style_context ().add_class ("transparent-bg");
        }

        public void display_for_error (string message) {
            var notification = new Notification (message, null, null, null);

            active_notification = notification;
        }

        public void display_for_action (string message,
                                        string? ok_label,
                                        owned Notification.OKFunc? ok_func,
                                        owned Notification.DismissFunc? dismiss_func) {
            var notification = new Notification (message, ok_label, (owned) ok_func, (owned) dismiss_func);
            notification.dismissed.connect (() => {
                active_notification = null;
            });

            active_notification = notification;
        }

        public AuthNotification display_for_auth (string auth_string,
                                                  owned AuthNotification.AuthFunc? auth_func,
                                                  owned Notification.DismissFunc?  dismiss_func,
                                                  bool                             need_username = true) {
            var notification = new Connections.AuthNotification (auth_string,
                                                                 (owned) auth_func,
                                                                 (owned) dismiss_func,
                                                                 need_username);
            active_notification = notification;

            return notification;
        }

        public void dismiss () {
            if (active_notification != null) {
                // TODO: Make AuthNotification derived from Notification
                if (active_notification is Notification) {
                    Notification? notification = active_notification as Notification;

                    notification.dismiss ();
                } else if (active_notification is AuthNotification) {
                    AuthNotification? notification = active_notification as AuthNotification;

                    notification.dismiss ();
                }

                active_notification = null;
            }
        }
    }

    [GtkTemplate (ui = "/org/gnome/Connections/ui/notification.ui")]
    private class Notification : Gtk.Revealer {
        public signal void dismissed ();

        public delegate void OKFunc ();
        public delegate void DismissFunc ();

        private DismissFunc? dismiss_func;

        [GtkChild]
        private unowned Gtk.Label message_label; 
        [GtkChild]
        private unowned Gtk.Button ok_button; 

        private uint notification_timeout_id = 0;

        public Notification (string  message,
                             string? ok_label,
                             owned OKFunc? ok_func,
                             owned DismissFunc? dismiss_func,
                             int timeout = NotificationsBar.DEFAULT_TIMEOUT) {
            this.dismiss_func = (owned)dismiss_func;
            set_reveal_child (true);

            message_label.label = message;

            notification_timeout_id = Timeout.add_seconds (timeout, () => {
                notification_timeout_id = 0;
                dismiss ();
                return Source.REMOVE;
            });

            if (ok_label != null) {
                ok_button.label = ok_label;

                ok_button.clicked.connect (() => {
                    if (ok_func != null)
                        ok_func ();

                    set_reveal_child (false);
                    dismissed ();

                    if (notification_timeout_id != 0) {
                        Source.remove (notification_timeout_id);
                        notification_timeout_id = 0;
                    }
                });

                ok_button.show_all ();
            }
        }

        [GtkCallback]
        public void dismiss () {
            dismissed ();
            set_reveal_child (false);
            if (dismiss_func != null)
                dismiss_func ();

            if (notification_timeout_id != 0) {
                Source.remove (notification_timeout_id);
                notification_timeout_id = 0;
            }
        }
    }

    [GtkTemplate (ui = "/org/gnome/Connections/ui/auth-notification.ui")]
    private class AuthNotification : Gtk.Revealer {
        public delegate void AuthFunc (string username, string password);
        private bool auth_pressed;

        public signal void dismissed ();

        [GtkChild]
        private unowned Gtk.Label title_label;
        [GtkChild]
        private unowned Gtk.Label username_label;
        [GtkChild]
        private unowned Gtk.Entry username_entry;
        [GtkChild]
        private unowned Gtk.Entry password_entry;
        [GtkChild]
        private unowned Gtk.Button auth_button;

        private AuthFunc? auth_func;

        public AuthNotification (string auth_string,
                                 owned AuthFunc? auth_func,
                                 owned Notification.DismissFunc? dismiss_func,
                                 bool need_username) {
            set_reveal_child (true);

            title_label.label = auth_string;

            username_label.visible = need_username;
            username_entry.visible = need_username;

            this.auth_func = (owned) auth_func;

            dismissed.connect (() => {
                if (!auth_pressed && dismiss_func != null)
                    dismiss_func ();
            });
        }

        [GtkCallback]
        private void on_username_entry_map () {
            username_entry.grab_focus ();
        }

        [GtkCallback]
        private void on_username_entry_activated () {
            password_entry.grab_focus ();
        }

        [GtkCallback]
        private void on_password_entry_map () {
            password_entry.grab_focus ();
        }

        [GtkCallback]
        private void on_password_entry_activated () {
            auth_button.activate ();
        }

        [GtkCallback]
        private void on_auth_button_clicked () {
            if (auth_func != null)
                auth_func (username_entry.get_text (), password_entry.get_text ());
            auth_pressed = true;

            dismiss ();
        }

        public void dismiss () {
            set_reveal_child (false);
            dismissed ();
        }
    }
}
