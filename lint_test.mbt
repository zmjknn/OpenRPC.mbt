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

///|
test "reports a non-object schema value" {
  let source =
    #|{"openrpc":"1.4.0","info":{"title":"x","version":"1"},"methods":[{"name":"bad","params":[{"name":"value","schema":"string"}]}]}
  let diagnostics = lint_document(source).lint()
  assert_eq(diagnostics.length(), 1)
  assert_eq(diagnostics[0].path, "$.methods[0].params[0].schema")
  assert_lint_code(diagnostics, 0, "invalid-schema-boundary")
}

///|
test "reports malformed type arrays with indexed paths" {
  let source =
    #|{"openrpc":"1.4.0","info":{"title":"x","version":"1"},"methods":[{"name":"bad","params":[{"name":"value","schema":{"type":["string",3,"date"]}}]}]}
  let diagnostics = lint_document(source).lint()
  assert_eq(diagnostics.length(), 2)
  assert_eq(diagnostics[0].path, "$.methods[0].params[0].schema.type[1]")
  assert_eq(diagnostics[1].path, "$.methods[0].params[0].schema.type[2]")
}

///|
test "reports empty and malformed enum declarations" {
  let empty_source =
    #|{"openrpc":"1.4.0","info":{"title":"x","version":"1"},"methods":[{"name":"empty","params":[{"name":"value","schema":{"enum":[]}}]}]}
  let malformed_source =
    #|{"openrpc":"1.4.0","info":{"title":"x","version":"1"},"methods":[{"name":"malformed","params":[{"name":"value","schema":{"enum":true}}]}]}
  let empty_diagnostics = lint_document(empty_source).lint()
  let malformed_diagnostics = lint_document(malformed_source).lint()
  assert_eq(empty_diagnostics.length(), 1)
  assert_eq(empty_diagnostics[0].path, "$.methods[0].params[0].schema.enum")
  assert_eq(malformed_diagnostics.length(), 1)
  assert_eq(malformed_diagnostics[0].path, "$.methods[0].params[0].schema.enum")
}

///|
test "reports a non-boolean uniqueItems keyword" {
  let source =
    #|{"openrpc":"1.4.0","info":{"title":"x","version":"1"},"methods":[{"name":"bad","params":[{"name":"values","schema":{"type":"array","uniqueItems":"true"}}]}]}
  let diagnostics = lint_document(source).lint()
  assert_eq(diagnostics.length(), 1)
  assert_eq(diagnostics[0].path, "$.methods[0].params[0].schema.uniqueItems")
  assert_lint_code(diagnostics, 0, "invalid-schema-boundary")
}

///|
test "reports malformed properties and additionalProperties" {
  let source =
    #|{"openrpc":"1.4.0","info":{"title":"x","version":"1"},"methods":[{"name":"bad","params":[{"name":"value","schema":{"properties":true,"additionalProperties":7}}]}]}
  let diagnostics = lint_document(source).lint()
  assert_eq(diagnostics.length(), 2)
  assert_eq(diagnostics[0].path, "$.methods[0].params[0].schema.properties")
  assert_eq(
    diagnostics[1].path,
    "$.methods[0].params[0].schema.additionalProperties",
  )
}

///|
test "reports malformed required entries and duplicate names" {
  let source =
    #|{"openrpc":"1.4.0","info":{"title":"x","version":"1"},"methods":[{"name":"bad","params":[{"name":"value","schema":{"required":["id","id",3]}}]}]}
  let diagnostics = lint_document(source).lint()
  assert_eq(diagnostics.length(), 2)
  assert_eq(diagnostics[0].path, "$.methods[0].params[0].schema.required[1]")
  assert_eq(diagnostics[1].path, "$.methods[0].params[0].schema.required[2]")
}

///|
test "reports malformed items and not schemas" {
  let source =
    #|{"openrpc":"1.4.0","info":{"title":"x","version":"1"},"methods":[{"name":"bad","params":[{"name":"items","schema":{"items":[{"type":"string"}]}},{"name":"not","schema":{"not":3}}]}]}
  let diagnostics = lint_document(source).lint()
  assert_eq(diagnostics.length(), 2)
  assert_eq(diagnostics[0].path, "$.methods[0].params[0].schema.items")
  assert_eq(diagnostics[1].path, "$.methods[0].params[1].schema.not")
}

///|
test "reports malformed composition values" {
  let source =
    #|{"openrpc":"1.4.0","info":{"title":"x","version":"1"},"methods":[{"name":"bad","params":[{"name":"all","schema":{"allOf":true}},{"name":"any","schema":{"anyOf":"x"}},{"name":"one","schema":{"oneOf":1}}]}]}
  let diagnostics = lint_document(source).lint()
  assert_eq(diagnostics.length(), 3)
  assert_eq(diagnostics[0].path, "$.methods[0].params[0].schema.allOf")
  assert_eq(diagnostics[1].path, "$.methods[0].params[1].schema.anyOf")
  assert_eq(diagnostics[2].path, "$.methods[0].params[2].schema.oneOf")
}

///|
test "recurses through composition branches" {
  let source =
    #|{"openrpc":"1.4.0","info":{"title":"x","version":"1"},"methods":[{"name":"nested","params":[{"name":"value","schema":{"anyOf":[{"type":"string","minLength":6,"maxLength":2},{"allOf":[{"type":"number","minimum":8,"maximum":1}]}]}}]}]}
  let diagnostics = lint_document(source).lint()
  assert_eq(diagnostics.length(), 2)
  assert_eq(
    diagnostics[0].path,
    "$.methods[0].params[0].schema.anyOf[0].minLength",
  )
  assert_eq(
    diagnostics[1].path,
    "$.methods[0].params[0].schema.anyOf[1].allOf[0].minimum",
  )
}

///|
test "reports property count contradictions" {
  let source =
    #|{"openrpc":"1.4.0","info":{"title":"x","version":"1"},"methods":[{"name":"bad","params":[{"name":"value","schema":{"minProperties":5,"maxProperties":2}}]}]}
  let diagnostics = lint_document(source).lint()
  assert_eq(diagnostics.length(), 1)
  assert_eq(diagnostics[0].path, "$.methods[0].params[0].schema.minProperties")
}

///|
test "reports exclusive numeric contradictions" {
  let source =
    #|{"openrpc":"1.4.0","info":{"title":"x","version":"1"},"methods":[{"name":"bad","params":[{"name":"value","schema":{"exclusiveMinimum":7,"exclusiveMaximum":2}}]}]}
  let diagnostics = lint_document(source).lint()
  assert_eq(diagnostics.length(), 1)
  assert_eq(
    diagnostics[0].path,
    "$.methods[0].params[0].schema.exclusiveMinimum",
  )
}

///|
test "reports multiple independent problems in one method" {
  let source =
    #|{"openrpc":"1.4.0","info":{"title":"x","version":"1"},"methods":[{"name":"","params":[{"name":"x","schema":{"minLength":5,"maxLength":1}},{"name":"x","required":true,"schema":{"type":"string"}}],"result":{"name":"","schema":{"allOf":[]}}}]}
  let diagnostics = lint_document(source).lint()
  assert_eq(diagnostics.length(), 6)
  assert_true(diagnostics[0].code is EmptyMethodName)
  assert_true(diagnostics[1].code is InvalidSchemaBoundary)
  assert_true(diagnostics[2].code is DuplicateParameter)
  assert_true(diagnostics[3].code is OptionalBeforeRequired)
  assert_true(diagnostics[4].code is EmptyResultName)
  assert_true(diagnostics[5].code is InvalidSchemaBoundary)
}

///|
test "accepts boolean schemas during linting" {
  let source =
    #|{"openrpc":"1.4.0","info":{"title":"x","version":"1"},"methods":[{"name":"flag","params":[{"name":"value","schema":true}]}]}
  assert_eq(lint_document(source).lint().length(), 0)
}

///|
test "reports a scalar type keyword" {
  let source =
    #|{"openrpc":"1.4.0","info":{"title":"x","version":"1"},"methods":[{"name":"bad","params":[{"name":"value","schema":{"type":7}}]}]}
  let diagnostics = lint_document(source).lint()
  assert_eq(diagnostics.length(), 1)
  assert_eq(diagnostics[0].path, "$.methods[0].params[0].schema.type")
}

///|
test "walks additionalProperties object schemas" {
  let source =
    #|{"openrpc":"1.4.0","info":{"title":"x","version":"1"},"methods":[{"name":"nested","params":[{"name":"value","schema":{"additionalProperties":{"type":"string","minLength":9,"maxLength":2}}}]}]}
  let diagnostics = lint_document(source).lint()
  assert_eq(diagnostics.length(), 1)
  assert_eq(
    diagnostics[0].path,
    "$.methods[0].params[0].schema.additionalProperties.minLength",
  )
}

///|
test "reports a required keyword that is not an array" {
  let source =
    #|{"openrpc":"1.4.0","info":{"title":"x","version":"1"},"methods":[{"name":"bad","params":[{"name":"value","schema":{"required":false}}]}]}
  let diagnostics = lint_document(source).lint()
  assert_eq(diagnostics.length(), 1)
  assert_eq(diagnostics[0].path, "$.methods[0].params[0].schema.required")
}

///|
test "reports invalid bound types without inventing a value error" {
  let source =
    #|{"openrpc":"1.4.0","info":{"title":"x","version":"1"},"methods":[{"name":"bad","params":[{"name":"value","schema":{"minLength":1.2,"maxProperties":"many"}}]}]}
  let diagnostics = lint_document(source).lint()
  assert_eq(diagnostics.length(), 2)
  assert_true(diagnostics[0].code is InvalidSchemaBoundary)
  assert_true(diagnostics[1].code is InvalidSchemaBoundary)
}

///|
test "recurses into a malformed anyOf child" {
  let source =
    #|{"openrpc":"1.4.0","info":{"title":"x","version":"1"},"methods":[{"name":"bad","params":[{"name":"value","schema":{"anyOf":[{"type":"string"},3]}}]}]}
  let diagnostics = lint_document(source).lint()
  assert_eq(diagnostics.length(), 1)
  assert_eq(diagnostics[0].path, "$.methods[0].params[0].schema.anyOf[1]")
}

///|
test "reports empty enum and empty composition in one schema" {
  let source =
    #|{"openrpc":"1.4.0","info":{"title":"x","version":"1"},"methods":[{"name":"bad","params":[{"name":"value","schema":{"enum":[],"allOf":[]}}]}]}
  let diagnostics = lint_document(source).lint()
  assert_eq(diagnostics.length(), 2)
  assert_eq(diagnostics[0].path, "$.methods[0].params[0].schema.enum")
  assert_eq(diagnostics[1].path, "$.methods[0].params[0].schema.allOf")
}

///|
test "lints a result enum path" {
  let source =
    #|{"openrpc":"1.4.0","info":{"title":"x","version":"1"},"methods":[{"name":"result","result":{"name":"state","schema":{"enum":true}}}]}
  let diagnostics = lint_document(source).lint()
  assert_eq(diagnostics.length(), 1)
  assert_eq(diagnostics[0].path, "$.methods[0].result.schema.enum")
}

///|
test "ignores documented extension keywords" {
  let source =
    #|{"openrpc":"1.4.0","info":{"title":"x","version":"1"},"methods":[{"name":"ok","params":[{"name":"value","schema":{"type":"string","description":"text","format":"custom","x-owner":"inventory"}}]}]}
  assert_eq(lint_document(source).lint().length(), 0)
}

///|
test "reports nested property type errors at the child path" {
  let source =
    #|{"openrpc":"1.4.0","info":{"title":"x","version":"1"},"methods":[{"name":"nested","params":[{"name":"value","schema":{"properties":{"profile":{"properties":{"age":{"type":"date"}}}}}}]}]}
  let diagnostics = lint_document(source).lint()
  assert_eq(diagnostics.length(), 1)
  assert_eq(
    diagnostics[0].path,
    "$.methods[0].params[0].schema.properties.profile.properties.age.type",
  )
}

///|
test "reports nested result composition paths" {
  let source =
    #|{"openrpc":"1.4.0","info":{"title":"x","version":"1"},"methods":[{"name":"nested","result":{"name":"value","schema":{"not":{"allOf":[{"type":"string","minLength":9,"maxLength":2}]}}}}]}
  let diagnostics = lint_document(source).lint()
  assert_eq(diagnostics.length(), 1)
  assert_eq(
    diagnostics[0].path,
    "$.methods[0].result.schema.not.allOf[0].minLength",
  )
}

///|
test "keeps duplicate required diagnostics local to their schema" {
  let source =
    #|{"openrpc":"1.4.0","info":{"title":"x","version":"1"},"methods":[{"name":"first","params":[{"name":"value","schema":{"required":["id","id"]}}]},{"name":"second","params":[{"name":"value","schema":{"required":["id","id"]}}]}]}
  let diagnostics = lint_document(source).lint()
  assert_eq(diagnostics.length(), 2)
  assert_true(diagnostics[0].path.has_prefix("$.methods[0]"))
  assert_true(diagnostics[1].path.has_prefix("$.methods[1]"))
}

///|
test "walks several child schemas without collapsing their paths" {
  let source =
    #|{"openrpc":"1.4.0","info":{"title":"x","version":"1"},"methods":[{"name":"children","params":[{"name":"payload","schema":{"properties":{"left":{"type":"date"},"right":{"items":{"type":"date"}}}}}]}]}
  let diagnostics = lint_document(source).lint()
  assert_eq(diagnostics.length(), 2)
  assert_eq(
    diagnostics[0].path,
    "$.methods[0].params[0].schema.properties.left.type",
  )
  assert_eq(
    diagnostics[1].path,
    "$.methods[0].params[0].schema.properties.right.items.type",
  )
}

///|
test "accepts a fully bounded nested schema" {
  let source =
    #|{"openrpc":"1.4.0","info":{"title":"x","version":"1"},"methods":[{"name":"bounded","params":[{"name":"payload","schema":{"type":"object","minProperties":1,"maxProperties":2,"required":["items"],"properties":{"items":{"type":"array","minItems":1,"maxItems":3,"uniqueItems":true,"items":{"type":"string","minLength":1,"maxLength":12}}},"additionalProperties":false}}]}]}
  assert_eq(lint_document(source).lint().length(), 0)
}

///|
test "reports a malformed nested bound and keeps later methods visible" {
  let source =
    #|{"openrpc":"1.4.0","info":{"title":"x","version":"1"},"methods":[{"name":"bad","params":[{"name":"value","schema":{"properties":{"nested":{"minItems":-1}}}}]},{"name":"good","params":[{"name":"value","schema":{"type":"string"}}]}]}
  let diagnostics = lint_document(source).lint()
  assert_eq(diagnostics.length(), 1)
  assert_eq(
    diagnostics[0].path,
    "$.methods[0].params[0].schema.properties.nested.minItems",
  )
}

///|
test "linting an empty methods list is a valid no-op" {
  let source =
    #|{"openrpc":"1.4.0","info":{"title":"x","version":"1"},"methods":[]}
  let document = lint_document(source)
  assert_eq(document.lint().length(), 0)
}

///|
test "lint output is repeatable for the same document" {
  let source =
    #|{"openrpc":"1.4.0","info":{"title":"x","version":"1"},"methods":[{"name":"bad","params":[{"name":"x","schema":{"minItems":4,"maxItems":1}}]}]}
  let document = lint_document(source)
  let first = document.lint()
  let second = document.lint()
  assert_eq(first.length(), second.length())
  assert_eq(first[0].path, second[0].path)
}
