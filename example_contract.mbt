///|
/// The contract used by the reproducible quickstart package.
pub fn quickstart_source() -> String {
  (
    #|{
    #|  "openrpc":"1.4.0",
    #|  "info":{"title":"Inventory","version":"1.0.0"},
    #|  "methods":[
    #|    {"name":"inventory.get","params":[{"name":"id","required":true,"schema":{"type":"string"}}],"result":{"name":"item","schema":{"type":"object"}}}
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
  Ok("method=" + method_value.name + ", request=" + request.stringify())
}
