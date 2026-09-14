# Contract-Aware JSON-RPC Notification Design

## Context

The package now builds both named and positional requests and decodes their responses. JSON-RPC notifications are the one-way counterpart: they carry the method and parameters but deliberately omit `id`, so a caller must not wait for a response. Hand-writing them would duplicate the required/unknown and positional arity checks already encoded by `Method`.

## Options considered

1. **Add a generic JSON-RPC message type.** The MoonBit ecosystem already has generic JSON-RPC/MCP message codecs; adding another would not advance this OpenRPC-specific contract boundary.
2. **Add dedicated named and positional notification builders (recommended).** Keep the two wire encodings explicit, reuse the existing parameter validation rules, and omit `id` by construction. Existing request and response APIs remain source-compatible.
3. **Attach notifications to a transport client.** This would make the feature harder to embed and violate the package's target-portable, I/O-free boundary.

## Selected architecture

Expose `Method::build_notification(params)` and `Method::build_positional_notification(values)`. Both return a JSON-RPC 2.0 object containing `jsonrpc`, `method`, and the validated `params` shape, with no `id` key. Extract private named and positional validation helpers so request and notification builders share exactly the same contract rules. Empty parameter maps/arrays remain explicit in the envelope for predictable consumers.

## Boundaries

Notifications never enter the response decoder because they have no request id. The builders perform no I/O, do not evaluate schemas, and do not synthesize defaults. Tests cover named and positional notifications, absence of `id`, optional trailing parameters, and all existing validation failures remaining unchanged.
