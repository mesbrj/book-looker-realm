// Recovery notification webhook payload for kerby-instruments
// This handles password recovery and certificate reissuance

function(ctx) {
  identity_id: ctx.identity.id,
  traits: {
    email: ctx.identity.traits.email,
    kerberos_principal: ctx.identity.traits.kerberos_principal,
    realm: ctx.identity.traits.realm,
    x509_cert_serial: ctx.identity.traits.x509_cert_serial,
  },
  recovery_context: {
    recovery_method: "email",
    recovery_initiated_at: ctx.flow.created_at,
    recovery_flow_id: ctx.flow.id,
    user_agent: std.get(ctx.request_headers, 'User-Agent', ''),
    ip_address: std.get(ctx.request_headers, 'X-Forwarded-For', ''),
  },
  action: "recovery_notification",
  security_actions: {
    audit_recovery_attempt: true,
    check_principal_lock_status: true,
    prepare_certificate_reissuance: true,
    notify_security_team: false,
  }
}
