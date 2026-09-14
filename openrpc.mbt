///|
pub struct Info {
  title : String
  version : String
}

///|
pub struct Method {
  name : String
}

///|
pub struct Document {
  openrpc : String
  info : Info
  methods : Array[Method]
}

///|
pub enum DiagnosticCode {
  InvalidJson
  ExpectedObject
  MissingField
  InvalidField
  UnsupportedVersion
}

///|
pub struct Diagnostic {
  path : String
  code : DiagnosticCode
  message : String
}

///|
pub fn Document::parse(source : String) -> Result[Document, Array[Diagnostic]] {
  let value = @json.parse(source) catch {
    _ => return Err([diagnostic("$", InvalidJson, "source is not valid JSON")])
  }
  parse_document(value)
}

///|
fn parse_document(value : Json) -> Result[Document, Array[Diagnostic]] {
  guard value is Object(root) else {
    return Err([
      diagnostic("$", ExpectedObject, "OpenRPC document must be an object"),
    ])
  }
  let version = match root.get("openrpc") {
    Some(String(value)) => value
    Some(_) =>
      return Err([
        diagnostic("$.openrpc", InvalidField, "openrpc must be a string"),
      ])
    None =>
      return Err([
        diagnostic("$.openrpc", MissingField, "required field is missing"),
      ])
  }
  if !version.has_prefix("1.") {
    return Err([
      diagnostic(
        "$.openrpc",
        UnsupportedVersion,
        "only OpenRPC 1.x documents are supported",
      ),
    ])
  }
  let info = match root.get("info") {
    Some(Object(info)) =>
      match parse_info(info) {
        Ok(value) => value
        Err(diagnostics) => return Err(diagnostics)
      }
    Some(_) =>
      return Err([diagnostic("$.info", InvalidField, "info must be an object")])
    None =>
      return Err([
        diagnostic("$.info", MissingField, "required field is missing"),
      ])
  }
  let methods = match root.get("methods") {
    Some(Array(methods)) =>
      match parse_methods(methods) {
        Ok(value) => value
        Err(diagnostics) => return Err(diagnostics)
      }
    Some(_) =>
      return Err([
        diagnostic("$.methods", InvalidField, "methods must be an array"),
      ])
    None =>
      return Err([
        diagnostic("$.methods", MissingField, "required field is missing"),
      ])
  }
  Ok({ openrpc: version, info, methods, })
}

///|
fn parse_info(value : Map[String, Json]) -> Result[Info, Array[Diagnostic]] {
  let title = match value.get("title") {
    Some(String(value)) => value
    Some(_) =>
      return Err([
        diagnostic("$.info.title", InvalidField, "title must be a string"),
      ])
    None =>
      return Err([
        diagnostic("$.info.title", MissingField, "required field is missing"),
      ])
  }
  let version = match value.get("version") {
    Some(String(value)) => value
    Some(_) =>
      return Err([
        diagnostic("$.info.version", InvalidField, "version must be a string"),
      ])
    None =>
      return Err([
        diagnostic("$.info.version", MissingField, "required field is missing"),
      ])
  }
  Ok({ title, version, })
}

///|
fn parse_methods(
  values : Array[Json],
) -> Result[Array[Method], Array[Diagnostic]] {
  let methods : Array[Method] = []
  for index, value in values {
    let method_path = "$.methods[" + index.to_string() + "]"
    guard value is Object(method_object) else {
      return Err([
        diagnostic(method_path, ExpectedObject, "each method must be an object"),
      ])
    }
    let name = match method_object.get("name") {
      Some(String(value)) => value
      Some(_) =>
        return Err([
          diagnostic(
            method_path + ".name",
            InvalidField,
            "method name must be a string",
          ),
        ])
      None =>
        return Err([
          diagnostic(
            method_path + ".name",
            MissingField,
            "required field is missing",
          ),
        ])
    }
    methods.push({ name, })
  }
  Ok(methods)
}

///|
fn diagnostic(
  path : String,
  code : DiagnosticCode,
  message : String,
) -> Diagnostic {
  { path, code, message, }
}
