///|
fn schema_fixture(source : String) -> Json raise {
  @json.parse(source) catch {
    _ => fail("the schema fixture should be valid JSON")
  }
}

///|
fn assert_schema_accepts(value : Json, schema : Json) -> Unit raise {
  match validate_schema(value, schema) {
    Ok(_) => ()
    Err(diagnostics) =>
      fail("expected schema acceptance, got " + diagnostics[0].message)
  }
}

///|
fn assert_schema_rejects(
  value : Json,
  schema : Json,
  expected_violation : Bool,
  expected_path : String,
) -> Unit raise {
  match validate_schema(value, schema) {
    Ok(_) => fail("expected schema rejection")
    Err(diagnostics) => {
      assert_true(diagnostics.length() > 0)
      assert_eq(diagnostics[0].path, expected_path)
      if expected_violation {
        assert_true(diagnostics[0].code is SchemaViolation)
      } else {
        assert_true(diagnostics[0].code is UnsupportedSchema)
      }
    }
  }
}

///|
test "accepts a value matching a primitive schema" {
  let schema_source =
    #|{"type":"string"}
  let schema = schema_fixture(schema_source)
  assert_schema_accepts(Json::string("ready"), schema)
}

///|
test "reports a primitive schema mismatch" {
  let schema_source =
    #|{"type":"number"}
  let schema = schema_fixture(schema_source)
  assert_schema_rejects(Json::string("not-a-number"), schema, true, "$")
}

///|
test "supports boolean schemas" {
  assert_schema_accepts(Json::string("ok"), true)
  assert_schema_rejects(Json::string("blocked"), false, true, "$")
}

///|
test "matches every primitive schema type" {
  let null_schema =
    #|{"type":"null"}
  let bool_schema =
    #|{"type":"boolean"}
  let object_schema =
    #|{"type":"object"}
  let array_schema =
    #|{"type":"array"}
  let number_schema =
    #|{"type":"number"}
  let integer_schema =
    #|{"type":"integer"}
  let string_schema =
    #|{"type":"string"}
  assert_schema_accepts(null, schema_fixture(null_schema))
  assert_schema_accepts(true, schema_fixture(bool_schema))
  assert_schema_accepts(Json::object({}), schema_fixture(object_schema))
  assert_schema_accepts(Json::array([]), schema_fixture(array_schema))
  assert_schema_accepts(2.5, schema_fixture(number_schema))
  assert_schema_accepts(2, schema_fixture(integer_schema))
  assert_schema_accepts(Json::string("moon"), schema_fixture(string_schema))
}

///|
test "accepts a union of primitive types" {
  let source =
    #|{"type":["string","null"]}
  let schema = schema_fixture(source)
  assert_schema_accepts(Json::string("ready"), schema)
  assert_schema_accepts(null, schema)
  assert_schema_rejects(1, schema, true, "$")
}

///|
test "rejects an unknown or malformed type declaration" {
  let unknown =
    #|{"type":"date"}
  let non_string =
    #|{"type":true}
  let empty =
    #|{"type":[]}
  assert_schema_rejects(
    Json::string("x"),
    schema_fixture(unknown),
    false,
    "$.type",
  )
  assert_schema_rejects(
    Json::string("x"),
    schema_fixture(non_string),
    false,
    "$.type",
  )
  assert_schema_rejects(
    Json::string("x"),
    schema_fixture(empty),
    false,
    "$.type",
  )
}

///|
test "enforces enum and const" {
  let enum_source =
    #|{"enum":["draft","published"]}
  let enum_schema = schema_fixture(enum_source)
  assert_schema_accepts(Json::string("draft"), enum_schema)
  assert_schema_rejects(Json::string("archived"), enum_schema, true, "$")
  let const_source =
    #|{"const":{"state":"ready"}}
  let matching =
    #|{"state":"ready"}
  let mismatching =
    #|{"state":"busy"}
  let const_schema = schema_fixture(const_source)
  assert_schema_accepts(schema_fixture(matching), const_schema)
  assert_schema_rejects(schema_fixture(mismatching), const_schema, true, "$")
}

///|
test "enforces string length boundaries" {
  let source =
    #|{"type":"string","minLength":2,"maxLength":4}
  let schema = schema_fixture(source)
  assert_schema_accepts(Json::string("moon"), schema)
  assert_schema_rejects(Json::string("m"), schema, true, "$")
  assert_schema_rejects(Json::string("mooncakes"), schema, true, "$")
}

///|
test "reports malformed string boundaries" {
  let negative =
    #|{"minLength":-1}
  let fractional =
    #|{"maxLength":1.5}
  assert_schema_rejects(
    Json::string("x"),
    schema_fixture(negative),
    false,
    "$.minLength",
  )
  assert_schema_rejects(
    Json::string("x"),
    schema_fixture(fractional),
    false,
    "$.maxLength",
  )
}

///|
test "enforces inclusive and exclusive numeric boundaries" {
  let source =
    #|{"type":"number","minimum":1,"maximum":5,"exclusiveMinimum":1,"exclusiveMaximum":5}
  let schema = schema_fixture(source)
  assert_schema_accepts(3, schema)
  assert_schema_rejects(1, schema, true, "$")
  assert_schema_rejects(5, schema, true, "$")
  assert_schema_rejects(0, schema, true, "$")
  assert_schema_rejects(6, schema, true, "$")
}

///|
test "distinguishes integer values from fractional numbers" {
  let source =
    #|{"type":"integer"}
  let schema = schema_fixture(source)
  assert_schema_accepts(3, schema)
  assert_schema_rejects(3.25, schema, true, "$")
}

///|
test "reports malformed numeric boundaries" {
  let minimum =
    #|{"minimum":"3"}
  let maximum =
    #|{"maximum":true}
  assert_schema_rejects(3, schema_fixture(minimum), false, "$.minimum")
  assert_schema_rejects(3, schema_fixture(maximum), false, "$.maximum")
}

///|
test "validates array items and size" {
  let source =
    #|{"type":"array","items":{"type":"integer"},"minItems":2,"maxItems":3}
  let schema = schema_fixture(source)
  assert_schema_accepts(Json::array([1, 2]), schema)
  assert_schema_rejects(Json::array([1]), schema, true, "$")
  assert_schema_rejects(Json::array([1, 2, 3, 4]), schema, true, "$")
  assert_schema_rejects(Json::array([1, "two"]), schema, true, "$[1]")
}

///|
test "enforces unique array items" {
  let source =
    #|{"type":"array","uniqueItems":true}
  let malformed =
    #|{"uniqueItems":"yes"}
  let schema = schema_fixture(source)
  assert_schema_accepts(Json::array([1, 2, 3]), schema)
  assert_schema_rejects(Json::array([1, 2, 1]), schema, true, "$")
  assert_schema_rejects(
    Json::array([1]),
    schema_fixture(malformed),
    false,
    "$.uniqueItems",
  )
}

///|
test "rejects tuple-style item arrays as an explicit boundary" {
  let source =
    #|{"items":[{"type":"integer"},{"type":"string"}]}
  assert_schema_rejects(
    Json::array([1, "x"]),
    schema_fixture(source),
    false,
    "$.items",
  )
}

///|
test "validates required properties and declared property schemas" {
  let source =
    #|{"type":"object","required":["id"],"properties":{"id":{"type":"string"},"count":{"type":"integer"}}}
  let complete =
    #|{"id":"a","count":2}
  let missing =
    #|{"count":2}
  let wrong =
    #|{"id":3}
  let schema = schema_fixture(source)
  assert_schema_accepts(schema_fixture(complete), schema)
  assert_schema_rejects(schema_fixture(missing), schema, true, "$.id")
  assert_schema_rejects(schema_fixture(wrong), schema, true, "$.id")
}

///|
test "controls additional properties with boolean and schema values" {
  let closed_source =
    #|{"type":"object","properties":{"id":{"type":"string"}},"additionalProperties":false}
  let closed_value =
    #|{"id":"a"}
  let extra_value =
    #|{"id":"a","extra":1}
  let closed = schema_fixture(closed_source)
  assert_schema_accepts(schema_fixture(closed_value), closed)
  assert_schema_rejects(schema_fixture(extra_value), closed, true, "$.extra")
  let typed_source =
    #|{"type":"object","properties":{"id":{"type":"string"}},"additionalProperties":{"type":"number"}}
  let typed_value =
    #|{"id":"a","extra":1}
  let wrong_value =
    #|{"id":"a","extra":false}
  let typed = schema_fixture(typed_source)
  assert_schema_accepts(schema_fixture(typed_value), typed)
  assert_schema_rejects(schema_fixture(wrong_value), typed, true, "$.extra")
}

///|
test "enforces object property count and validates required names" {
  let source =
    #|{"type":"object","minProperties":1,"maxProperties":2,"required":["name"]}
  let valid =
    #|{"name":"moon"}
  let too_many =
    #|{"name":"moon","x":1,"y":2}
  let schema = schema_fixture(source)
  assert_schema_accepts(schema_fixture(valid), schema)
  assert_schema_rejects(Json::object({}), schema, true, "$")
  assert_schema_rejects(schema_fixture(too_many), schema, true, "$")
}

///|
test "supports allOf composition" {
  let source =
    #|{"allOf":[{"type":"number"},{"minimum":2},{"maximum":4}]}
  let malformed =
    #|{"allOf":true}
  let schema = schema_fixture(source)
  assert_schema_accepts(3, schema)
  assert_schema_rejects(1, schema, true, "$")
  assert_schema_rejects(3, schema_fixture(malformed), false, "$.allOf")
}

///|
test "supports anyOf and oneOf composition" {
  let any_source =
    #|{"anyOf":[{"type":"string"},{"type":"integer"}]}
  let one_source =
    #|{"oneOf":[{"type":"number"},{"type":"integer"}]}
  let any_schema = schema_fixture(any_source)
  let one_schema = schema_fixture(one_source)
  assert_schema_accepts(Json::string("ok"), any_schema)
  assert_schema_accepts(2, any_schema)
  assert_schema_rejects(true, any_schema, true, "$")
  assert_schema_accepts(2.5, one_schema)
  assert_schema_rejects(2, one_schema, true, "$")
}

///|
test "supports not composition" {
  let source =
    #|{"not":{"type":"null"}}
  let schema = schema_fixture(source)
  assert_schema_accepts(Json::string("not-null"), schema)
  assert_schema_rejects(null, schema, true, "$")
}

///|
test "reports nested paths for item and property violations" {
  let schema_source =
    #|{"type":"object","properties":{"items":{"type":"array","items":{"type":"object","required":["id"],"properties":{"id":{"type":"integer"}}}}}}
  let value_source =
    #|{"items":[{"id":"wrong"}]}
  assert_schema_rejects(
    schema_fixture(value_source),
    schema_fixture(schema_source),
    true,
    "$.items[0].id",
  )
}

///|
test "ignores non-semantic extension keywords" {
  let source =
    #|{"type":"string","description":"human text","default":"x","x-moonbit":"extension"}
  assert_schema_accepts(Json::string("ok"), schema_fixture(source))
}

///|
test "validates declared parameter and result schemas" {
  let source =
    #|{
    #|  "openrpc":"1.4.0",
    #|  "info":{"title":"Inventory","version":"1"},
    #|  "methods":[{"name":"inventory.get","params":[{"name":"id","required":true,"schema":{"type":"string"}},{"name":"limit","schema":{"type":"integer","minimum":1}}],"result":{"name":"item","schema":{"type":"object","required":["id"],"properties":{"id":{"type":"string"}}}}}]
    #|}
  let document = match Document::parse(source) {
    Ok(value) => value
    Err(_) => fail("the OpenRPC schema fixture should parse")
  }
  let method_value = match document.find_method("inventory.get") {
    Some(value) => value
    None => fail("the method should be present")
  }
  let valid_named : Map[String, Json] = { "id": "abc", "limit": 2 }
  match method_value.validate_named_params(valid_named) {
    Ok(_) => ()
    Err(_) => fail("valid named values should satisfy parameter schemas")
  }
  let invalid_named : Map[String, Json] = { "id": 7, "limit": 2 }
  match method_value.validate_named_params(invalid_named) {
    Err(diagnostics) => {
      assert_eq(diagnostics[0].path, "$.params.id")
      assert_true(diagnostics[0].code is SchemaViolation)
    }
    Ok(_) => fail("the id schema should reject a number")
  }
  match method_value.build_request(1, invalid_named) {
    Ok(_) => ()
    Err(_) => fail("builders remain schema-agnostic")
  }
  let invalid_limit : Map[String, Json] = { "id": "abc", "limit": 0 }
  match method_value.validate_named_params(invalid_limit) {
    Err(diagnostics) => {
      assert_eq(diagnostics[0].path, "$.params.limit")
      assert_true(diagnostics[0].code is SchemaViolation)
    }
    Ok(_) => fail("minimum should reject a zero limit")
  }
  let valid_result =
    #|{"id":"abc"}
  let invalid_result =
    #|{"id":false}
  match method_value.validate_result(schema_fixture(valid_result)) {
    Ok(_) => ()
    Err(_) => fail("the result object should satisfy its schema")
  }
  match method_value.validate_result(schema_fixture(invalid_result)) {
    Err(diagnostics) => {
      assert_eq(diagnostics[0].path, "$.result.id")
      assert_true(diagnostics[0].code is SchemaViolation)
    }
    Ok(_) => fail("the result id should be a string")
  }
}

///|
test "validates positional parameter schemas and optional omissions" {
  let source =
    #|{"openrpc":"1.4.0","info":{"title":"x","version":"1"},"methods":[{"name":"sum","params":[{"name":"left","required":true,"schema":{"type":"integer"}},{"name":"right","schema":{"type":"integer"}}]}]}
  let document = match Document::parse(source) {
    Ok(value) => value
    Err(_) => fail("the fixture should parse")
  }
  let method_value = match document.find_method("sum") {
    Some(value) => value
    None => fail("the method should be present")
  }
  match method_value.validate_positional_params([1]) {
    Ok(_) => ()
    Err(_) => fail("optional positional parameters may be omitted")
  }
  match method_value.validate_positional_params([1, 2]) {
    Ok(_) => ()
    Err(_) => fail("valid positional parameters should pass")
  }
  match method_value.validate_positional_params([1, Json::string("bad")]) {
    Err(diagnostics) => {
      assert_eq(diagnostics[0].path, "$.params[1]")
      assert_true(diagnostics[0].code is SchemaViolation)
    }
    Ok(_) => fail("the second positional value should be an integer")
  }
}

///|
test "parameter and result validation expose stable paths" {
  let source =
    #|{"openrpc":"1.4.0","info":{"title":"x","version":"1"},"methods":[{"name":"count","params":[{"name":"token","required":true,"schema":{"type":"string","minLength":3}}],"result":{"name":"count","schema":{"type":"integer","minimum":0}}}]}
  let document = match Document::parse(source) {
    Ok(value) => value
    Err(_) => fail("the fixture should parse")
  }
  let method_value = match document.find_method("count") {
    Some(value) => value
    None => fail("the method should be present")
  }
  let invalid : Map[String, Json] = { "token": "ok" }
  match method_value.validate_named_params(invalid) {
    Err(diagnostics) => assert_eq(diagnostics[0].path, "$.params.token")
    Ok(_) => fail("a short token should be rejected")
  }
  match method_value.validate_result(-1) {
    Err(diagnostics) => assert_eq(diagnostics[0].path, "$.result")
    Ok(_) => fail("a negative count should be rejected")
  }
}
