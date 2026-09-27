///|
/// The contract used by the reproducible quickstart package.
pub fn quickstart_source() -> String {
  (
    #|{
    #|  "openrpc":"1.4.0",
    #|  "info":{"title":"Inventory","version":"1.0.0","description":"A small inventory JSON-RPC API"},
    #|  "servers":[{"name":"primary","url":"https://{region}.inventory.example/rpc","variables":{"region":{"default":"dev","enum":["dev","staging"]}}}],
    #|  "components":{
    #|    "schemas":{
    #|      "InventoryId":{"type":"string","minLength":1},
    #|      "InventoryItem":{"type":"object","properties":{"id":{"$ref":"#/components/schemas/InventoryId"}}}
    #|    }
    #|  },
    #|  "methods":[
    #|    {"name":"inventory.get","summary":"Look up one item","tags":[{"name":"inventory"}],"params":[{"name":"id","required":true,"schema":{"$ref":"#/components/schemas/InventoryId"}}],"result":{"name":"item","schema":{"$ref":"#/components/schemas/InventoryItem"}},"examples":[{"name":"example-item","params":[{"name":"id","value":"abc"}],"result":{"name":"item","value":{"id":"abc"}}}]}
    #|  ]
    #|}
  )
}

///|
/// Produce the deterministic summary printed by the quickstart executable.
pub fn quickstart_summary() -> Result[String, Array[Diagnostic]] {
  let document = match Document::parse(quickstart_source()) {
    Ok(value) => value
    Err(diagnostics) => return Err(diagnostics)
  }
  let method_value = match document.find_method("inventory.get") {
    Some(value) => value
    None =>
      return Err([
        diagnostic("$.methods", UnknownMethod, "quickstart method is missing"),
      ])
  }
  let request = match method_value.build_request(7, { "id": "abc" }) {
    Ok(value) => value
    Err(diagnostics) => return Err(diagnostics)
  }
  match document.validate_named_params("inventory.get", { "id": "abc" }) {
    Ok(_) => ()
    Err(diagnostics) => return Err(diagnostics)
  }
  match document.validate_examples("inventory.get") {
    Ok(_) => ()
    Err(diagnostics) => return Err(diagnostics)
  }
  let server = match document.find_server("primary") {
    Some(value) => value
    None =>
      return Err([
        diagnostic(
          "$.servers",
          UnknownServerVariable,
          "quickstart server is missing",
        ),
      ])
  }
  let server_url = match server.render_url(Map([])) {
    Ok(value) => value
    Err(diagnostics) => return Err(diagnostics)
  }
  Ok(
    "method=" +
    method_value.name +
    ", server=" +
    server_url +
    ", request=" +
    request.stringify(),
  )
}
