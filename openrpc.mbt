///|
pub struct Info {
  title : String
  version : String
}

///|
pub struct Parameter {
  name : String
  required : Bool
  schema : Json
}

///|
pub struct ResultDescriptor {
  name : String
  schema : Json
}

///|
pub struct Method {
  name : String
  params : Array[Parameter]
  result : ResultDescriptor?
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
  DuplicateMethod
  MissingParameter
  UnknownParameter
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
pub fn Document::find_method(self : Document, name : String) -> Method? {
  for method_value in self.methods {
    if method_value.name == name {
      return Some(method_value)
    }
  }
  None
}

///|
pub fn Method::build_request(
  self : Method,
  id : Json,
  params : Map[String, Json],
) -> Result[Json, Array[Diagnostic]] {
  for parameter in self.params {
    if parameter.required && params.get(parameter.name) is None {
      return Err([
        diagnostic(
          "$.params." + parameter.name,
          MissingParameter,
          "required parameter is missing",
        ),
      ])
    }
  }
  for name, _value in params {
    let mut declared = false
    for parameter in self.params {
      if parameter.name == name {
        declared = true
        break
      }
    }
    if !declared {
      return Err([
        diagnostic(
          "$.params." + name,
          UnknownParameter,
          "parameter is not declared by the method",
        ),
      ])
    }
  }
  Ok({
    "jsonrpc": "2.0",
    "id": id,
    "method": self.name,
    "params": Json::object(params),
  })
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
  let names : Map[String, Bool] = Map([])
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
    if names.get(name) is Some(_) {
      return Err([
        diagnostic(
          method_path + ".name",
          DuplicateMethod,
          "method names must be unique",
        ),
      ])
    }
    names[name] = true
    let params = match method_object.get("params") {
      None => []
      Some(Array(values)) =>
        match parse_parameters(values, method_path) {
          Ok(value) => value
          Err(diagnostics) => return Err(diagnostics)
        }
      Some(_) =>
        return Err([
          diagnostic(
            method_path + ".params",
            InvalidField,
            "params must be an array",
          ),
        ])
    }
    let result = match method_object.get("result") {
      None => None
      Some(Object(value)) =>
        match parse_result(value, method_path) {
          Ok(value) => Some(value)
          Err(diagnostics) => return Err(diagnostics)
        }
      Some(_) =>
        return Err([
          diagnostic(
            method_path + ".result",
            InvalidField,
            "result must be an object",
          ),
        ])
    }
    methods.push({ name, params, result, })
  }
  Ok(methods)
}

///|
fn parse_parameters(
  values : Array[Json],
  method_path : String,
) -> Result[Array[Parameter], Array[Diagnostic]] {
  let params : Array[Parameter] = []
  for index, value in values {
    let param_path = method_path + ".params[" + index.to_string() + "]"
    guard value is Object(parameter_object) else {
      return Err([
        diagnostic(
          param_path,
          ExpectedObject,
          "each parameter must be an object",
        ),
      ])
    }
    let name = match parameter_object.get("name") {
      Some(String(value)) => value
      Some(_) =>
        return Err([
          diagnostic(
            param_path + ".name",
            InvalidField,
            "parameter name must be a string",
          ),
        ])
      None =>
        return Err([
          diagnostic(
            param_path + ".name",
            MissingField,
            "required field is missing",
          ),
        ])
    }
    let required = match parameter_object.get("required") {
      None => false
      Some(True) => true
      Some(False) => false
      Some(_) =>
        return Err([
          diagnostic(
            param_path + ".required",
            InvalidField,
            "required must be a boolean",
          ),
        ])
    }
    let schema = match parameter_object.get("schema") {
      Some(value) => value
      None =>
        return Err([
          diagnostic(
            param_path + ".schema",
            MissingField,
            "required field is missing",
          ),
        ])
    }
    params.push({ name, required, schema, })
  }
  Ok(params)
}

///|
fn parse_result(
  value : Map[String, Json],
  method_path : String,
) -> Result[ResultDescriptor, Array[Diagnostic]] {
  let name = match value.get("name") {
    Some(String(value)) => value
    Some(_) =>
      return Err([
        diagnostic(
          method_path + ".result.name",
          InvalidField,
          "result name must be a string",
        ),
      ])
    None =>
      return Err([
        diagnostic(
          method_path + ".result.name",
          MissingField,
          "required field is missing",
        ),
      ])
  }
  let schema = match value.get("schema") {
    Some(value) => value
    None =>
      return Err([
        diagnostic(
          method_path + ".result.schema",
          MissingField,
          "required field is missing",
        ),
      ])
  }
  Ok({ name, schema, })
}

///|
fn diagnostic(
  path : String,
  code : DiagnosticCode,
  message : String,
) -> Diagnostic {
  { path, code, message, }
}
