# Lets translations use the plural forms of the language (one/few/many for
# Russian). The rules live in config/locales/plurals.rb.
I18n::Backend::Simple.include(I18n::Backend::Pluralization)
Rails.application.config.i18n.load_path += [ Rails.root.join("config/locales/plurals.rb").to_s ]
