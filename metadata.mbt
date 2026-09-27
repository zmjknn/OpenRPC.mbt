///|
/// A named OpenRPC tag used to group methods.
pub struct Tag {
  name : String
  description : String?
}

///|
/// One variable in an OpenRPC server URL template.
pub struct ServerVariable {
  default_value : String
  enum_values : Array[String]
  description : String?
}

///|
/// A transport-neutral server descriptor from an OpenRPC document.
pub struct Server {
  name : String
  url : String
  description : String?
  variables : Map[String, ServerVariable]
}

///|
/// An inline JSON example attached to a parameter, result, or pairing.
pub struct Example {
  name : String
  summary : String?
  description : String?
  value : Json
}

///|
/// A parameter-to-result example for one method.
pub struct ExamplePairing {
  name : String
  description : String?
  params : Array[Example]
  result : Example?
}

///|
/// Reusable OpenRPC components. Values remain JSON so unsupported schema
/// keywords are preserved instead of discarded.
pub struct Components {
  schemas : Map[String, Json]
  examples : Map[String, Json]
  example_pairings : Map[String, Json]
  content_descriptors : Map[String, Json]
  errors : Map[String, Json]
  links : Map[String, Json]
  tags : Map[String, Json]
}

///|
/// Create an empty component collection.
pub fn Components::empty() -> Components {
  {
    schemas: Map([]),
    examples: Map([]),
    example_pairings: Map([]),
    content_descriptors: Map([]),
    errors: Map([]),
    links: Map([]),
    tags: Map([]),
  }
}

///|
/// Return a named component from a recognized OpenRPC component section.
pub fn Components::find(
  self : Components,
  section : String,
  name : String,
) -> Json? {
  match section {
    "schemas" => self.schemas.get(name)
    "examples" => self.examples.get(name)
    "examplePairings" => self.example_pairings.get(name)
    "contentDescriptors" => self.content_descriptors.get(name)
    "errors" => self.errors.get(name)
    "links" => self.links.get(name)
    "tags" => self.tags.get(name)
    _ => None
  }
}

///|
/// Find a declared server by its stable name.
pub fn Document::find_server(self : Document, name : String) -> Server? {
  for server in self.servers {
    if server.name == name {
      return Some(server)
    }
  }
  None
}

///|
/// Find a document-level tag by its name.
pub fn Document::find_tag(self : Document, name : String) -> Tag? {
  for tag in self.tags {
    if tag.name == name {
      return Some(tag)
    }
  }
  None
}

///|
/// Check whether a method declares a tag with the requested name.
pub fn Method::has_tag(self : Method, name : String) -> Bool {
  for tag in self.tags {
    if tag.name == name {
      return true
    }
  }
  false
}

///|
/// Expand a server URL template using caller values or declared defaults.
///
/// Values are inserted literally; callers remain responsible for URL encoding
/// values that contain reserved URL characters. This function performs no I/O.
pub fn Server::render_url(
  self : Server,
  overrides : Map[String, String],
) -> Result[String, Array[Diagnostic]] {
  for name, _value in overrides {
    if self.variables.get(name) is None {
      return Err([
        diagnostic(
          "$.servers." + self.name + ".variables." + name,
          UnknownServerVariable,
          "server URL override is not declared by this server",
        ),
      ])
    }
  }
  let source = self.url.to_array()
  let output : Array[Char] = []
  let mut index = 0
  while index < source.length() {
    if source[index] == '{' {
      let mut closing : Int? = None
      let first_candidate = index + 1
      for candidate in first_candidate..<source.length() {
        if source[candidate] == '}' {
          closing = Some(candidate)
          break
        }
        if source[candidate] == '{' {
          return Err([
            diagnostic(
              "$.servers." + self.name + ".url",
              InvalidServerTemplate,
              "server URL contains nested template braces",
            ),
          ])
        }
      }
      let end = match closing {
        Some(value) => value
        None =>
          return Err([
            diagnostic(
              "$.servers." + self.name + ".url",
              InvalidServerTemplate,
              "server URL contains an opening brace without a closing brace",
            ),
          ])
      }
      let name_chars : Array[Char] = []
      let first_name_char = index + 1
      for char_index in first_name_char..<end {
        name_chars.push(source[char_index])
      }
      let variable_name = String::from_array(name_chars)
      if variable_name.length() == 0 {
        return Err([
          diagnostic(
            "$.servers." + self.name + ".url",
            InvalidServerTemplate,
            "server URL contains an empty variable name",
          ),
        ])
      }
      let variable = match self.variables.get(variable_name) {
        Some(value) => value
        None =>
          return Err([
            diagnostic(
              "$.servers." + self.name + ".variables." + variable_name,
              UnknownServerVariable,
              "server URL references an undeclared variable",
            ),
          ])
      }
      let value = match overrides.get(variable_name) {
        Some(value) => value
        None => variable.default_value
      }
      if variable.enum_values.length() > 0 {
        let mut allowed = false
        for candidate in variable.enum_values {
          if candidate == value {
            allowed = true
            break
          }
        }
        if !allowed {
          return Err([
            diagnostic(
              "$.servers." + self.name + ".variables." + variable_name,
              InvalidServerVariableValue,
              "server URL variable value is not in its declared enum",
            ),
          ])
        }
      }
      for char in value.to_array() {
        output.push(char)
      }
      index = end + 1
    } else if source[index] == '}' {
      return Err([
        diagnostic(
          "$.servers." + self.name + ".url",
          InvalidServerTemplate,
          "server URL contains a closing brace without an opening brace",
        ),
      ])
    } else {
      output.push(source[index])
      index = index + 1
    }
  }
  Ok(String::from_array(output))
}

///|
fn parse_optional_string(
  object : Map[String, Json],
  field : String,
  path : String,
) -> Result[String?, Array[Diagnostic]] {
  match object.get(field) {
    None => Ok(None)
    Some(String(value)) => Ok(Some(value))
    Some(_) =>
      Err([
        diagnostic(
          path + "." + field,
          InvalidField,
          field + " must be a string",
        ),
      ])
  }
}

///|
fn parse_optional_bool(
  object : Map[String, Json],
  field : String,
  path : String,
) -> Result[Bool?, Array[Diagnostic]] {
  match object.get(field) {
    None => Ok(None)
    Some(True) => Ok(Some(true))
    Some(False) => Ok(Some(false))
    Some(_) =>
      Err([
        diagnostic(
          path + "." + field,
          InvalidField,
          field + " must be a boolean",
        ),
      ])
  }
}

///|
fn parse_components(value : Json?) -> Result[Components, Array[Diagnostic]] {
  match value {
    None => Ok(Components::empty())
    Some(Object(object)) => {
      let schemas = match parse_component_group(object, "schemas") {
        Ok(value) => value
        Err(diagnostics) => return Err(diagnostics)
      }
      let examples = match parse_component_group(object, "examples") {
        Ok(value) => value
        Err(diagnostics) => return Err(diagnostics)
      }
      let example_pairings = match
        parse_component_group(object, "examplePairings") {
        Ok(value) => value
        Err(diagnostics) => return Err(diagnostics)
      }
      let content_descriptors = match
        parse_component_group(object, "contentDescriptors") {
        Ok(value) => value
        Err(diagnostics) => return Err(diagnostics)
      }
      let errors = match parse_component_group(object, "errors") {
        Ok(value) => value
        Err(diagnostics) => return Err(diagnostics)
      }
      let links = match parse_component_group(object, "links") {
        Ok(value) => value
        Err(diagnostics) => return Err(diagnostics)
      }
      let tags = match parse_component_group(object, "tags") {
        Ok(value) => value
        Err(diagnostics) => return Err(diagnostics)
      }
      Ok({
        schemas,
        examples,
        example_pairings,
        content_descriptors,
        errors,
        links,
        tags,
      })
    }
    Some(_) =>
      Err([
        diagnostic("$.components", InvalidField, "components must be an object"),
      ])
  }
}

///|
fn parse_component_group(
  components : Map[String, Json],
  field : String,
) -> Result[Map[String, Json], Array[Diagnostic]] {
  match components.get(field) {
    None => Ok(Map([]))
    Some(Object(values)) => Ok(values)
    Some(_) =>
      Err([
        diagnostic(
          "$.components." + field,
          InvalidField,
          "component section must be an object",
        ),
      ])
  }
}

///|
fn parse_optional_servers(
  value : Json?,
  path : String,
) -> Result[Array[Server], Array[Diagnostic]] {
  match value {
    None => Ok([])
    Some(Array(values)) => {
      let servers : Array[Server] = []
      for index, value in values {
        let server_path = path + "[" + index.to_string() + "]"
        match value {
          Object(object) =>
            match parse_server(object, server_path) {
              Ok(server) => servers.push(server)
              Err(diagnostics) => return Err(diagnostics)
            }
          _ =>
            return Err([
              diagnostic(
                server_path,
                ExpectedObject,
                "each server must be an object",
              ),
            ])
        }
      }
      Ok(servers)
    }
    Some(_) => Err([diagnostic(path, InvalidField, "servers must be an array")])
  }
}

///|
fn required_string(
  object : Map[String, Json],
  field : String,
  path : String,
) -> Result[String, Array[Diagnostic]] {
  match object.get(field) {
    Some(String(value)) => Ok(value)
    Some(_) =>
      Err([
        diagnostic(
          path + "." + field,
          InvalidField,
          field + " must be a string",
        ),
      ])
    None =>
      Err([
        diagnostic(
          path + "." + field,
          MissingField,
          "required field is missing",
        ),
      ])
  }
}

///|
fn parse_server(
  object : Map[String, Json],
  path : String,
) -> Result[Server, Array[Diagnostic]] {
  let name = match required_string(object, "name", path) {
    Ok(value) => value
    Err(diagnostics) => return Err(diagnostics)
  }
  let url = match required_string(object, "url", path) {
    Ok(value) => value
    Err(diagnostics) => return Err(diagnostics)
  }
  let description = match parse_optional_string(object, "description", path) {
    Ok(value) => value
    Err(diagnostics) => return Err(diagnostics)
  }
  let variables = match object.get("variables") {
    None => Map([])
    Some(Object(values)) =>
      match parse_server_variables(values, path + ".variables") {
        Ok(value) => value
        Err(diagnostics) => return Err(diagnostics)
      }
    Some(_) =>
      return Err([
        diagnostic(
          path + ".variables",
          InvalidField,
          "server variables must be an object",
        ),
      ])
  }
  Ok({ name, url, description, variables, })
}

///|
fn parse_server_variables(
  values : Map[String, Json],
  path : String,
) -> Result[Map[String, ServerVariable], Array[Diagnostic]] {
  let variables : Map[String, ServerVariable] = Map([])
  for name, raw_value in values {
    let variable_path = path + "." + name
    guard raw_value is Object(object) else {
      return Err([
        diagnostic(
          variable_path,
          ExpectedObject,
          "server variable must be an object",
        ),
      ])
    }
    let default_value = match
      required_string(object, "default", variable_path) {
      Ok(value) => value
      Err(diagnostics) => return Err(diagnostics)
    }
    let enum_values = match object.get("enum") {
      None => []
      Some(Array(items)) => {
        let values : Array[String] = []
        for index, item in items {
          match item {
            String(value) => values.push(value)
            _ =>
              return Err([
                diagnostic(
                  variable_path + ".enum[" + index.to_string() + "]",
                  InvalidField,
                  "server variable enum entries must be strings",
                ),
              ])
          }
        }
        values
      }
      Some(_) =>
        return Err([
          diagnostic(
            variable_path + ".enum",
            InvalidField,
            "server variable enum must be an array",
          ),
        ])
    }
    let description = match
      parse_optional_string(object, "description", variable_path) {
      Ok(value) => value
      Err(diagnostics) => return Err(diagnostics)
    }
    variables[name] = { default_value, enum_values, description, }
  }
  Ok(variables)
}

///|
fn parse_optional_tags(
  value : Json?,
  path : String,
  root : Json,
) -> Result[Array[Tag], Array[Diagnostic]] {
  match value {
    None => Ok([])
    Some(Array(values)) => {
      let tags : Array[Tag] = []
      let names : Map[String, Bool] = Map([])
      for index, raw_value in values {
        let tag_path = path + "[" + index.to_string() + "]"
        let resolved = match
          resolve_reference_value(root, raw_value, tag_path) {
          Ok(value) => value
          Err(diagnostics) => return Err(diagnostics)
        }
        guard resolved is Object(object) else {
          return Err([
            diagnostic(tag_path, ExpectedObject, "each tag must be an object"),
          ])
        }
        let name = match required_string(object, "name", tag_path) {
          Ok(value) => value
          Err(diagnostics) => return Err(diagnostics)
        }
        if names.get(name) is Some(_) {
          return Err([
            diagnostic(
              tag_path + ".name",
              DuplicateTag,
              "tag names must be unique within the same tag list",
            ),
          ])
        }
        names[name] = true
        let description = match
          parse_optional_string(object, "description", tag_path) {
          Ok(value) => value
          Err(diagnostics) => return Err(diagnostics)
        }
        tags.push({ name, description, })
      }
      Ok(tags)
    }
    Some(_) => Err([diagnostic(path, InvalidField, "tags must be an array")])
  }
}

///|
fn parse_optional_examples(
  value : Json?,
  path : String,
  root : Json,
) -> Result[Array[Example], Array[Diagnostic]] {
  match value {
    None => Ok([])
    Some(Array(values)) => {
      let examples : Array[Example] = []
      for index, value in values {
        let item_path = path + "[" + index.to_string() + "]"
        match parse_example(value, item_path, root) {
          Ok(example) => examples.push(example)
          Err(diagnostics) => return Err(diagnostics)
        }
      }
      Ok(examples)
    }
    Some(_) =>
      Err([diagnostic(path, InvalidField, "examples must be an array")])
  }
}

///|
fn parse_optional_example_pairings(
  value : Json?,
  path : String,
  root : Json,
) -> Result[Array[ExamplePairing], Array[Diagnostic]] {
  match value {
    None => Ok([])
    Some(Array(values)) => {
      let pairings : Array[ExamplePairing] = []
      for index, value in values {
        let item_path = path + "[" + index.to_string() + "]"
        match parse_example_pairing(value, item_path, root) {
          Ok(pairing) => pairings.push(pairing)
          Err(diagnostics) => return Err(diagnostics)
        }
      }
      Ok(pairings)
    }
    Some(_) =>
      Err([diagnostic(path, InvalidField, "examples must be an array")])
  }
}

///|
fn parse_example(
  raw_value : Json,
  path : String,
  root : Json,
) -> Result[Example, Array[Diagnostic]] {
  let value = match resolve_reference_value(root, raw_value, path) {
    Ok(value) => value
    Err(diagnostics) => return Err(diagnostics)
  }
  guard value is Object(object) else {
    return Err([diagnostic(path, ExpectedObject, "example must be an object")])
  }
  let name = match required_string(object, "name", path) {
    Ok(value) => value
    Err(diagnostics) => return Err(diagnostics)
  }
  let value = match object.get("value") {
    Some(value) => value
    None =>
      return Err([
        diagnostic(path + ".value", MissingField, "required field is missing"),
      ])
  }
  let summary = match parse_optional_string(object, "summary", path) {
    Ok(value) => value
    Err(diagnostics) => return Err(diagnostics)
  }
  let description = match parse_optional_string(object, "description", path) {
    Ok(value) => value
    Err(diagnostics) => return Err(diagnostics)
  }
  Ok({ name, summary, description, value, })
}

///|
fn parse_example_pairing(
  raw_value : Json,
  path : String,
  root : Json,
) -> Result[ExamplePairing, Array[Diagnostic]] {
  let value = match resolve_reference_value(root, raw_value, path) {
    Ok(value) => value
    Err(diagnostics) => return Err(diagnostics)
  }
  guard value is Object(object) else {
    return Err([
      diagnostic(path, ExpectedObject, "example pairing must be an object"),
    ])
  }
  let name = match required_string(object, "name", path) {
    Ok(value) => value
    Err(diagnostics) => return Err(diagnostics)
  }
  let raw_params = match object.get("params") {
    Some(Array(values)) => values
    Some(_) =>
      return Err([
        diagnostic(
          path + ".params",
          InvalidField,
          "pairing params must be an array",
        ),
      ])
    None =>
      return Err([
        diagnostic(path + ".params", MissingField, "required field is missing"),
      ])
  }
  let params : Array[Example] = []
  for index, raw_param in raw_params {
    let param_path = path + ".params[" + index.to_string() + "]"
    match parse_example(raw_param, param_path, root) {
      Ok(example) => params.push(example)
      Err(diagnostics) => return Err(diagnostics)
    }
  }
  let result = match object.get("result") {
    None => None
    Some(value) =>
      match parse_example(value, path + ".result", root) {
        Ok(example) => Some(example)
        Err(diagnostics) => return Err(diagnostics)
      }
  }
  let description = match parse_optional_string(object, "description", path) {
    Ok(value) => value
    Err(diagnostics) => return Err(diagnostics)
  }
  Ok({ name, description, params, result, })
}
