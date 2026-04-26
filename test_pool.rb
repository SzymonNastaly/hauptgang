require 'bundler/inline'

gemfile do
  source 'https://rubygems.org'
  gem 'apnotic', '1.8.0'
end

require 'apnotic'
require 'stringio'
require 'openssl'

key = OpenSSL::PKey::EC.generate("prime256v1")
pem = key.to_pem

pool = Apnotic::ConnectionPool.new(
  {
    auth_method: :token,
    cert_path: StringIO.new(pem),
    key_id: "abc",
    team_id: "def"
  },
  size: 2
) { |conn| }

Thread.new { pool.with { |conn| puts conn.class } }.join
Thread.new { pool.with { |conn| puts conn.class } }.join
