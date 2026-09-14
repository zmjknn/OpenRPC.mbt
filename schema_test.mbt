///|
test "accepts a value matching a primitive schema" {
  let schema_source =
    #|{"type":"string"}
  let schema = @json.parse(schema_source) catch {
    _ => fail("the schema fixture should be valid JSON")
  }
  match validate_schema(Json::string("ready"), schema) {
    Ok(_) => ()
    Err(_) => fail("a string should satisfy a string schema")
  }
}

///|
test "reports a primitive schema mismatch" {
  let schema_source =
    #|{"type":"number"}
  let schema = @json.parse(schema_source) catch {
    _ => fail("the schema fixture should be valid JSON")
  }
  match validate_schema(Json::string("not-a-number"), schema) {
    Err(diagnostics) => {
      assert_eq(diagnostics.length(), 1)
      assert_eq(diagnostics[0].path, "$")
      assert_true(diagnostics[0].code is SchemaViolation)
    }
    Ok(_) => fail("a string should not satisfy a number schema")
  }
}
