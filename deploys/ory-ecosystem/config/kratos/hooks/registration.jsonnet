// Registration webhook payload for kerby-instruments
// This Jsonnet template formats identity data for kerby-instruments principal creation

function(ctx) {
  identity_id: ctx.identity.id,
  traits: {
    email: ctx.identity.traits.email,
    kerberos_principal: ctx.identity.traits.kerberos_principal,
    realm: ctx.identity.traits.realm,
    roles: ctx.identity.traits.roles,
    x509_cert_serial: ctx.identity.traits.x509_cert_serial,
  },
  metadata: {
    registration_method: ctx.flow.type,
    registration_time: ctx.flow.created_at,
    kratos_identity_id: ctx.identity.id,
    user_agent: std.get(ctx.request_headers, 'User-Agent', ''),
    ip_address: std.get(ctx.request_headers, 'X-Forwarded-For', ''),
  },
  action: "create_principal",
  realm_context: {
    realm_name: "BOOK-LOOKER.REALM",
    require_cert_generation: true,
    default_roles: ["user"],
    enable_delegation: false,
  }
}
