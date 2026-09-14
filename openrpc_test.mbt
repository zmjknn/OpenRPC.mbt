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
