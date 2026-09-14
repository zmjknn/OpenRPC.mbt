# Batch response correlation design

## Decision

Add a document-level `decode_batch_response` operation that receives the
original `BatchCall` list and a JSON response value. It correlates ids without
network access, delegates envelope validation to the existing method decoder,
and returns typed records in the original call order.

## Boundary

The correlator handles JSON-RPC response shape, id matching, duplicates, and
missing responses. It does not dispatch requests, retry calls, or validate
result schemas automatically; callers can invoke `Method::validate_result`
after correlation when that policy is desired.

## Failure model

Malformed arrays use `InvalidBatchResponse`; unknown, duplicate, and missing
ids receive dedicated diagnostics with indexed JSON-style paths. A malformed
individual envelope preserves the existing `InvalidResponse`/`InvalidRpcError`
diagnostics from `Method::decode_response`.
