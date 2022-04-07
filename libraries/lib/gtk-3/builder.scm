(define-library (lib gtk-3 builder)
   (export
      GtkBuilder*

      gtk_builder_new
      gtk_builder_new_from_file
      gtk_builder_add_from_file
      gtk_builder_get_object

      gtk_builder_add_callback_symbol
      gtk_builder_connect_signals

      gtk_builder_set_application
      gtk_builder_get_application
   )
   (import
      (scheme core)
      (otus ffi)
      (lib gtk-3 gtk)
      (lib gtk-3 widget)
      (lib gtk-3 application))

(begin
   (define GtkBuilder* type-vptr)
   (define gtk_builder_new (GTK3 GtkBuilder* "gtk_builder_new"))
   (define gtk_builder_new_from_file (GTK3 GtkBuilder* "gtk_builder_new_from_file" type-string))
   (define gtk_builder_add_from_file (GTK3 guint "gtk_builder_add_from_file" GtkBuilder* gchar* (fft& GError*)))
   (define gtk_builder_get_object (GTK3 GObject* "gtk_builder_get_object" GtkBuilder* type-string))

   (define GtkBuilderConnectFunc GtkCallback) ; void (*GtkBuilderConnectFunc)(GtkBuilder *builder, GObject *object, const gchar *signal_name, const gchar *handler_name, GObject *connect_object, GConnectFlags flags, gpointer user_data)
   (define gtk_builder_add_callback_symbol (GTK3 fft-void "gtk_builder_add_callback_symbol" GtkBuilder* gchar* GCallback))
   (define gtk_builder_connect_signals (GTK3 fft-void "gtk_builder_connect_signals" GtkBuilder* gpointer))

   (define gtk_builder_set_application (GTK3 void "gtk_builder_set_application" GtkBuilder* GtkApplication*))
   (define gtk_builder_get_application (GTK3 GtkApplication* "gtk_builder_get_application" GtkBuilder*))

   (define (GtkBuilder props)
      ;...
      #false)
))