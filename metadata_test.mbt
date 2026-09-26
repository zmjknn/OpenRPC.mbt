///|
test "parses metadata and validates local component references" {
  let source =
    #|{
    #|  "openrpc":"1.4.0",
    #|  "info":{"title":"Inventory","version":"1.0.0","description":"Catalog API"},
    #|  "servers":[{"name":"primary","url":"https://{region}.example.test/rpc","variables":{"region":{"default":"dev","enum":["dev","staging"]}}}],
    #|  "tags":[{"$ref":"#/components/tags/read"}],
    #|  "components":{
    #|    "schemas":{
    #|      "Id":{"type":"string"},
    #|      "Item":{"type":"object","properties":{"id":{"$ref":"#/components/schemas/Id"}}}
    #|    },
    #|    "examples":{"valid-id":{"name":"valid-id","value":"abc"}},
    #|    "examplePairings":{"get":{"name":"get","params":[{"$ref":"#/components/examples/valid-id"}],"result":{"name":"item","value":{"id":"abc"}}}},
    #|    "contentDescriptors":{
    #|      "id":{"name":"id","required":true,"schema":{"$ref":"#/components/schemas/Id"}},
    #|      "item":{"name":"item","schema":{"$ref":"#/components/schemas/Item"}}
    #|    },
    #|    "tags":{"read":{"name":"read","description":"Read methods"}}
    #|  },
    #|  "methods":[{
    #|    "name":"inventory.get",
    #|    "summary":"Get one item",
    #|    "deprecated":false,
    #|    "tags":[{"$ref":"#/components/tags/read"}],
    #|    "params":[{"$ref":"#/components/contentDescriptors/id"}],
    #|    "result":{"$ref":"#/components/contentDescriptors/item"},
    #|    "examples":[{"$ref":"#/components/examplePairings/get"}]
    #|  }]
    #|}
  let document = match Document::parse(source) {
    Ok(value) => value
    Err(diagnostics) =>
      fail("valid metadata should parse: " + diagnostics[0].message)
  }
  assert_eq(document.info.description, Some("Catalog API"))
  assert_eq(document.tags.length(), 1)
  assert_eq(document.servers.length(), 1)
  assert_eq(document.components.schemas.length(), 2)
  let method_value = match document.find_method("inventory.get") {
    Some(value) => value
    None => fail("method should be available")
  }
  assert_eq(method_value.summary, Some("Get one item"))
  assert_false(method_value.deprecated)
  assert_true(method_value.has_tag("read"))
  assert_eq(method_value.params[0].name, "id")
  assert_eq(method_value.examples[0].params[0].name, "valid-id")
  match document.find_server("primary") {
    Some(server) => {
      match server.render_url(Map([])) {
        Ok(url) => assert_eq(url, "https://dev.example.test/rpc")
        Err(_) => fail("server defaults should render")
      }
      match server.render_url({ "region": "staging" }) {
        Ok(url) => assert_eq(url, "https://staging.example.test/rpc")
        Err(_) => fail("declared server overrides should render")
      }
      match server.render_url({ "region": "production" }) {
        Err(diagnostics) =>
          assert_true(diagnostics[0].code is InvalidServerVariableValue)
        Ok(_) => fail("server enum should reject undeclared values")
      }
    }
    None => fail("server should be discoverable by name")
  }
  assert_eq(document.lint().length(), 0)
  match document.validate_named_params("inventory.get", { "id": "abc" }) {
    Ok(_) => ()
    Err(_) => fail("referenced parameter schema should accept a string")
  }
  match document.validate_named_params("inventory.get", { "id": 42 }) {
    Err(diagnostics) => {
      assert_eq(diagnostics[0].path, "$.params.id")
      assert_true(diagnostics[0].code is SchemaViolation)
    }
    Ok(_) => fail("referenced parameter schema should reject a number")
  }
  match document.validate_result("inventory.get", { "id": "abc" }) {
    Ok(_) => ()
    Err(_) => fail("nested local schema references should validate")
  }
  match document.validate_result("inventory.get", { "id": 42 }) {
    Err(diagnostics) => assert_true(diagnostics[0].code is SchemaViolation)
    Ok(_) => fail("nested local schema references should reject bad values")
  }
}

///|
test "resolves JSON Pointer tokens and rejects external references" {
  let source =
    #|{"openrpc":"1.4.0","info":{"title":"x","version":"1"},"components":{"schemas":{"Model/Item":{"type":"object"}}},"methods":[{"name":"inventory.get"}]}
  let document = match Document::parse(source) {
    Ok(value) => value
    Err(_) => fail("the pointer fixture should parse")
  }
  match document.resolve_ref("#/components/schemas/Model~1Item") {
    Ok(Object(schema)) =>
      assert_true(schema.get("type") is Some(String("object")))
    _ => fail("escaped slash should resolve to the component key")
  }
  match document.resolve_ref("#/methods/0/name") {
    Ok(String(name)) => assert_eq(name, "inventory.get")
    _ => fail("array indexes should work in JSON Pointers")
  }
  match document.resolve_ref("https://example.test/schema.json") {
    Err(diagnostics) => assert_true(diagnostics[0].code is UnsupportedReference)
    Ok(_) => fail("external references must not trigger I/O")
  }
}

///|
test "reports missing and circular references in lint" {
  let missing_source =
    #|{
    #|  "openrpc":"1.4.0",
    #|  "info":{"title":"x","version":"1"},
    #|  "methods":[{"name":"inventory.get","params":[{"$ref":"#/components/contentDescriptors/missing"}]}],
    #|  "components":{"contentDescriptors":{}}
    #|}
  match Document::parse(missing_source) {
    Err(diagnostics) => assert_true(diagnostics[0].code is UnresolvedReference)
    Ok(_) => fail("missing references should fail during parsing")
  }
  let circular_source =
    #|{
    #|  "openrpc":"1.4.0",
    #|  "info":{"title":"x","version":"1"},
    #|  "methods":[{"name":"inventory.get","tags":[{"$ref":"#/components/tags/a"}]}],
    #|  "components":{"tags":{"a":{"$ref":"#/components/tags/b"},"b":{"$ref":"#/components/tags/a"}}}
    #|}
  match Document::parse(circular_source) {
    Err(diagnostics) => assert_true(diagnostics[0].code is CircularReference)
    Ok(_) => fail("cyclic reference chains should be rejected")
  }
}

///|
test "documents lint server URL templates" {
  let source =
    #|{
    #|  "openrpc":"1.4.0",
    #|  "info":{"title":"x","version":"1"},
    #|  "servers":[{"name":"primary","url":"https://{region}.example.test","variables":{"region":{"default":"prod","enum":["dev","test"]}}}],
    #|  "methods":[]
    #|}
  let document = match Document::parse(source) {
    Ok(value) => value
    Err(_) => fail("server template fixture should parse")
  }
  let diagnostics = document.lint()
  assert_true(diagnostics.length() > 0)
  assert_true(diagnostics[0].code is InvalidServerVariableValue)
}

///|
test "diff reports breaking and compatible contract changes" {
  let old_source =
    #|{
    #|  "openrpc":"1.4.0",
    #|  "info":{"title":"x","version":"1"},
    #|  "servers":[{"name":"primary","url":"https://old.example.test"}],
    #|  "methods":[{"name":"inventory.get","params":[{"name":"id","schema":{"type":"string"}}],"result":{"name":"item","schema":{"type":"string"}}}]
    #|}
  let new_source =
    #|{
    #|  "openrpc":"1.4.0",
    #|  "info":{"title":"x","version":"2"},
    #|  "servers":[{"name":"primary","url":"https://new.example.test"}],
    #|  "methods":[
    #|    {"name":"inventory.get","params":[{"name":"id","required":true,"schema":{"type":"integer"}},{"name":"locale","required":true,"schema":{"type":"string"}}],"result":{"name":"item","schema":{"type":"object"}}},
    #|    {"name":"inventory.list"}
    #|  ]
    #|}
  let old_document = match Document::parse(old_source) {
    Ok(value) => value
    Err(_) => fail("old contract fixture should parse")
  }
  let new_document = match Document::parse(new_source) {
    Ok(value) => value
    Err(_) => fail("new contract fixture should parse")
  }
  let changes = old_document.diff(new_document)
  assert_eq(changes.length(), 6)
  let mut requiredness_changed = false
  let mut schema_changed = false
  let mut server_changed = false
  let mut method_added = false
  for change in changes {
    if change.kind is ParameterRequiredChanged && change.impact is Breaking {
      requiredness_changed = true
    }
    if change.kind is ParameterSchemaChanged && change.impact is Breaking {
      schema_changed = true
    }
    if change.kind is ServerChanged && change.impact is Breaking {
      server_changed = true
    }
    if change.kind is MethodAdded && change.impact is Compatible {
      method_added = true
    }
  }
  assert_true(requiredness_changed)
  assert_true(schema_changed)
  assert_true(server_changed)
  assert_true(method_added)
}

///|
test "validates examples against descriptors and referenced schemas" {
  let valid_source =
    #|{
    #|  "openrpc":"1.4.0",
    #|  "info":{"title":"Example API","version":"1.0.0"},
    #|  "components":{"schemas":{"Text":{"type":"string"}}},
    #|  "methods":[{
    #|    "name":"echo",
    #|    "params":[{"name":"message","required":true,"schema":{"$ref":"#/components/schemas/Text","minLength":2}}],
    #|    "result":{"name":"reply","schema":{"type":"string"}},
    #|    "examples":[{"name":"round-trip","params":[{"name":"sample-input","value":"hi"}],"result":{"name":"sample-output","value":"hello"}}]
    #|  }]
    #|}
  let document = match Document::parse(valid_source) {
    Ok(value) => value
    Err(diagnostics) =>
      fail("the valid example fixture should parse: " + diagnostics[0].message)
  }
  match document.validate_examples("echo") {
    Ok(_) => ()
    Err(diagnostics) =>
      fail(
        "the example should satisfy its descriptors: " + diagnostics[0].message,
      )
  }
  match document.validate_named_params("echo", { "message": "x" }) {
    Err(diagnostics) => assert_true(diagnostics[0].code is SchemaViolation)
    Ok(_) =>
      fail("$ref siblings should preserve the inline minLength constraint")
  }

  let invalid_source =
    #|{
    #|  "openrpc":"1.4.0",
    #|  "info":{"title":"Example API","version":"1.0.0"},
    #|  "methods":[{
    #|    "name":"echo",
    #|    "params":[{"name":"message","required":true,"schema":{"type":"string"}}],
    #|    "examples":[{"name":"bad-input","params":[{"name":"arbitrary-example-name","value":42}]}]
    #|  }]
    #|}
  let invalid_document = match Document::parse(invalid_source) {
    Ok(value) => value
    Err(diagnostics) =>
      fail(
        "the structurally valid example should parse: " + diagnostics[0].message,
      )
  }
  match invalid_document.validate_examples("echo") {
    Err(diagnostics) => assert_true(diagnostics[0].code is SchemaViolation)
    Ok(_) => fail("example values must satisfy their parameter schemas")
  }
}
