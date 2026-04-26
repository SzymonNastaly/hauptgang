require 'openssl'
require 'stringio'
key = OpenSSL::PKey::RSA.new(2048)
cert = OpenSSL::X509::Certificate.new
cert.version = 2
cert.serial = 1
cert.subject = OpenSSL::X509::Name.parse "/DC=org/DC=ruby-lang/CN=Ruby CA"
cert.issuer = cert.subject
cert.public_key = key.public_key
cert.not_before = Time.now
cert.not_after = cert.not_before + 3600
cert.sign key, OpenSSL::Digest::SHA1.new
pkcs12 = OpenSSL::PKCS12.create("pass", "cert", key, cert)
pem = pkcs12.to_der

# test the apnotic bug reported in SO:
# Apnotic::Connection.new fails with cert_path: StringIO.new(pem) and token auth?
# Actually the SO question is: OpenSSL::PKey::RSAError (incorrect pkey type: id-ecPublicKey)
