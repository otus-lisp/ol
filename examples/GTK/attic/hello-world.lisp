#!/usr/bin/env ol

(import (otus ffi)
   (lib glib-2)
   (lib gtk-3))
(import (only (olvm syscalls) strftime))

(define print_hello (vm:pin (cons
   (cons fft-int (list GtkWidget* gpointer))
   (lambda (widget userdata)
      (print (strftime "%F %H:%M:%S\0") " - hello!")
      TRUE
))))

(define activate (vm:pin (cons
   (cons fft-int (list GtkApplication* gpointer))
   (lambda (app userdata)
      (define window (gtk_application_window_new app))
      (gtk_window_set_title window "Window")
      (gtk_window_set_default_size window 200 200)

      (define button_box (gtk_button_box_new GTK_ORIENTATION_HORIZONTAL))
      (gtk_container_add window button_box)

      (define button (gtk_button_new_with_label "Hello World"))
      (g_signal_connect button "clicked"  (G_CALLBACK print_hello) NULL)

      ;g_signal_connect_swapped (button, "clicked", G_CALLBACK (gtk_widget_destroy), window);
      (gtk_container_add button_box button)

      (gtk_widget_show_all window)
))))

(define app (gtk_application_new "org.gtk.example" G_APPLICATION_FLAGS_NONE))
(g_signal_connect app "activate" (G_CALLBACK activate) NULL)

(g_application_run app 0 #false)