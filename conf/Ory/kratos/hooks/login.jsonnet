// Login event webhook payload for kerby-instruments
// This tracks login events and can trigger certificate validation

function(ctx) {
  identity_id: ctx.identity.id,
  traits: {
    email: ctx.identity.traits.email,
    kerberos_principal: ctx.identity.traits.kerberos_principal,
    realm: ctx.identity.traits.realm,
    x509_cert_serial: ctx.identity.traits.x509_cert_serial,
  },
  login_context: {
    session_id: std.get(ctx, 'session.id', ''),
    authentication_method: std.get(ctx.flow, 'active', ''),
    login_time: ctx.flow.created_at,
    user_agent: std.get(ctx.request_headers, 'User-Agent', ''),
    ip_address: std.get(ctx.request_headers, 'X-Forwarded-For', ''),
  },
  action: "login_event",
  security_checks: {
    validate_certificate: true,
    check_principal_status: true,
    update_last_login: true,
    audit_login: true,
  }
}
