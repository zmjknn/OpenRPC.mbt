///|
fn response_fixture(source : String) -> Json raise {
  @json.parse(source) catch {
    _ => fail("the response fixture should be valid JSON")
  }
}

///|
fn batch_document_fixture() -> Document raise {
  let source =
    #|{
    #|  "openrpc":"1.4.0",
    #|  "info":{"title":"Batch service","version":"1"},
    #|  "methods":[
    #|    {"name":"inventory.get"},
    #|    {"name":"inventory.delete"}
    #|  ]
    #|}
  match Document::parse(source) {
    Ok(document) => document
    Err(_) => fail("the batch document fixture should parse")
  }
}

///|
fn batch_calls_fixture() -> Array[BatchCall] {
  [
    BatchCall::new(101, "inventory.get", RequestParams::named({})),
    BatchCall::new(202, "inventory.delete", RequestParams::named({})),
  ]
}

///|
test "correlates out-of-order batch results in call order" {
  let response_source =
    #|[{"jsonrpc":"2.0","id":202,"result":{"deleted":true}},{"jsonrpc":"2.0","id":101,"result":{"id":"abc"}}]
  let document = batch_document_fixture()
  let result = document.decode_batch_response(
    response_fixture(response_source),
    batch_calls_fixture(),
  )
  match result {
    Ok(values) => {
      assert_eq(values.length(), 2)
      assert_eq(values[0].id, 101)
      assert_eq(values[0].method_name, "inventory.get")
      assert_eq(values[1].id, 202)
      assert_eq(values[1].method_name, "inventory.delete")
    }
    Err(_) => fail("out-of-order results should correlate by id")
  }
}

///|
test "preserves structured errors in a correlated batch" {
  let response_source =
    #|[{"jsonrpc":"2.0","id":101,"result":{"id":"abc"}},{"jsonrpc":"2.0","id":202,"error":{"code":-32000,"message":"not found","data":{"id":202}}}]
  let result = batch_document_fixture().decode_batch_response(
    response_fixture(response_source),
    batch_calls_fixture(),
  )
  match result {
    Ok(values) =>
      match values[1].response {
        RpcResponse::Error(error_value) => {
          assert_eq(error_value.code, -32000)
          assert_eq(error_value.message, "not found")
        }
        RpcResponse::Result(_) =>
          fail("the second response should remain an error")
      }
    Err(_) => fail("a valid error envelope should be preserved")
  }
}

///|
test "rejects an empty call list before decoding responses" {
  let response_source =
    #|[]
  match
    batch_document_fixture().decode_batch_response(
      response_fixture(response_source),
      [],
    ) {
    Err(diagnostics) => {
      assert_eq(diagnostics.length(), 1)
      assert_true(diagnostics[0].code is EmptyBatch)
    }
    Ok(_) => fail("a batch response needs at least one expected call")
  }
}

///|
test "rejects a non-array batch response" {
  let response_source =
    #|{"jsonrpc":"2.0","id":101,"result":true}
  match
    batch_document_fixture().decode_batch_response(
      response_fixture(response_source),
      batch_calls_fixture(),
    ) {
    Err(diagnostics) => {
      assert_eq(diagnostics[0].path, "$")
      assert_true(diagnostics[0].code is InvalidBatchResponse)
    }
    Ok(_) => fail("a batch response must be a JSON array")
  }
}

///|
test "rejects an empty response array" {
  let response_source =
    #|[]
  match
    batch_document_fixture().decode_batch_response(
      response_fixture(response_source),
      batch_calls_fixture(),
    ) {
    Err(diagnostics) => assert_true(diagnostics[0].code is InvalidBatchResponse)
    Ok(_) => fail("an empty response array cannot satisfy two calls")
  }
}

///|
test "reports an unknown response id" {
  let response_source =
    #|[{"jsonrpc":"2.0","id":999,"result":true}]
  match
    batch_document_fixture().decode_batch_response(
      response_fixture(response_source),
      batch_calls_fixture(),
    ) {
    Err(diagnostics) => {
      assert_eq(diagnostics[0].path, "$[0].id")
      assert_true(diagnostics[0].code is UnknownResponseId)
    }
    Ok(_) => fail("an id not present in the calls must be rejected")
  }
}

///|
test "reports duplicate response ids" {
  let response_source =
    #|[{"jsonrpc":"2.0","id":101,"result":true},{"jsonrpc":"2.0","id":101,"result":false}]
  match
    batch_document_fixture().decode_batch_response(
      response_fixture(response_source),
      batch_calls_fixture(),
    ) {
    Err(diagnostics) => {
      assert_eq(diagnostics[0].path, "$[1].id")
      assert_true(diagnostics[0].code is DuplicateResponseId)
    }
    Ok(_) => fail("a response id may occur only once")
  }
}

///|
test "reports a missing response id after scanning the array" {
  let response_source =
    #|[{"jsonrpc":"2.0","id":101,"result":true}]
  match
    batch_document_fixture().decode_batch_response(
      response_fixture(response_source),
      batch_calls_fixture(),
    ) {
    Err(diagnostics) => {
      assert_eq(diagnostics[0].path, "$.responses[1]")
      assert_true(diagnostics[0].code is MissingResponse)
    }
    Ok(_) => fail("every expected call needs one response")
  }
}

///|
test "reuses single-response envelope diagnostics" {
  let response_source =
    #|[{"jsonrpc":"1.0","id":101,"result":true},{"jsonrpc":"2.0","id":202,"result":true}]
  match
    batch_document_fixture().decode_batch_response(
      response_fixture(response_source),
      batch_calls_fixture(),
    ) {
    Err(diagnostics) => {
      assert_eq(diagnostics[0].path, "$.jsonrpc")
      assert_true(diagnostics[0].code is InvalidResponse)
    }
    Ok(_) => fail("individual envelopes still require JSON-RPC 2.0")
  }
}
