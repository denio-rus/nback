# Plural rules for languages whose forms differ from English (one/other).
# Russian: 1 прохождение, 2 прохождения, 5 прохождений. Loaded by config/initializers/i18n_pluralization.rb.
{
  en: {
    i18n: {
      plural: {
        keys: %i[one other],
        rule: ->(count) { count == 1 ? :one : :other }
      }
    }
  },
  ru: {
    i18n: {
      plural: {
        keys: %i[one few many other],
        rule: lambda do |count|
          n = count.to_i.abs
          if count != n then :other
          elsif n % 10 == 1 && n % 100 != 11 then :one
          elsif (2..4).cover?(n % 10) && !(12..14).cover?(n % 100) then :few
          else :many
          end
        end
      }
    }
  }
}
