local _M = require('apicast.policy.tls')
local ssl = require('ngx.ssl')

local function assert_certificate_set()
    assert.spy(ssl.clear_certs).was_called()
    assert.spy(ssl.set_cert).was_called()
    assert.spy(ssl.set_priv_key).was_called()
    assert.spy(ngx.exit).was_not_called()
end

describe('tls policy', function()

  before_each(function()
    stub.new(ssl, 'clear_certs', function() return true, nil end)
    stub.new(ssl, 'set_cert', function() return true, nil end)
    stub.new(ssl, 'set_priv_key', function() return true, nil end)
    stub.new(ngx, 'exit', function() return true end)
  end)

  describe('.new', function()
    it('works without configuration', function()
      assert(_M.new())
    end)

    it('accepts configuration', function()
        assert(_M.new({ }))
    end)
  end)

  describe("certificate validation", function()
    it('parses embedded PEM certificates', function ()
      local policy = _M.new{
        certificates = {
          {
            certificate = 'data:application/x-x509-ca-cert;name=server.crt;base64,LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSUJ1RENDQVY2Z0F3SUJBZ0lRUkdnVjQzVkIvT3RKVkZOY1NpN0tmREFLQmdncWhrak9QUVFEQWpBYU1SZ3cKRmdZRFZRUURFdzlwYm5SbGNtMWxaR2xoZEdVdFkyRXdIaGNOTVRrd05EQTBNVEV6TWpVNVdoY05Namt3TkRBeApNVEV6TWpVNVdqQVJNUTh3RFFZRFZRUURFd1p6WlhKMlpYSXdXVEFUQmdjcWhrak9QUUlCQmdncWhrak9QUU1CCkJ3TkNBQVErcHJkTE9wa2pGbTEvcWg1dnJxQlcyN0hmY0Q0V3psd0lZbHp1S0tDSkZxR1k3YUV3V3B2MjR2QWcKbkxKQlFhZnE4VUNGZ1hVYjNNL3hLYzNKQURwaG80R09NSUdMTUE0R0ExVWREd0VCL3dRRUF3SUZvREFkQmdOVgpIU1VFRmpBVUJnZ3JCZ0VGQlFjREFRWUlLd1lCQlFVSEF3SXdIUVlEVlIwT0JCWUVGSCtKU2VPbjNzaklia0h2CkQ4K3g3YXZNelpsT01COEdBMVVkSXdRWU1CYUFGTm9TTjRwd0pJa1M1UnlmQlNWMTIxZUVxRXh4TUJvR0ExVWQKRVFRVE1CR0NDV3h2WTJGc2FHOXpkSUlFZEdWemREQUtCZ2dxaGtqT1BRUURBZ05JQURCRkFpQVpPMVRIL0tveAowTDhnOTVSZDQ0L1BaN2RxY1FLOXMzaUg3UVEwajlJcmt3SWhBUC9HcnpEQ0xFVmtEZ0JPOW90a3FHWmRHcDF5CkNZQzZBZ0dkQ0ZIYkxQMW4KLS0tLS1FTkQgQ0VSVElGSUNBVEUtLS0tLQo=',
            certificate_key = 'data:application/pkcs8;name=server.key;base64,LS0tLS1CRUdJTiBFQyBQUklWQVRFIEtFWS0tLS0tCk1IY0NBUUVFSUxZVmJhUmhSeHZtVmNWTDIxL0REazliQ0k5Y3Y5WjBxQ2pncklocFdJcEdvQW9HQ0NxR1NNNDkKQXdFSG9VUURRZ0FFUHFhM1N6cVpJeFp0ZjZvZWI2NmdWdHV4MzNBK0ZzNWNDR0pjN2lpZ2lSYWhtTzJoTUZxYgo5dUx3SUp5eVFVR242dkZBaFlGMUc5elA4U25OeVFBNllRPT0KLS0tLS1FTkQgRUMgUFJJVkFURSBLRVktLS0tLQo=',
          }
        }
      }

      assert.same(1, #policy.certificates)
      policy:ssl_certificate()
      assert_certificate_set()
    end)

    it('parses PEM certificates in files', function ()
      local policy = _M.new{
        certificates = {
          {
            certificate_path = 't/fixtures/CA/root-ca.crt',
            certificate_key_path = 't/fixtures/CA/root-ca.key',
          }
        }
      }

      assert.same(1, #policy.certificates)
      policy:ssl_certificate()
      assert_certificate_set()
    end)

    it("Does not load cert if can't be read", function()
      local policy = _M.new{
        certificates = {
          {
            certificate_path = 't/fixtures/CA/invalid_va',
            certificate_key_path = 't/fixtures/CA/invalid_key',
          }
        }
      }
      assert.same(0, #policy.certificates)
      policy:ssl_certificate()
      assert.spy(ssl.clear_certs).was_not_called()
    end)

    it("Fallbacks correctly to the second certificate if first fails", function()
      local policy = _M.new{
        certificates = {
          {
            certificate_path = 't/fixtures/CA/invalid_va',
            certificate_key_path = 't/fixtures/CA/invalid_key',
          },
          {
            certificate_path = 't/fixtures/CA/root-ca.crt',
            certificate_key_path = 't/fixtures/CA/root-ca.key',
          }
        }
      }
      assert.same(1, #policy.certificates)
      policy:ssl_certificate()
      assert_certificate_set()
    end)
  end)
end)
