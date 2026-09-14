///|
fn lint_document(source : String) -> Document raise {
  match Document::parse(source) {
    Ok(document) => document
    Err(_) => fail("the lint fixture should parse before linting")
  }
}

///|
fn assert_lint_code(
  diagnostics : Array[Diagnostic],
  index : Int,
  code : String,
) -> Unit raise {
  match code {
    "empty-method" => assert_true(diagnostics[index].code is EmptyMethodName)
    "empty-parameter" =>
      assert_true(diagnostics[index].code is EmptyParameterName)
    "empty-result" => assert_true(diagnostics[index].code is EmptyResultName)
    "duplicate-parameter" =>
      assert_true(diagnostics[index].code is DuplicateParameter)
    "optional-before-required" =>
      assert_true(diagnostics[index].code is OptionalBeforeRequired)
    "invalid-schema-boundary" =>
      assert_true(diagnostics[index].code is InvalidSchemaBoundary)
    _ => fail("the lint helper received an unknown code name")
  }
}

///|
test "accepts a semantically complete contract" {
  let source =
    #|{"openrpc":"1.4.0","info":{"title":"Inventory","version":"1"},"methods":[{"name":"inventory.get","params":[{"name":"id","required":true,"schema":{"type":"string"}},{"name":"verbose","schema":{"type":"boolean"}}],"result":{"name":"item","schema":{"type":"object","required":["id"],"properties":{"id":{"type":"string"}}}}}]}
  let diagnostics = lint_document(source).lint()
  assert_eq(diagnostics.length(), 0)
}

///|
test "reports empty method, parameter, and result names" {
  let source =
    #|{"openrpc":"1.4.0","info":{"title":"x","version":"1"},"methods":[{"name":"","params":[{"name":"","schema":{"type":"string"}}],"result":{"name":"","schema":{"type":"null"}}}]}
  let diagnostics = lint_document(source).lint()
  assert_eq(diagnostics.length(), 3)
  assert_eq(diagnostics[0].path, "$.methods[0].name")
  assert_lint_code(diagnostics, 0, "empty-method")
  assert_eq(diagnostics[1].path, "$.methods[0].params[0].name")
  assert_lint_code(diagnostics, 1, "empty-parameter")
  assert_eq(diagnostics[2].path, "$.methods[0].result.name")
  assert_lint_code(diagnostics, 2, "empty-result")
}

///|
test "reports duplicate parameter names" {
  let source =
    #|{"openrpc":"1.4.0","info":{"title":"x","version":"1"},"methods":[{"name":"echo","params":[{"name":"value","schema":{"type":"string"}},{"name":"value","schema":{"type":"string"}}]}]}
  let diagnostics = lint_document(source).lint()
  assert_eq(diagnostics.length(), 1)
  assert_eq(diagnostics[0].path, "$.methods[0].params[1].name")
  assert_lint_code(diagnostics, 0, "duplicate-parameter")
}

///|
test "reports required parameters after optional positional parameters" {
  let source =
    #|{"openrpc":"1.4.0","info":{"title":"x","version":"1"},"methods":[{"name":"ambiguous","params":[{"name":"prefix","schema":{"type":"string"}},{"name":"suffix","required":true,"schema":{"type":"string"}}]}]}
  let diagnostics = lint_document(source).lint()
  assert_eq(diagnostics.length(), 1)
  assert_eq(diagnostics[0].path, "$.methods[0].params[1]")
  assert_lint_code(diagnostics, 0, "optional-before-required")
}

///|
test "accepts optional parameters only at the end" {
  let source =
    #|{"openrpc":"1.4.0","info":{"title":"x","version":"1"},"methods":[{"name":"ordered","params":[{"name":"first","required":true,"schema":{"type":"string"}},{"name":"second","schema":{"type":"integer"}},{"name":"third","schema":{"type":"boolean"}}]}]}
  let diagnostics = lint_document(source).lint()
  assert_eq(diagnostics.length(), 0)
}

///|
test "reports contradictory string and array bounds" {
  let source =
    #|{"openrpc":"1.4.0","info":{"title":"x","version":"1"},"methods":[{"name":"bad","params":[{"name":"text","schema":{"type":"string","minLength":8,"maxLength":2}},{"name":"items","schema":{"type":"array","minItems":4,"maxItems":1}}]}]}
  let diagnostics = lint_document(source).lint()
  assert_eq(diagnostics.length(), 2)
  assert_eq(diagnostics[0].path, "$.methods[0].params[0].schema.minLength")
  assert_lint_code(diagnostics, 0, "invalid-schema-boundary")
  assert_eq(diagnostics[1].path, "$.methods[0].params[1].schema.minItems")
  assert_lint_code(diagnostics, 1, "invalid-schema-boundary")
}

///|
test "reports contradictory numeric bounds" {
  let source =
    #|{"openrpc":"1.4.0","info":{"title":"x","version":"1"},"methods":[{"name":"bad","params":[{"name":"value","schema":{"type":"number","minimum":10,"maximum":2}}]}]}
  let diagnostics = lint_document(source).lint()
  assert_eq(diagnostics.length(), 1)
  assert_eq(diagnostics[0].path, "$.methods[0].params[0].schema.minimum")
  assert_lint_code(diagnostics, 0, "invalid-schema-boundary")
}

///|
test "reports malformed and negative schema bounds" {
  let source =
    #|{"openrpc":"1.4.0","info":{"title":"x","version":"1"},"methods":[{"name":"bad","params":[{"name":"text","schema":{"minLength":true}},{"name":"items","schema":{"maxItems":-1}},{"name":"value","schema":{"minimum":"zero"}}]}]}
  let diagnostics = lint_document(source).lint()
  assert_eq(diagnostics.length(), 3)
  assert_eq(diagnostics[0].path, "$.methods[0].params[0].schema.minLength")
  assert_eq(diagnostics[1].path, "$.methods[0].params[1].schema.maxItems")
  assert_eq(diagnostics[2].path, "$.methods[0].params[2].schema.minimum")
  assert_lint_code(diagnostics, 0, "invalid-schema-boundary")
  assert_lint_code(diagnostics, 1, "invalid-schema-boundary")
  assert_lint_code(diagnostics, 2, "invalid-schema-boundary")
}

///|
test "reports empty composition arrays" {
  let source =
    #|{"openrpc":"1.4.0","info":{"title":"x","version":"1"},"methods":[{"name":"bad","params":[{"name":"all","schema":{"allOf":[]}},{"name":"any","schema":{"anyOf":[]}},{"name":"one","schema":{"oneOf":[]}}]}]}
  let diagnostics = lint_document(source).lint()
  assert_eq(diagnostics.length(), 3)
  assert_eq(diagnostics[0].path, "$.methods[0].params[0].schema.allOf")
  assert_eq(diagnostics[1].path, "$.methods[0].params[1].schema.anyOf")
  assert_eq(diagnostics[2].path, "$.methods[0].params[2].schema.oneOf")
  assert_lint_code(diagnostics, 0, "invalid-schema-boundary")
  assert_lint_code(diagnostics, 1, "invalid-schema-boundary")
  assert_lint_code(diagnostics, 2, "invalid-schema-boundary")
}

///|
test "walks nested properties and item schemas" {
  let source =
    #|{"openrpc":"1.4.0","info":{"title":"x","version":"1"},"methods":[{"name":"nested","params":[{"name":"payload","schema":{"type":"object","properties":{"records":{"type":"array","items":{"type":"object","properties":{"name":{"type":"string","minLength":5,"maxLength":1}}}}}}}]}]}
  let diagnostics = lint_document(source).lint()
  assert_eq(diagnostics.length(), 1)
  assert_eq(
    diagnostics[0].path,
    "$.methods[0].params[0].schema.properties.records.items.properties.name.minLength",
  )
  assert_lint_code(diagnostics, 0, "invalid-schema-boundary")
}

///|
test "returns diagnostics in method and parameter order" {
  let source =
    #|{"openrpc":"1.4.0","info":{"title":"x","version":"1"},"methods":[{"name":"first","params":[{"name":"x","schema":{"minLength":5,"maxLength":1}}]},{"name":"second","params":[{"name":"x","schema":{"minItems":4,"maxItems":2}}]}]}
  let diagnostics = lint_document(source).lint()
  assert_eq(diagnostics.length(), 2)
  assert_true(diagnostics[0].path.has_prefix("$.methods[0]"))
  assert_true(diagnostics[1].path.has_prefix("$.methods[1]"))
}

///|
test "lints result schemas as well as parameter schemas" {
  let source =
    #|{"openrpc":"1.4.0","info":{"title":"x","version":"1"},"methods":[{"name":"result","result":{"name":"value","schema":{"type":"number","minimum":9,"maximum":3}}}]}
  let diagnostics = lint_document(source).lint()
  assert_eq(diagnostics.length(), 1)
  assert_eq(diagnostics[0].path, "$.methods[0].result.schema.minimum")
  assert_lint_code(diagnostics, 0, "invalid-schema-boundary")
}

///|
test "does not mutate or reject request construction" {
  let source =
    #|{"openrpc":"1.4.0","info":{"title":"x","version":"1"},"methods":[{"name":"ambiguous","params":[{"name":"optional","schema":{"type":"string"}},{"name":"required","required":true,"schema":{"type":"string"}}]}]}
  let document = lint_document(source)
  let diagnostics = document.lint()
  assert_eq(diagnostics.length(), 1)
  let method_value = match document.find_method("ambiguous") {
    Some(value) => value
    None => fail("the method should remain available")
  }
  match method_value.build_positional_request(1, ["x", "y"]) {
    Ok(_) => ()
    Err(_) => fail("linting should not alter request construction")
  }
}
