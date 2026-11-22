class PrepareUsersForHashedEmail < ActiveRecord::Migration[8.1]
  # The address is replaced by its HMAC and can never be restored from it.
  def up
    add_column :users, :email_digest, :string
    add_column :users, :gender, :string
    add_column :users, :age_decade, :integer
    add_column :users, :confirmed_at, :datetime

    backfill_email_digest

    change_column_null :users, :email_digest, false
    add_index :users, :email_digest, unique: true

    remove_index :users, :email_address
    remove_column :users, :email_address

    # Nicknames are unique ignoring case.
    remove_index :users, :nickname
    add_index :users, "lower(nickname)", unique: true, name: "index_users_on_lower_nickname"
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "email addresses cannot be restored from their digests"
  end

  private

  # Same formula as User.email_digest_for; the model is not used here so the
  # migration keeps working when the model changes.
  def backfill_email_digest
    pepper = Rails.configuration.x.email_pepper

    select_rows("SELECT id, email_address FROM users").each do |id, email|
      digest = OpenSSL::HMAC.hexdigest("SHA256", pepper, email.to_s.strip.downcase)
      execute <<~SQL.squish
        UPDATE users
        SET email_digest = #{quote(digest)}, confirmed_at = #{quote(Time.current)}
        WHERE id = #{id.to_i}
      SQL
    end
  end
end
