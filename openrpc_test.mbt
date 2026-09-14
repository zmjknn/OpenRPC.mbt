///|
test "decodes the minimum OpenRPC document" {
  let source =
    #|{
    #|  "openrpc": "1.4.0",
    #|  "info": {"title": "Inventory", "version": "1.0.0"},
    #|  "methods": [{"name": "inventory.list"}]
    #|}
  match Document::parse(source) {
    Ok(document) => {
      assert_eq(document.openrpc, "1.4.0")
      assert_eq(document.info.title, "Inventory")
      assert_eq(document.methods.length(), 1)
      assert_eq(document.methods[0].name, "inventory.list")
    }
    Err(_) => fail("valid OpenRPC documents should be decoded")
  }
}

///|
test "reports the path for an unsupported OpenRPC version" {
  let source =
    #|{"openrpc":"2.0.0","info":{"title":"x","version":"1"},"methods":[]}
  let result = Document::parse(source)
  match result {
    Err(diagnostics) => {
      assert_eq(diagnostics.length(), 1)
      assert_eq(diagnostics[0].path, "$.openrpc")
      assert_true(diagnostics[0].code is UnsupportedVersion)
    }
    Ok(_) => fail("unsupported OpenRPC versions should be rejected")
  }
}

///|
test "reports a missing required field" {
  let source =
    #|{"openrpc":"1.4.0","info":{"title":"x","version":"1"}}
  let result = Document::parse(source)
  match result {
    Err(diagnostics) => {
      assert_eq(diagnostics.length(), 1)
      assert_eq(diagnostics[0].path, "$.methods")
      assert_true(diagnostics[0].code is MissingField)
    }
    Ok(_) => fail("documents without methods should be rejected")
  }
}

///|
test "reports the indexed path for an invalid method" {
  let source =
    #|{"openrpc":"1.4.0","info":{"title":"x","version":"1"},"methods":[{}]}
  let result = Document::parse(source)
  match result {
    Err(diagnostics) => {
      assert_eq(diagnostics.length(), 1)
      assert_eq(diagnostics[0].path, "$.methods[0].name")
      assert_true(diagnostics[0].code is MissingField)
    }
    Ok(_) => fail("methods without names should be rejected")
  }
}

///|
test "rejects a non-object document" {
  let result = Document::parse("[]")
  match result {
    Err(diagnostics) => {
      assert_eq(diagnostics.length(), 1)
      assert_eq(diagnostics[0].path, "$")
      assert_true(diagnostics[0].code is ExpectedObject)
    }
    Ok(_) => fail("an array is not an OpenRPC document")
  }
}

///|
test "finds a method by its contract name" {
  let source =
    #|{"openrpc":"1.4.0","info":{"title":"x","version":"1"},"methods":[{"name":"inventory.get"}]}
  let document = match Document::parse(source) {
    Ok(document) => document
    Err(_) => fail("the fixture should be valid")
  }
  match document.find_method("inventory.get") {
    Some(method_value) => assert_eq(method_value.name, "inventory.get")
    None => fail("the parsed method should be discoverable by name")
  }
}

///|
test "keeps ordered parameters and an optional result schema" {
  let source =
    #|{"openrpc":"1.4.0","info":{"title":"x","version":"1"},"methods":[{"name":"inventory.get","params":[{"name":"id","required":true,"schema":{"type":"string"}},{"name":"verbose","schema":{"type":"boolean"}}],"result":{"name":"item","schema":{"type":"object"}}}]}
  let document = match Document::parse(source) {
    Ok(document) => document
    Err(_) => fail("the fixture should be valid")
  }
  let method_value = match document.find_method("inventory.get") {
    Some(method_value) => method_value
    None => fail("the method should be present")
  }
  assert_eq(method_value.params.length(), 2)
  assert_eq(method_value.params[0].name, "id")
  assert_true(method_value.params[0].required)
  assert_false(method_value.params[1].required)
  assert_true(method_value.params[0].schema is Object(_))
  match method_value.result {
    Some(result_value) => {
      assert_eq(result_value.name, "item")
      assert_true(result_value.schema is Object(_))
    }
    None => fail("the result descriptor should be present")
  }
}

///|
test "rejects duplicate method names" {
  let source =
    #|{"openrpc":"1.4.0","info":{"title":"x","version":"1"},"methods":[{"name":"inventory.get"},{"name":"inventory.get"}]}
  match Document::parse(source) {
    Err(diagnostics) => {
      assert_eq(diagnostics.length(), 1)
      assert_eq(diagnostics[0].path, "$.methods[1].name")
      assert_true(diagnostics[0].code is DuplicateMethod)
    }
    Ok(_) => fail("duplicate method names should be rejected")
  }
}

///|
test "rejects a parameter without a schema" {
  let source =
    #|{"openrpc":"1.4.0","info":{"title":"x","version":"1"},"methods":[{"name":"inventory.get","params":[{"name":"id"}]}]}
  match Document::parse(source) {
    Err(diagnostics) => {
      assert_eq(diagnostics.length(), 1)
      assert_eq(diagnostics[0].path, "$.methods[0].params[0].schema")
      assert_true(diagnostics[0].code is MissingField)
    }
    Ok(_) => fail("a parameter without a schema should be rejected")
  }
}

test "builds a named JSON-RPC request from a method contract" {
  let source =
    #|{"openrpc":"1.4.0","info":{"title":"x","version":"1"},"methods":[{"name":"inventory.get","params":[{"name":"id","required":true,"schema":{"type":"string"}}]}]}
  let document = match Document::parse(source) {
    Ok(document) => document
    Err(_) => fail("the fixture should be valid")
  }
  let method_value = match document.find_method("inventory.get") {
    Some(method_value) => method_value
    None => fail("the method should be present")
  }
  let params : Map[String, Json] = { "id": "abc" }
  match method_value.build_request(7, params) {
    Ok(request) => {
      guard request is {
        "jsonrpc": String(version),
        "method": String(name),
        "params": Object(encoded_params),
        ..
      } else { fail("request should be a JSON-RPC object") }
      assert_eq(version, "2.0")
      assert_eq(name, "inventory.get")
      assert_eq(encoded_params.get("id"), Some(Json::string("abc")))
    }
    Err(_) => fail("a complete request should be constructed")
  }
}
