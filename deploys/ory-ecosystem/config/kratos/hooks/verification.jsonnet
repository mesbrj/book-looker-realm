// Verification completed webhook payload for kerby-instruments
// This notifies kerby-instruments when email verification is completed

function(ctx) {
  identity_id: ctx.identity.id,
  traits: {
    email: ctx.identity.traits.email,
    kerberos_principal: ctx.identity.traits.kerberos_principal,
    realm: ctx.identity.traits.realm,
  },
  verification_context: {
    verification_method: "email",
    verified_at: ctx.flow.created_at,
    verification_flow_id: ctx.flow.id,
  },
  action: "verification_completed",
  post_verification_actions: {
    activate_principal: true,
    generate_certificates: true,
    enable_kerberos_auth: true,
    send_welcome_notification: true,
  }
}
